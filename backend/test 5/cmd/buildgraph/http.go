package main

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"test/kdtree"
	"test/routing"
	"time"
)

var (
	reLetterDigit = regexp.MustCompile(`([[:alpha:]])([0-9])`)
	reDigitLetter = regexp.MustCompile(`([0-9])([[:alpha:]])`)
	reBuilding    = regexp.MustCompile(`\b(строение|стр|корпус|корп)\s*\d+[а-яa-z0-9/-]*`)
	geocodeCache  = NewAddressGeocodeCache()
)

type reverseProbeCoord struct {
	Lat float64
	Lon float64
}

type NominatimItem struct {
	Lat         string `json:"lat"`
	Lon         string `json:"lon"`
	DisplayName string `json:"display_name"`
}

type NominatimResponse struct {
	DisplayName string `json:"display_name"`
}
type GeocodeResult struct {
	FullAddress string
	Lat         float64
	Lon         float64
}

type AddressGeocodeCache struct {
	mu    sync.RWMutex
	items map[string]GeocodeResult
}

// геокодин для того чтобы сделать из вводимого адреса реальный через OSM

func CalculateTime(routeLengthMeters uint32) uint32 {

	if routeLengthMeters == 0 {
		return 0
	}

	return uint32(math.Ceil(float64(routeLengthMeters) / 1.4))
}

func NewAddressGeocodeCache() *AddressGeocodeCache {

	return &AddressGeocodeCache{
		items: make(map[string]GeocodeResult),
	}
}

func (c *AddressGeocodeCache) getByAddress(address string) (GeocodeResult, bool) {

	keys := MakeGeocodeCacheKeys(address)

	c.mu.RLock()
	defer c.mu.RUnlock()

	for _, key := range keys {
		result, flag := c.items[key]
		if flag {
			return result, true
		}
	}

	return GeocodeResult{}, false
}

func (c *AddressGeocodeCache) SaveResultInCache(result GeocodeResult) {

	keys := MakeGeocodeCacheKeys(result.FullAddress)

	c.mu.Lock()
	defer c.mu.Unlock()

	for _, key := range keys {
		c.items[key] = result
	}
}

func (s *Server) geocodeHandler(w http.ResponseWriter, r *http.Request) {

	if r.Method != http.MethodPost {
		http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
		return
	}

	var req GeocodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	query := req.Query
	if query == "" {
		query = req.Adress
	}

	result, err := GeocodeAddress(r.Context(), query)
	if err != nil {
		http.Error(w, "Не удалось найти адрес", http.StatusNotFound)
		return
	}

	response := GeocodeResponse{
		FullAddress: result.FullAddress,
		Lat:         result.Lat,
		Lon:         result.Lon,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "encode response error", http.StatusInternalServerError)
		return
	}
}

func FindNearestPointWithGeocode(lat float64, lon float64) []reverseProbeCoord {

	coords := []reverseProbeCoord{
		{Lat: lat, Lon: lon},
	}

	testDistMeters := []float64{8, 18}

	for _, square := range testDistMeters {

		latOffset := square / 111320.0
		lonScale := math.Cos(lat * math.Pi / 180.0)

		if lonScale == 0 {
			lonScale = 0.000001
		}
		lonOffset := square / (111320.0 * lonScale)

		coords = append(coords,
			reverseProbeCoord{Lat: lat + latOffset, Lon: lon},
			reverseProbeCoord{Lat: lat - latOffset, Lon: lon},
			reverseProbeCoord{Lat: lat, Lon: lon + lonOffset},
			reverseProbeCoord{Lat: lat, Lon: lon - lonOffset},
		)
	}

	return coords
}

