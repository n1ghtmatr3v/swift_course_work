package kdtree

type KDPoint struct {
	Vertex uint32
	X      int32
	Y      int32
}

type KDNode struct {
	Point KDPoint
	Left  *KDNode
	Right *KDNode
}
