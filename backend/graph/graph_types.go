package graph

type WayNodes struct {
	NodeIDs []int64 // список id nodes, которые составляют путь
	WayID   int64   // айди ребра
}

type Edge struct {
	U uint32 // индекс 1 вершины
	V uint32 // индекс 2 вершины
	W uint32 // вес реба (метры)
}

type Graph struct {
	LatE7      []int32
	LonE7      []int32
	Offset     []uint32
	To_csr     []uint32
	Weight_csr []uint32
	WayID_csr  []int64
}