func CoordinateToAddress(ctx context.Context, lat float64, lon float64) (GeocodeResult, error) {

	ctx, cancel := context.WithTimeout(ctx, 5500*time.Millisecond)
	defer cancel()

	nearestCoords := FindNearestPointWithGeocode(lat, lon)

	var lastErr error
	for i := 0; i < len(nearestCoords); i++ {

		fullAddress, err := CoordinatesToAddressOnce(
			ctx,
			nearestCoords[i].Lat,
			nearestCoords[i].Lon,
		)
		if err != nil {
			lastErr = err
			continue
		}

		result := GeocodeResult{
			FullAddress: fullAddress,
			Lat:         lat,
			Lon:         lon,
		}
		geocodeCache.SaveResultInCache(result)
		return result, nil
	}

	if ctx.Err() != nil {
		return GeocodeResult{}, ctx.Err()
	}

	if lastErr != nil {
		return GeocodeResult{}, lastErr
	}

	return GeocodeResult{}, fmt.Errorf("Не удалось найти адрес")
}

func (s *Server) coordinatesToAddressHandler(w http.ResponseWriter, r *http.Request) {

	if r.Method != http.MethodPost {
		http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
		return
	}

	var req NearestRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	result, err := CoordinateToAddress(r.Context(), req.Lat, req.Lon)
	if err != nil {
		http.Error(w, "Не удалось найти адрес", http.StatusNotFound)
		return
	}

	response := GeocodeResponse{
		FullAddress: result.FullAddress,
		Lat:         result.Lat,
		Lon:         result.Lon,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "encode response error", http.StatusInternalServerError)
		return
	}
}

func SearchNominatim(ctx context.Context, query string) (GeocodeResult, bool, error) {

	if query == "" {
		return GeocodeResult{}, false, fmt.Errorf("empty query")
	}

	params := url.Values{}
	params.Set("q", query)
	params.Set("format", "jsonv2")
	params.Set("limit", "5")
	params.Set("addressdetails", "1")
	params.Set("countrycodes", "ru")
	params.Set("accept-language", "ru")
	params.Set("bounded", "1")
	params.Set("viewbox", "37.2343692,55.9492019,37.9057324,55.5570003")

	endPoint := "https://nominatim.openstreetmap.org/search?" + params.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endPoint, nil)
	if err != nil {
		return GeocodeResult{}, false, err
	}

	req.Header.Set("User-Agent", "test-course-project/1.0 (student project)")

	client := &http.Client{
		Timeout: 2500 * time.Millisecond,
	}

	response, err := client.Do(req)
	if err != nil {
		return GeocodeResult{}, false, err
	}
	defer response.Body.Close()

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return GeocodeResult{}, false, fmt.Errorf("nominatim status %d", response.StatusCode)
	}

	var items []NominatimItem
	if err := json.NewDecoder(response.Body).Decode(&items); err != nil {
		return GeocodeResult{}, false, err
	}

	for _, item := range items {

		lat, err1 := strconv.ParseFloat(item.Lat, 64)
		lon, err2 := strconv.ParseFloat(item.Lon, 64)

		if err1 != nil || err2 != nil {
			continue
		}

		return GeocodeResult{
			Lat:         lat,
			Lon:         lon,
			FullAddress: item.DisplayName,
		}, true, nil
	}

	return GeocodeResult{}, false, nil
}

func GeocodeAddress(ctx context.Context, address string) (GeocodeResult, error) {

	cleanStr := strings.TrimSpace(address)

	if cleanStr == "" {
		return GeocodeResult{}, fmt.Errorf("empty query")
	}

	if cached, flag := geocodeCache.getByAddress(cleanStr); flag {
		return cached, nil
	}

	for _, query := range MakeGeocodeVariants(cleanStr) {

		result, found, err := SearchNominatim(ctx, query)

		if err != nil {
			return GeocodeResult{}, err
		}
		if found {
			geocodeCache.SaveResultInCache(result)
			return result, nil
		}
	}

	return GeocodeResult{}, fmt.Errorf("Не удалось найти адрес")
}

