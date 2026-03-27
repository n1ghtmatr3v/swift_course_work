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

func isWalkWay(tags osm.Tags) bool {
	true_hw := tags.Find("highway")
	if true_hw == "" {
		return false
	}

	if tags.Find("area") == "yes" {
		return false
	}

	switch true_hw {
	case "footway",
		"pedestrian",
		"path",
		"steps",
		"living_street",
		"residential",
		"service",
		"unclassified",
		"track":
	default:
		return false
	}

	/*switch true_hw {
	case "footway",
		"pedestrian",
		"steps":
	// ------
	case "path":
	foot := tags.Find("foot")
	if foot != "yes" && foot != "designated" && foot != "permissive" {
		return false
	}
	default:
		return false
	}*/

	if tags.Find("foot") == "no" {
		return false
	}

	access := tags.Find("access")
	if access == "no" || access == "private" {
		return false
	}

	// -----
	service := tags.Find("service")
	if service == "driveway" || service == "parking_aisle" || service == "private" {
		return false
	}

	if tags.Find("motorroad") == "yes" {
		return false
	}

	if tags.Find("construction") != "" {
		return false
	}

	return true
}

/*func IsOneWay(tags osm.Tags) bool {
	one_w := tags.Find("oneway")
	return one_w == "true" || one_w == "1" || one_w == "yes"
}*/

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

// создаем список структрук где показана связь вершин (10-20-30 и прочее) и множество всех вершин пешеходного вида
func passWays(pbfPath string) ([]WayNodes, map[int64]struct{}) {
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
	// резервируем память чтобы map и array делали меньше добавлений и выделений памяти

	//highwayCount := make(map[string]int)

	for decoder.Scan() {
		v := decoder.Object()

		way, ok := v.(*osm.Way)
		// пробуем превратить v в osm.Way, тк могут быть другие типы
		// ok = получилось или нет

		if !ok { // если тип не way
			continue
		}

		if !isWalkWay(way.Tags) {
			continue
		}

		//hw := way.Tags.Find("highway")
		//highwayCount[hw]++

		ids := make([]int64, 0, len(way.Nodes))
		for _, n := range way.Nodes {
			ids = append(ids, int64(n.ID))
			needed[int64(n.ID)] = struct{}{}
		}

		ways = append(ways, WayNodes{
			NodeIDs: ids,
			WayID:   int64(way.ID), // ---
		})
	}

	if err := decoder.Err(); err != nil {
		log.Fatal(err)
	}

	/*log.Println("highway stats:")
	for hw, count := range highwayCount {
		log.Println(hw, "=", count)
	}

	log.Println("passWays result:")
	log.Println("ways =", len(ways))
	log.Println("needed nodes =", len(needed))*/

	return ways, needed
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

		if _, want := needed[int64(node.ID)]; !want { // есть ли node в needed нашем множестве ?
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
) ([]uint32, []uint32, []uint32, []int64) { // -----

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

func buildCSR(
	n int,
	from []uint32,
	to []uint32,
	weight []uint32,
	way_ids []int64,
) ([]uint32, []uint32, []uint32, []int64) {

	m := len(from)
	offset := make([]uint32, n+1)

	for i := 0; i < m; i++ { // считаем кол-во исходящий ребер у вершины
		offset[from[i]+1]++
	}

	for i := 1; i <= n; i++ { // считаем префикс суммы, чтобы в массиве лежали индексы начала и конца соседей вершин
		offset[i] += offset[i-1]
	}

	to_csr := make([]uint32, m)
	weight_csr := make([]uint32, m)
	way_id_csr := make([]int64, len(way_ids))

	// создаем доп массив чтобы разложить ребра в to и weight в правильном порядке чтоб были подряд по вершинам
	choice := make([]uint32, n)
	copy(choice, offset[:n]) // не берем ласт элемент тк он берется тока для границы в offset

	// кладем по местам
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
	ways, needed := passWays(pbfPath)

	IndxId, latE7, lonE7 := passNodes(pbfPath, needed)

	from, to, weight, way_ids := BuildEdges(ways, IndxId, latE7, lonE7)

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

/*func BuildGraphFromPBF(pbfPath string) *Graph {
	ways, needed := passWays(pbfPath)
	log.Println("after passWays:")
	log.Println("ways =", len(ways))
	log.Println("needed nodes =", len(needed))

	IndxId, latE7, lonE7 := passNodes(pbfPath, needed)
	log.Println("after passNodes:")
	log.Println("indexed nodes =", len(IndxId))
	log.Println("latE7 =", len(latE7))
	log.Println("lonE7 =", len(lonE7))

	from, to, weight, way_ids := BuildEdges(ways, IndxId, latE7, lonE7)
	log.Println("after BuildEdges:")
	log.Println("from =", len(from))
	log.Println("to =", len(to))
	log.Println("weight =", len(weight))
	log.Println("way_ids =", len(way_ids))

	offset, to_csr, weight_csr, way_id_csr := buildCSR(
		len(latE7),
		from,
		to,
		weight,
		way_ids,
	)
	log.Println("after buildCSR:")
	log.Println("offset =", len(offset))
	log.Println("to_csr =", len(to_csr))
	log.Println("weight_csr =", len(weight_csr))
	log.Println("way_id_csr =", len(way_id_csr))

	g := &Graph{
		LatE7:      latE7,
		LonE7:      lonE7,
		Offset:     offset,
		To_csr:     to_csr,
		Weight_csr: weight_csr,
		WayID_csr:  way_id_csr,
	}

	log.Println("final graph:")
	log.Println("vertices =", len(g.LatE7))
	log.Println("edges =", len(g.To_csr))

	return g
}*/
