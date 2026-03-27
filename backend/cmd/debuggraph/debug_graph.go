package main

import (
	"fmt"
	"log"
	"test/binary"
	"test/graph"
	"test/kdtree"
	"test/routing"
)

func printVertex(g *graph.Graph, v uint32, title string) {
	fmt.Println("===================================")
	fmt.Println(title)
	fmt.Println("vertex:", v)
	fmt.Println("coords:", float64(g.LatE7[v])/1e7, float64(g.LonE7[v])/1e7)

	start := g.Offset[v]
	end := g.Offset[v+1]

	fmt.Println("neighbors count:", end-start)

	for i := start; i < end; i++ {
		to := g.To_csr[i]
		wayID := g.WayID_csr[i]
		weight := g.Weight_csr[i]

		fmt.Println("-----")
		fmt.Println("to vertex:", to)
		fmt.Println("to coords:", float64(g.LatE7[to])/1e7, float64(g.LonE7[to])/1e7)
		fmt.Println("way id:", wayID)
		fmt.Println("weight:", weight)
	}
}

func findVertexInPath(path []uint32, target uint32) int {
	for i := 0; i < len(path); i++ {
		if path[i] == target {
			return i
		}
	}
	return -1
}

func printPathWindow(g *graph.Graph, path []uint32, center int, radius int) {
	left := center - radius
	if left < 0 {
		left = 0
	}

	right := center + radius
	if right >= len(path) {
		right = len(path) - 1
	}

	fmt.Println("===================================")
	fmt.Println("PATH WINDOW")
	fmt.Println("from index:", left, "to index:", right)

	for i := left; i <= right; i++ {
		v := path[i]
		fmt.Println(
			"index:", i,
			"vertex:", v,
			"coords:", float64(g.LatE7[v])/1e7, float64(g.LonE7[v])/1e7,
		)
	}
}

func main() {
	g, err := binary.LoadGraph("data/graph.bin")
	if err != nil {
		log.Fatal(err)
	}

	root, err := binary.LoadKDtree("data/kdtree.bin")
	if err != nil {
		log.Fatal(err)
	}

	// спорная точка
	lat := int32(55.8795969 * 1e7)
	lon := int32(37.4812756 * 1e7)

	targetWays := map[int64]bool{
		235500001: true,
		302378715: true,
		5170228:   true,
		379703830: true,
		550124588: true,
	}

	vertex := kdtree.FindNearestVertex(root, lat, lon)

	fmt.Println("nearest vertex:", vertex)
	fmt.Println("nearest coords:", float64(g.LatE7[vertex])/1e7, float64(g.LonE7[vertex])/1e7)

	start := g.Offset[vertex]
	end := g.Offset[vertex+1]

	fmt.Println("===================================")
	fmt.Println("CENTER VERTEX NEIGHBORS")
	fmt.Println("neighbors count:", end-start)

	for i := start; i < end; i++ {
		to := g.To_csr[i]
		wayID := g.WayID_csr[i]
		weight := g.Weight_csr[i]

		mark := ""
		if targetWays[wayID] {
			mark = "   <=== TARGET WAY"
		}

		fmt.Println("-----")
		fmt.Println("edge index:", i)
		fmt.Println("to vertex:", to)
		fmt.Println("to coords:", float64(g.LatE7[to])/1e7, float64(g.LonE7[to])/1e7)
		fmt.Println("way id:", wayID, mark)
		fmt.Println("weight:", weight)
	}

	fmt.Println("===================================")
	fmt.Println("SECOND LEVEL")

	for i := start; i < end; i++ {
		to := g.To_csr[i]
		title := fmt.Sprintf("neighbors of vertex %d", to)
		printVertex(g, to, title)
	}

	// маршрут из твоих тестовых точек
	latStE7 := int32(55.8905505 * 1e7)
	lonStE7 := int32(37.4838629 * 1e7)
	latEndE7 := int32(55.7577416 * 1e7)
	lonEndE7 := int32(37.5378913 * 1e7)

	path := routing.BuildRouteByCoords(g, root, latStE7, lonStE7, latEndE7, lonEndE7)

	fmt.Println("===================================")
	fmt.Println("ROUTE DEBUG")
	fmt.Println("path length:", len(path.Path))

	targetVertices := []uint32{
		29791,
		646016,
		736376,
		874758,
	}

	for _, target := range targetVertices {
		pos := findVertexInPath(path.Path, target)
		if pos == -1 {
			fmt.Println("vertex", target, "NOT FOUND in path")
		} else {
			fmt.Println("vertex", target, "FOUND in path at index", pos)
			printPathWindow(g, path.Path, pos, 5)
		}
	}
}