func CoordinatesToAddressOnce(ctx context.Context, lat float64, lon float64) (string, error) {

	params := url.Values{}
	params.Set("format", "jsonv2")
	params.Set("lat", strconv.FormatFloat(lat, 'f', 7, 64))
	params.Set("lon", strconv.FormatFloat(lon, 'f', 7, 64))
	params.Set("zoom", "18")
	params.Set("addressdetails", "1")
	params.Set("accept-language", "ru")

	endPoint := "https://nominatim.openstreetmap.org/reverse?" + params.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endPoint, nil)
	if err != nil {
		return "", err
	}

	req.Header.Set("User-Agent", "test-course-project/1.0 (student project)")

	client := &http.Client{
		Timeout: 1500 * time.Millisecond,
	}

	response, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return "", fmt.Errorf("nominatim status %d", response.StatusCode)
	}

	var item NominatimResponse
	if err := json.NewDecoder(response.Body).Decode(&item); err != nil {
		return "", err
	}

	fullAddress := strings.TrimSpace(item.DisplayName)
	if fullAddress == "" {
		return "", fmt.Errorf("Не удалось найти адрес")
	}

	return fullAddress, nil
}

func MakeStrToNormalView(text string) string {

	text = strings.ToLower(strings.TrimSpace(text))
	text = strings.ReplaceAll(text, ",", " ")
	text = strings.ReplaceAll(text, ".", " ")
	text = strings.ReplaceAll(text, "ё", "е")
	return strings.Join(strings.Fields(text), " ")
}

func AppendCacheKey(keys []string, value string) []string {

	key := MakeStrToNormalView(value)
	if key == "" {
		return keys
	}

	for _, now := range keys {
		if now == key {
			return keys
		}
	}

	return append(keys, key)
}

func MakeGeocodeCacheKeys(address string) []string {
	var keys []string

	keys = AppendCacheKey(keys, address)

	for _, now := range MakeGeocodeVariants(address) {
		keys = AppendCacheKey(keys, now)
	}

	return keys
}

func MakeQueryToBaseForm(q string) string {

	q = strings.ToLower(strings.TrimSpace(q))
	q = strings.ReplaceAll(q, ",", " ")
	q = strings.ReplaceAll(q, ".", " ")
	q = strings.ReplaceAll(q, "ё", "е")

	q = reLetterDigit.ReplaceAllString(q, "$1 $2")
	q = reDigitLetter.ReplaceAllString(q, "$1 $2")

	vector := strings.Fields(q)
	for i, j := range vector {
		switch j {
		case "ул", "ул.":
			vector[i] = "улица"
		case "пр-кт", "пркт", "просп", "просп.":
			vector[i] = "проспект"
		case "пр-д", "прд":
			vector[i] = "проезд"
		case "пер", "пер.":
			vector[i] = "переулок"
		case "вл", "вл.", "влад", "влад.":
			vector[i] = "владение"
		case "д", "д.":
			vector[i] = "дом"
		case "к", "корп", "корп.":
			vector[i] = "корпус"
		case "с", "стр", "стр.":
			vector[i] = "строение"
		case "мкр":
			vector[i] = "микрорайон"
		}
	}

	q = strings.Join(vector, " ")
	q = strings.Join(strings.Fields(q), " ")

	if !strings.Contains(q, "москва") {
		q = q + " москва"
	}

	return q
}

func AppendUniqueAddress(addresses []string, value string) []string {

	value = strings.TrimSpace(strings.Join(strings.Fields(value), " "))

	if value == "" {
		return addresses
	}

	for _, now := range addresses {
		if now == value {
			return addresses
		}
	}

	return append(addresses, value)
}

