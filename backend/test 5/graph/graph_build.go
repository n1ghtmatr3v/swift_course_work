package graph

import (
	"context"
	"log"
	"math"
	"os"
	"runtime"

	"github.com/paulmach/osm"
	"github.com/paulmach/osm/osmpbf"
)

type WalkableAreaRelation struct {
	RelationID   int64
	OuterBorders []int64
}

func isFoot(tags osm.Tags) bool {
	foot := tags.Find("foot")
	switch foot {
	case "yes",
		"designated",
		"permissive",
		"destination",
		"customers",
		"delivery",
		"official",
		"discouraged":
		return true
	default:
		return false
	}
}

func NoFoot(tags osm.Tags) bool {
	foot := tags.Find("foot")
	switch foot {
	case "no",
		"private",
		"use_sidepath",
		"military",
		"permit",
		"agricultural",
		"forestry":
		return true
	default:
		return false
	}
}

func isAllowedForPedestrians(value string) bool {
	switch value {
	case "yes",
		"permissive",
		"destination",
		"customers",
		"delivery",
		"designated",
		"official",
		"discouraged":
		return true
	default:
		return false
	}
}

func isBlockedForPedestrians(value string) bool {
	switch value {
	case "no",
		"private",
		"use_sidepath",
		"military",
		"permit",
		"agricultural",
		"forestry":
		return true
	default:
		return false
	}
}

func ObviousFootAllows(tags osm.Tags) bool {
	foot := tags.Find("foot")
	return foot != "" && isAllowedForPedestrians(foot)
}

func ObviousAccessAllows(tags osm.Tags) bool {
	access := tags.Find("access")
	return access != "" && isAllowedForPedestrians(access)
}

func isPedestrianDenied(tags osm.Tags) bool {
	if NoFoot(tags) {
		return true
	}

	access := tags.Find("access")
	if access != "" && isBlockedForPedestrians(access) && !ObviousFootAllows(tags) {
		return true
	}

	return false
}

func SidewalkValues(tags osm.Tags) []string {
	return []string{
		tags.Find("sidewalk"),
		tags.Find("sidewalk:left"),
		tags.Find("sidewalk:right"),
		tags.Find("sidewalk:both"),
	}
}

func SidewalkHasPedestrianSpace(value string) bool {
	switch value {
	case "yes",
		"both",
		"left",
		"right",
		"lane":
		return true
	default:
		return false
	}
}

func SidewalkValueIsSeparate(value string) bool {
	return value == "separate"
}

func SidewalkValueDenies(value string) bool {
	return value == "no" || value == "none"
}

func isSidewalk(tags osm.Tags) bool {
	for _, sidewalk := range SidewalkValues(tags) {
		if SidewalkHasPedestrianSpace(sidewalk) {
			return true
		}
	}

	return false
}

func UseSeparatePedestrianSidepath(tags osm.Tags) bool {
	if tags.Find("foot") == "use_sidepath" {
		return true
	}

	if SidewalkValueIsSeparate(tags.Find("sidewalk")) || SidewalkValueIsSeparate(tags.Find("sidewalk:both")) {
		return true
	}

	left := tags.Find("sidewalk:left")
	right := tags.Find("sidewalk:right")

	if SidewalkValueIsSeparate(left) && (SidewalkValueIsSeparate(right) || SidewalkValueDenies(right)) {
		return true
	}

	if SidewalkValueIsSeparate(right) && (SidewalkValueIsSeparate(left) || SidewalkValueDenies(left)) {
		return true
	}

	return false
}

func HasRoadSignForWalk(tags osm.Tags) bool {
	if UseSeparatePedestrianSidepath(tags) {
		return false
	}

	return isSidewalk(tags) || ObviousFootAllows(tags) || ObviousAccessAllows(tags)
}

func isMajorRoadHighway(highway string) bool {
	switch highway {
	case "primary",
		"primary_link",
		"secondary",
		"secondary_link",
		"trunk",
		"trunk_link",
		"road":
		return true
	default:
		return false
	}
}

func SkipRoadBySidewalk(tags osm.Tags, highway string) bool {
	if isSidewalk(tags) == false {
		return false
	}

	if ObviousFootAllows(tags) || ObviousAccessAllows(tags) {
		return false
	}

	return isMajorRoadHighway(highway)
}

func isWalkServiceRoad(tags osm.Tags) bool {
	service := tags.Find("service")

	switch service {
	case "parking_aisle",
		"drive-through",
		"private",
		"emergency_access",
		"driveway":
		return HasRoadSignForWalk(tags)
	}

	if HasRoadSignForWalk(tags) {
		return true
	}

	if tags.Find("maxspeed") != "" || tags.Find("source:maxspeed") != "" {
		return false
	}

	if tags.Find("lanes") != "" {
		return false
	}

	return true
}

