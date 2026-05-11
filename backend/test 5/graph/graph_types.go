package graph

import (
	"sync"
	"test/kdtree"
)

type WayNodes struct {
	NodeIDs []int64 // список id nodes, которые составляют путь
	WayID   int64   // айди ребра
}

type Edge struct {
	U uint32 // индекс 1 вершины
	V uint32 // индекс 2 вершины
	W uint32 // вес реба (метры)
}

type EdgePoint struct {
	EdgeIndex uint32
	LatE7     int32
	LonE7     int32
}

type Graph struct {
	LatE7      []int32
	LonE7      []int32
	Offset     []uint32
	To_csr     []uint32
	Weight_csr []uint32
	WayID_csr  []int64

	Edges []Edges

	EdgePoints     []EdgePoint
	RootEdgePoints *kdtree.KDNode

	EdgesOnce      sync.Once
	EdgePointsOnce sync.Once
}