func MakeGeocodeVariants(address string) []string {

	base := MakeQueryToBaseForm(address)
	if base == "" {
		return nil
	}

	var addresses []string

	addresses = AppendUniqueAddress(addresses, base)
	addresses = AppendUniqueAddress(addresses, base+", Москва")
	addresses = AppendUniqueAddress(addresses, strings.ReplaceAll(base, "владение", "вл"))
	addresses = AppendUniqueAddress(addresses, strings.ReplaceAll(base, "строение", "стр"))
	addresses = AppendUniqueAddress(
		addresses,
		strings.ReplaceAll(
			strings.ReplaceAll(base, "владение", "вл"),
			"строение",
			"стр",
		),
	)

	withoutBuilding := strings.TrimSpace(reBuilding.ReplaceAllString(base, ""))
	addresses = AppendUniqueAddress(addresses, withoutBuilding)
	addresses = AppendUniqueAddress(addresses, withoutBuilding+", Москва")

	return addresses
}

// обычные хендлеры для проверок состояния сервера и данных о маршрутах

func (s *Server) routeByAddressHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
		return
	}

	var req RouteByAddressRequest

	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, "invalid JSON (can't create)", http.StatusBadRequest)
		return
	}

	startGeo, err := GeocodeAddress(r.Context(), req.StartQuery)
	if err != nil {
		http.Error(w, "start address not found", http.StatusNotFound)
		return
	}

	endGeo, err := GeocodeAddress(r.Context(), req.EndQuery)
	if err != nil {
		http.Error(w, "end address not found", http.StatusNotFound)
		return
	}

	routePoints, routeLengthMeters, err := s.buildRouteFromCoords(
		startGeo.Lat,
		startGeo.Lon,
		endGeo.Lat,
		endGeo.Lon,
	)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	response := RouteByAddressResponse{
		StartFullAdress: startGeo.FullAddress,
		EndFullAdress:   endGeo.FullAddress,
		LatSt:           startGeo.Lat,
		LonSt:           startGeo.Lon,
		LatEnd:          endGeo.Lat,
		LonEnd:          endGeo.Lon,
		Route:           routePoints,
		LengthMeters:    routeLengthMeters,
		Time:            CalculateTime(routeLengthMeters),
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *Server) buildRouteFromCoords(startLat float64, startLon float64, endLat float64, endLon float64) ([]routing.RoutePoint, uint32, error) {

	latStE7 := int32(startLat * 1e7)
	lonStE7 := int32(startLon * 1e7)
	latEndE7 := int32(endLat * 1e7)
	lonEndE7 := int32(endLon * 1e7)

	routePath := routing.BuildRouteByCoords(s.Graph, s.Root, latStE7, lonStE7, latEndE7, lonEndE7)
	if len(routePath.Route.Path) == 0 {
		return nil, 0, fmt.Errorf("route not found")
	}

	routePoints := routing.ConvertPathToCoords(s.Graph, routePath)
	return routePoints, routePath.Route.LengthMeters, nil
}