func CanWalkOnBridge(tags osm.Tags) bool {
	if tags.Find("bridge") != "yes" {
		return false
	}

	if isPedestrianDenied(tags) {
		return false
	}

	highway := tags.Find("highway")
	switch highway {
	case "footway",
		"pedestrian",
		"path",
		"steps",
		"corridor",
		"platform":
		return true
	}

	return ObviousFootAllows(tags) || ObviousAccessAllows(tags)
}

func CanWalkOnPlatform(tags osm.Tags) bool {
	return tags.Find("highway") == "platform" ||
		tags.Find("public_transport") == "platform" ||
		tags.Find("railway") == "platform"
}

func WalkAreaClass(tags osm.Tags) string {
	areaHighway := tags.Find("area:highway")
	switch areaHighway {
	case "footway",
		"path",
		"pedestrian",
		"steps",
		"corridor":
		return areaHighway
	case "cycleway":
		if ObviousFootAllows(tags) {
			return areaHighway
		}
	}

	if CanWalkOnPlatform(tags) && (tags.Find("area") == "yes" || tags.Find("type") == "multipolygon") {
		return "platform"
	}

	if tags.Find("area") != "yes" {
		return ""
	}

	switch tags.Find("highway") {
	case "footway",
		"path",
		"pedestrian",
		"steps",
		"corridor",
		"platform":
		return tags.Find("highway")
	case "cycleway":
		if ObviousFootAllows(tags) {
			return "cycleway"
		}
	}

	return ""
}

func isWalkAreaFeature(tags osm.Tags) bool {
	if isPedestrianDenied(tags) {
		return false
	}

	return WalkAreaClass(tags) != ""
}

func isLinearWalkByHighway(tags osm.Tags, highway string) bool {
	switch highway {
	case "footway",
		"pedestrian",
		"path",
		"steps",
		"corridor",
		"platform":
		return true

	case "cycleway",
		"bridleway":
		return ObviousFootAllows(tags)

	case "living_street",
		"track",
		"residential":
		if UseSeparatePedestrianSidepath(tags) {
			return false
		}

		if HasRoadSignForWalk(tags) {
			return true
		}

		return true

	case "unclassified":
		if UseSeparatePedestrianSidepath(tags) {
			return false
		}

		return HasRoadSignForWalk(tags)

	case "service":
		if UseSeparatePedestrianSidepath(tags) {
			return false
		}

		return isWalkServiceRoad(tags)

	case "tertiary",
		"tertiary_link",
		"secondary",
		"secondary_link",
		"primary",
		"primary_link",
		"trunk",
		"trunk_link":
		if UseSeparatePedestrianSidepath(tags) {
			return false
		}

		if SkipRoadBySidewalk(tags, highway) {
			return false
		}

		return HasRoadSignForWalk(tags)

	case "road":
		if UseSeparatePedestrianSidepath(tags) {
			return false
		}

		if SkipRoadBySidewalk(tags, highway) {
			return false
		}

		return HasRoadSignForWalk(tags)

	default:
		return false
	}
}

func isClosedWay(way *osm.Way) bool {
	if len(way.Nodes) < 4 {
		return false
	}

	return way.Nodes[0].ID == way.Nodes[len(way.Nodes)-1].ID
}

func isWalkWay(tags osm.Tags) bool {
	if isPedestrianDenied(tags) {
		return false
	}

	if tags.Find("motorroad") == "yes" {
		return false
	}

	highway := tags.Find("highway")
	if highway == "construction" || highway == "proposed" {
		return false
	}

	if tags.Find("construction") != "" || tags.Find("proposed") != "" {
		return false
	}

	if tags.Find("bridge") == "yes" {
		return CanWalkOnBridge(tags)
	}

	if WalkAreaClass(tags) != "" {
		return false
	}

	if CanWalkOnPlatform(tags) {
		return true
	}

	if highway == "" {
		return ObviousFootAllows(tags)
	}

	if isLinearWalkByHighway(tags, highway) {
		return true
	}

	return ObviousFootAllows(tags)
}

func isWalkAreaRelation(tags osm.Tags) bool {
	if tags.Find("type") != "multipolygon" {
		return false
	}

	return isWalkAreaFeature(tags)
}

func GetWayNodeIDs(way *osm.Way) []int64 {
	ids := make([]int64, 0, len(way.Nodes))
	for _, n := range way.Nodes {
		ids = append(ids, int64(n.ID))
	}

	return ids
}

