package main

import (
	"encoding/json"
	"net/http"
	"test/kdtree"
	"test/routing"
)

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
	routePathVerticesCount := len(path.Path)
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
		Path:                   path.Path,
		LengthMeters:           path.LengthMeters,
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

	nearestVertex := kdtree.FindNearestVertex(s.Root, latE7, lonE7)
	treeNearestPoint := kdtree.FindNearestPoint(s.Root, latE7, lonE7)

	nearestPoint := routing.RoutePoint{
		Lat: float64(treeNearestPoint.X) / 1e7,
		Lon: float64(treeNearestPoint.Y) / 1e7,
	}

	response := NearestResponse{
		Vertex: nearestVertex,
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

	routePath := routing.BuildRouteByCoords(s.Graph, s.Root, latStE7, lonStE7, latEndE7, lonEndE7)
	if len(routePath.Path) == 0 {
		http.Error(w, "route not found (size 0)", http.StatusNotFound)
		return
	}

	routePoints := routing.ConvertPathToCoords(s.Graph, routePath)

	response := AnswerStruct{
		Route:        routePoints,
		LengthMeters: routePath.LengthMeters,
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}