func (s *Server) routedebugHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
		return
	}

	var req RouteDebugRequest

	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, "invalid JSON (can't create)", http.StatusBadRequest)
		return
	}

	latStE7 := int32(req.LatSt * 1e7)
	lonStE7 := int32(req.LonSt * 1e7)
	latEndE7 := int32(req.LatEnd * 1e7)
	lonEndE7 := int32(req.LonEnd * 1e7)

	startNearestVertex := kdtree.FindNearestVertex(s.Root, latStE7, lonStE7)
	endNearestVertex := kdtree.FindNearestVertex(s.Root, latEndE7, lonEndE7)

	kdPointSt := kdtree.FindNearestPoint(s.Root, latStE7, lonStE7)
	startNearestPoint := routing.RoutePoint{
		Lat: float64(kdPointSt.X) / 1e7,
		Lon: float64(kdPointSt.Y) / 1e7,
	}

	kdPointEn := kdtree.FindNearestPoint(s.Root, latEndE7, lonEndE7)
	endNearestPoint := routing.RoutePoint{
		Lat: float64(kdPointEn.X) / 1e7,
		Lon: float64(kdPointEn.Y) / 1e7,
	}

	path := routing.BuildRouteByCoords(s.Graph, s.Root, latStE7, lonStE7, latEndE7, lonEndE7)
	routePathVerticesCount := len(path.Route.Path)
	if routePathVerticesCount == 0 {
		http.Error(w, "route not found", http.StatusNotFound)
		return
	}

	route := routing.ConvertPathToCoords(s.Graph, path)

	response := RouteDebugResponse{
		StartNearestVertex:     startNearestVertex,
		EndNearestVertex:       endNearestVertex,
		StartNearestPoint:      startNearestPoint,
		EndNearestPoint:        endNearestPoint,
		RoutePathVerticesCount: routePathVerticesCount,
		Route:                  route,
		Path:                   path.Route.Path,
		LengthMeters:           path.Route.LengthMeters,
		Time:                   CalculateTime(path.Route.LengthMeters),
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *Server) bboxHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Only GET method is allowed", http.StatusMethodNotAllowed)
		return
	}

	minLat := s.Graph.LatE7[0]
	maxLat := s.Graph.LatE7[0]
	minLon := s.Graph.LonE7[0]
	maxLon := s.Graph.LonE7[0]

	for i := 0; i < len(s.Graph.LatE7); i++ {
		latV := s.Graph.LatE7[i]
		lonV := s.Graph.LonE7[i]
		if latV < minLat {
			minLat = latV
		}

		if latV > maxLat {
			maxLat = latV
		}

		if lonV < minLon {
			minLon = lonV
		}

		if lonV > maxLon {
			maxLon = lonV
		}
	}

	response := BBoxResponse{
		MinLat: float64(minLat) / 1e7,
		MinLon: float64(minLon) / 1e7,
		MaxLat: float64(maxLat) / 1e7,
		MaxLon: float64(maxLon) / 1e7,
	}

	w.Header().Set("Content-Type", "application/json")
	err := json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *Server) nearestHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
		return
	}

	var req NearestRequest

	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, "invalid JSON (can't create)", http.StatusBadRequest)
		return
	}

	latE7 := int32(req.Lat * 1e7)
	lonE7 := int32(req.Lon * 1e7)

	flagPoint := s.Graph.PointNearToFlag(s.Root, latE7, lonE7)

	nearestPoint := routing.RoutePoint{
		Lat: float64(flagPoint.LatE7) / 1e7,
		Lon: float64(flagPoint.LonE7) / 1e7,
	}

	response := NearestResponse{
		Vertex: flagPoint.Vertex,
		Point:  nearestPoint,
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *Server) healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Only GET method is allowed", http.StatusMethodNotAllowed)
		return
	}

	response := HealthResponse{
		Status: "ok",
	}

	w.Header().Set("Content-Type", "application/json")
	err := json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *Server) statsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "DOnly GET method is allowed", http.StatusMethodNotAllowed)
		return
	}

	response := StatsResponse{
		Vertexes: len(s.Graph.LatE7),
		Edges:    len(s.Graph.To_csr),
	}

	w.Header().Set("Content-Type", "application/json")
	err := json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *Server) routeHandler(w http.ResponseWriter, r *http.Request) {

	if r.Method != http.MethodPost {
		http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
		return
	}
	var req RequestStruct

	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, "invalid JSON (can't create)", http.StatusBadRequest)
		return
	}

	latStE7 := int32(req.LatSt * 1e7)
	lonStE7 := int32(req.LonSt * 1e7)
	latEndE7 := int32(req.LatEnd * 1e7)
	lonEndE7 := int32(req.LonEnd * 1e7)

	routePoints, routeLengthMeters, err := s.buildRouteFromCoords(
		float64(latStE7)/1e7,
		float64(lonStE7)/1e7,
		float64(latEndE7)/1e7,
		float64(lonEndE7)/1e7,
	)
	if err != nil {
		http.Error(w, "route not found (size 0)", http.StatusNotFound)
		return
	}

	response := AnswerStruct{
		Route:           routePoints,
		LengthMeters:    routeLengthMeters,
		DurationSeconds: CalculateTime(routeLengthMeters),
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}