func DistanceMeters(lat1e7 int32, lon1e7 int32, lat2e7 int32, lon2e7 int32) uint32 {
	const R = 6371000.0

	lat1 := (float64(lat1e7) / 1e7) * (math.Pi / 180)
	lat2 := (float64(lat2e7) / 1e7) * (math.Pi / 180)
	lon1 := (float64(lon1e7) / 1e7) * (math.Pi / 180)
	lon2 := (float64(lon2e7) / 1e7) * (math.Pi / 180)

	dlat := lat2 - lat1
	dlon := lon2 - lon1

	sinDLat := math.Sin(dlat / 2)
	sinDLon := math.Sin(dlon / 2)

	a := sinDLat*sinDLat + math.Cos(lat1)*math.Cos(lat2)*sinDLon*sinDLon
	d := 2 * R * math.Asin(math.Sqrt(a))

	if d < 0 {
		d = 0
	}
	return uint32(math.Round(d))
}

func passWalkAreas(pbfPath string) ([]WalkableAreaRelation, map[int64]struct{}) {
	f, err := os.Open(pbfPath)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	decoder := osmpbf.New(context.Background(), f, runtime.GOMAXPROCS(-1))
	defer decoder.Close()

	decoder.SkipNodes = true

	relations := make([]WalkableAreaRelation, 0, 10_000)
	areaWayIDs := make(map[int64]struct{}, 50_000)
	visitedAreas := make(map[int64]struct{}, 10_000)

	for decoder.Scan() {
		v := decoder.Object()

		switch obj := v.(type) {
		case *osm.Way:
			if !isClosedWay(obj) {
				continue
			}

			if !isWalkAreaFeature(obj.Tags) {
				continue
			}

			wayID := int64(obj.ID)
			if _, found := visitedAreas[wayID]; found {
				continue
			}

			visitedAreas[wayID] = struct{}{}
			areaWayIDs[wayID] = struct{}{}

			relations = append(relations, WalkableAreaRelation{
				RelationID:   wayID,
				OuterBorders: []int64{wayID},
			})

		case *osm.Relation:
			if !isWalkAreaRelation(obj.Tags) {
				continue
			}

			outerWayIDs := make([]int64, 0, len(obj.Members))
			for _, member := range obj.Members {
				if member.Type != osm.TypeWay {
					continue
				}

				if member.Role == "inner" {
					continue
				}

				outerWayIDs = append(outerWayIDs, member.Ref)
				areaWayIDs[member.Ref] = struct{}{}
			}

			if len(outerWayIDs) == 0 {
				continue
			}

			relations = append(relations, WalkableAreaRelation{
				RelationID:   int64(obj.ID),
				OuterBorders: outerWayIDs,
			})
		}
	}

	if err := decoder.Err(); err != nil {
		log.Fatal(err)
	}

	return relations, areaWayIDs
}

// создаем список структрук где показана связь вершин (10-20-30 и прочее) и множество всех вершин пешеходного вида
func passWays(pbfPath string, areaWayIDs map[int64]struct{}) ([]WayNodes, map[int64][]int64, map[int64]struct{}) {
	f, err := os.Open(pbfPath)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	decoder := osmpbf.New(context.Background(), f, runtime.GOMAXPROCS(-1))
	defer decoder.Close()

	decoder.SkipNodes = true
	decoder.SkipRelations = true

	needed := make(map[int64]struct{}, 1_000_000)
	ways := make([]WayNodes, 0, 200_000)
	areaWayNodes := make(map[int64][]int64, len(areaWayIDs))
	addedWayIDs := make(map[int64]struct{}, 200_000)

	for decoder.Scan() {
		v := decoder.Object()

		way, ok := v.(*osm.Way)
		if !ok {
			continue
		}

		ids := GetWayNodeIDs(way)
		_, isAreaBoundary := areaWayIDs[int64(way.ID)]

		if isAreaBoundary {
			areaWayNodes[int64(way.ID)] = ids
		}

		if !isWalkWay(way.Tags) {
			continue
		}

		for _, nodeID := range ids {
			needed[nodeID] = struct{}{}
		}

		if _, found := addedWayIDs[int64(way.ID)]; found {
			continue
		}

		ways = append(ways, WayNodes{
			NodeIDs: ids,
			WayID:   int64(way.ID),
		})
		addedWayIDs[int64(way.ID)] = struct{}{}
	}

	if err := decoder.Err(); err != nil {
		log.Fatal(err)
	}

	return ways, areaWayNodes, needed
}

