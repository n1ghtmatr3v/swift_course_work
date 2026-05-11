package main

import (
	"fmt"
	"test/graph"
	"test/kdtree"
	"test/routing"
)

func makeMiniGraph() (*graph.Graph, *kdtree.KDNode) {
	latE7 := []int32{
		int32(55.0000000 * 1e7),
		int32(55.0000000 * 1e7),
		int32(55.0000000 * 1e7),
		int32(55.0000000 * 1e7),
		int32(55.0000000 * 1e7),
		int32(55.0000000 * 1e7),
		int32(55.0000000 * 1e7),
		int32(55.0000000 * 1e7),
		int32(55.0000000 * 1e7),
		int32(55.0000000 * 1e7),
		int32(55.0010000 * 1e7),
		int32(55.0010000 * 1e7),
		int32(55.0010000 * 1e7),
		int32(55.0010000 * 1e7),
		int32(55.0010000 * 1e7),
		int32(54.9990000 * 1e7),
		int32(54.9990000 * 1e7),
		int32(54.9990000 * 1e7),
		int32(54.9990000 * 1e7),
		int32(54.9990000 * 1e7),
	}

	lonE7 := []int32{
		int32(37.0000000 * 1e7),
		int32(37.0010000 * 1e7),
		int32(37.0020000 * 1e7),
		int32(37.0030000 * 1e7),
		int32(37.0040000 * 1e7),
		int32(37.0050000 * 1e7),
		int32(37.0060000 * 1e7),
		int32(37.0070000 * 1e7),
		int32(37.0080000 * 1e7),
		int32(37.0090000 * 1e7),
		int32(37.0020000 * 1e7),
		int32(37.0030000 * 1e7),
		int32(37.0040000 * 1e7),
		int32(37.0050000 * 1e7),
		int32(37.0060000 * 1e7),
		int32(37.0020000 * 1e7),
		int32(37.0030000 * 1e7),
		int32(37.0040000 * 1e7),
		int32(37.0050000 * 1e7),
		int32(37.0060000 * 1e7),
	}

	neighbors := [][]uint32{
		{1},
		{0, 2},
		{1, 3, 10, 15},
		{2, 4, 11, 16},
		{3, 5, 12, 17},
		{4, 6, 13, 18},
		{5, 7, 14, 19},
		{6, 8},
		{7, 9},
		{8},
		{2, 11},
		{10, 12, 3},
		{11, 13, 4},
		{12, 14, 5},
		{13, 6},
		{2, 16},
		{15, 17, 3},
		{16, 18, 4},
		{17, 19, 5},
		{18, 6},
	}

	offset := make([]uint32, len(neighbors)+1)
	toCSR := make([]uint32, 0)
	weightCSR := make([]uint32, 0)
	wayIDCSR := make([]int64, 0)

	cur := uint32(0)
	for i := 0; i < len(neighbors); i++ {
		offset[i] = cur
		for _, to := range neighbors[i] {
			toCSR = append(toCSR, to)
			weightCSR = append(weightCSR, graph.DistanceMeters(latE7[i], lonE7[i], latE7[to], lonE7[to]))
			wayIDCSR = append(wayIDCSR, int64(1000+i))
			cur++
		}
	}
	offset[len(neighbors)] = cur

	g := &graph.Graph{
		LatE7:      latE7,
		LonE7:      lonE7,
		Offset:     offset,
		To_csr:     toCSR,
		Weight_csr: weightCSR,
		WayID_csr:  wayIDCSR,
	}

	points := make([]kdtree.KDPoint, 0, len(latE7))
	for i := 0; i < len(latE7); i++ {
		points = append(points, kdtree.KDPoint{
			Vertex: uint32(i),
			X:      latE7[i],
			Y:      lonE7[i],
		})
	}

	root := kdtree.BuildKDtree(points, 0, len(points)-1, 0)
	return g, root
}

func printAnswer(title string, g *graph.Graph, ans graph.AnswerVirtualResult) {
	fmt.Println("---------------------------------------------------")
	fmt.Println(title)
	fmt.Println("path vertices count:", len(ans.Route.Path))
	fmt.Println("length meters:", ans.Route.LengthMeters)

	fmt.Println("startVirtual id:", ans.StartVirtual.Vertex)
	fmt.Println("startVirtual left/right:", ans.StartVirtual.LeftVertex, ans.StartVirtual.RightVertex)
	fmt.Println("startVirtual coords:",
		float64(ans.StartVirtual.LatE7)/1e7,
		float64(ans.StartVirtual.LonE7)/1e7,
	)

	fmt.Println("endVirtual id:", ans.EndVirtual.Vertex)
	fmt.Println("endVirtual left/right:", ans.EndVirtual.LeftVertex, ans.EndVirtual.RightVertex)
	fmt.Println("endVirtual coords:",
		float64(ans.EndVirtual.LatE7)/1e7,
		float64(ans.EndVirtual.LonE7)/1e7,
	)

	fmt.Println("raw path ids:")
	for i := 0; i < len(ans.Route.Path); i++ {
		fmt.Println("  ", i, "->", ans.Route.Path[i])
	}

	coords := routing.ConvertPathToCoords(g, ans)

	fmt.Println("path coords:")
	for i := 0; i < len(coords); i++ {
		fmt.Println("  ", i, "->", coords[i].Lat, coords[i].Lon)
	}
}

func DebugMiniGraph() {
	g, root := makeMiniGraph()

	latSt1 := int32(55.0002500 * 1e7)
	lonSt1 := int32(37.0035000 * 1e7)
	latEnd1 := int32(54.9997500 * 1e7)
	lonEnd1 := int32(37.0055000 * 1e7)

	ans1 := routing.BuildRouteByCoords(g, root, latSt1, lonSt1, latEnd1, lonEnd1)
	printAnswer("CASE 1", g, ans1)

	latSt2 := int32(55.0000000 * 1e7)
	lonSt2 := int32(37.0020000 * 1e7)
	latEnd2 := int32(55.0010000 * 1e7)
	lonEnd2 := int32(37.0060000 * 1e7)

	ans2 := routing.BuildRouteByCoords(g, root, latSt2, lonSt2, latEnd2, lonEnd2)
	printAnswer("CASE 2", g, ans2)

	latSt3 := int32(55.0000000 * 1e7)
	lonSt3 := int32(36.9994000 * 1e7)
	latEnd3 := int32(55.0000000 * 1e7)
	lonEnd3 := int32(37.0096000 * 1e7)

	ans3 := routing.BuildRouteByCoords(g, root, latSt3, lonSt3, latEnd3, lonEnd3)
	printAnswer("CASE 3", g, ans3)
}

func main() {
	DebugMiniGraph()
}