func passNodes(pbfPath string, needed map[int64]struct{}) (map[int64]uint32, []int32, []int32) {
	f, err := os.Open(pbfPath)

	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	decoder := osmpbf.New(context.Background(), f, runtime.GOMAXPROCS(-1))
	defer decoder.Close()

	decoder.SkipWays = true
	decoder.SkipRelations = true

	IndxId := make(map[int64]uint32, len(needed))
	latE7 := make([]int32, 0, len(needed))
	lonE7 := make([]int32, 0, len(needed))

	var indx uint32 = 0
	for decoder.Scan() {
		v := decoder.Object()

		node, ok := v.(*osm.Node)
		if !ok {
			continue
		}

		if _, want := needed[int64(node.ID)]; !want {
			continue
		}

		IndxId[int64(node.ID)] = indx

		latE7 = append(latE7, int32(math.Round(node.Lat*1e7)))
		lonE7 = append(lonE7, int32(math.Round(node.Lon*1e7)))

		indx++
	}

	if err := decoder.Err(); err != nil {
		log.Fatal(err)
	}

	return IndxId, latE7, lonE7
}

// строим 3 массива: from, to, weight для более удобной работы с графом и последующей постройки CSR
func BuildEdges(
	ways []WayNodes,
	IndxId map[int64]uint32,
	latE7 []int32,
	lonE7 []int32,
) ([]uint32, []uint32, []uint32, []int64) {

	from := make([]uint32, 0, 1_000_000)
	to := make([]uint32, 0, 1_000_000)
	weight := make([]uint32, 0, 1_000_000)
	way_ids := make([]int64, 0, 1_000_000)

	for _, w := range ways {
		for i := 0; i+1 < len(w.NodeIDs); i++ {
			idA := w.NodeIDs[i]
			idB := w.NodeIDs[i+1]

			idxA, okA := IndxId[idA]
			idxB, okB := IndxId[idB]

			if !okA || !okB {
				continue
			}

			latA := latE7[idxA]
			lonA := lonE7[idxA]
			latB := latE7[idxB]
			lonB := lonE7[idxB]

			d := DistanceMeters(latA, lonA, latB, lonB)

			from = append(from, idxA)
			to = append(to, idxB)
			weight = append(weight, d)
			way_ids = append(way_ids, w.WayID)

			from = append(from, idxB)
			to = append(to, idxA)
			weight = append(weight, d)
			way_ids = append(way_ids, w.WayID)
		}
	}

	return from, to, weight, way_ids
}

func BuildWalkAreaEdges(areaRelations []WalkableAreaRelation, areaWayNodes map[int64][]int64, IndxId map[int64]uint32, latE7 *[]int32, lonE7 *[]int32) ([]uint32, []uint32, []uint32, []int64) {
	return []uint32{}, []uint32{}, []uint32{}, []int64{}
}

func buildCSR(
	n int,
	from []uint32,
	to []uint32,
	weight []uint32,
	way_ids []int64,
) ([]uint32, []uint32, []uint32, []int64) {

	m := len(from)
	offset := make([]uint32, n+1)

	for i := 0; i < m; i++ {
		offset[from[i]+1]++
	}

	for i := 1; i <= n; i++ {
		offset[i] += offset[i-1]
	}

	to_csr := make([]uint32, m)
	weight_csr := make([]uint32, m)
	way_id_csr := make([]int64, len(way_ids))

	choice := make([]uint32, n)
	copy(choice, offset[:n])

	for i := 0; i < m; i++ {
		u := from[i]
		position := choice[u]

		to_csr[position] = to[i]
		weight_csr[position] = weight[i]
		way_id_csr[position] = way_ids[i]

		choice[u]++
	}

	return offset, to_csr, weight_csr, way_id_csr
}

func BuildGraphFromPBF(pbfPath string) *Graph {
	areaRelations, areaWayIDs := passWalkAreas(pbfPath)

	ways, areaWayNodes, needed := passWays(pbfPath, areaWayIDs)

	IndxId, latE7, lonE7 := passNodes(pbfPath, needed)

	from, to, weight, way_ids := BuildEdges(ways, IndxId, latE7, lonE7)

	areaFrom, areaTo, areaWeight, areaWayIDsGraph := BuildWalkAreaEdges(
		areaRelations,
		areaWayNodes,
		IndxId,
		&latE7,
		&lonE7,
	)

	from = append(from, areaFrom...)
	to = append(to, areaTo...)
	weight = append(weight, areaWeight...)
	way_ids = append(way_ids, areaWayIDsGraph...)

	offset, to_csr, weight_csr, way_id_csr := buildCSR(
		len(latE7),
		from,
		to,
		weight,
		way_ids,
	)

	g := &Graph{
		LatE7:      latE7,
		LonE7:      lonE7,
		Offset:     offset,
		To_csr:     to_csr,
		Weight_csr: weight_csr,
		WayID_csr:  way_id_csr,
	}

	return g
}
