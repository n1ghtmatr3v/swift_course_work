package kdtree

func DistanceSquared(p1 KDPoint, p2 KDPoint) int64 {
	dx := int64(p1.X - p2.X)
	dy := int64(p1.Y - p2.Y)

	return dx*dx + dy*dy
}

func DistanceToSplitLine(node_point KDPoint, Q KDPoint, axis int) int64 {
	difference := int64(CoordinateByAxis(Q, axis)) - int64(CoordinateByAxis(node_point, axis))
	return difference * difference
}

func CoordinateByAxis(p KDPoint, axis int) int32 {
	if axis == 0 {
		return p.X
	}
	return p.Y
}

// возвращает индекс среднего элемента first-middle-last
func MedianOfThree(points []KDPoint, left int, right int, axis int) int {
	mid := (left + right) / 2

	i := left
	j := mid
	k := right

	if CoordinateByAxis(points[i], axis) > CoordinateByAxis(points[j], axis) {
		i, j = j, i
	}

	if CoordinateByAxis(points[j], axis) > CoordinateByAxis(points[k], axis) {
		j, k = k, j
	}

	if CoordinateByAxis(points[i], axis) > CoordinateByAxis(points[j], axis) {
		i, j = j, i
	}

	return j
}

func Partition(points []KDPoint, left int, right int, axis int) int {
	indx_pivot := MedianOfThree(points, left, right, axis)
	pivot := points[indx_pivot]
	pivotValue := CoordinateByAxis(pivot, axis)

	points[indx_pivot], points[right] = points[right], points[indx_pivot]

	storeIndex := left
	for nowIndex := left; nowIndex < right; nowIndex++ {
		if CoordinateByAxis(points[nowIndex], axis) <= pivotValue {
			points[nowIndex], points[storeIndex] = points[storeIndex], points[nowIndex]
			storeIndex++
		}
	}

	points[storeIndex], points[right] = points[right], points[storeIndex]
	return storeIndex
}

func QuickSelect(points []KDPoint, left int, right int, k int, axis int) int {
	storeIndex := Partition(points, left, right, axis)

	if storeIndex == k {
		return storeIndex
	}
	if storeIndex > k {
		return QuickSelect(points, left, storeIndex-1, k, axis)
	}

	return QuickSelect(points, storeIndex+1, right, k, axis)
}

func BuildKDtree(points []KDPoint, left int, right int, depth int) *KDNode {

	if left > right {
		return nil
	}

	axis := depth % 2
	mid := (left + right) / 2

	QuickSelect(points, left, right, mid, axis) // [   | все < pivot |   pivot   | все > pivot |   ]

	node := &KDNode{
		Point: points[mid],
		Left:  nil,
		Right: nil,
	}

	node.Left = BuildKDtree(points, left, mid-1, depth+1)
	node.Right = BuildKDtree(points, mid+1, right, depth+1)

	return node
}

func NearestSearch(node *KDNode, Q KDPoint, depth int, bestDist *int64, bestPoint **KDNode) {

	if node == nil {
		return
	}

	axis := depth % 2

	tempDist := DistanceSquared(node.Point, Q)
	if tempDist < *bestDist {
		*bestDist = tempDist
		*bestPoint = node
	}

	var firstChield *KDNode
	var secondChield *KDNode

	if CoordinateByAxis(Q, axis) < CoordinateByAxis(node.Point, axis) {
		firstChield = node.Left
		secondChield = node.Right
	} else {
		firstChield = node.Right
		secondChield = node.Left
	}

	NearestSearch(firstChield, Q, depth+1, bestDist, bestPoint)
	// (8 ,7)

	planeDist := DistanceToSplitLine(node.Point, Q, axis)
	if planeDist <= *bestDist {
		NearestSearch(secondChield, Q, depth+1, bestDist, bestPoint)
	}
}

func FindNearestVertex(root *KDNode, x int32, y int32) uint32 {

	Q := KDPoint{
		Vertex: 0,
		X:      x,
		Y:      y,
	}

	var bestPoint *KDNode = nil
	bestDist := int64(1 << 62)
	NearestSearch(root, Q, 0, &bestDist, &bestPoint)

	if bestPoint == nil {
		return 0
	}

	return bestPoint.Point.Vertex
}

func FindNearestPoint(root *KDNode, x int32, y int32) KDPoint {

	Q := KDPoint{
		Vertex: 0,
		X:      x,
		Y:      y,
	}

	var bestPoint *KDNode = nil
	bestDist := int64(1 << 62)
	NearestSearch(root, Q, 0, &bestDist, &bestPoint)

	if bestPoint == nil {
		return KDPoint{}
	}

	return bestPoint.Point
}

// --------------------------

func PushCurrentNode(heap *MaxHeap, k int, d Node) {
	if k <= 0 {
		return
	}

	if heap.Len() < k {
		heap.Push(d)
		return
	}

	if d.Distance < heap.Top().Distance {
		heap.Pop()
		heap.Push(d)
	}
}

func NearestSearchKPoints(root *KDNode, Q KDPoint, depth int, k int, heap *MaxHeap) {
	if root == nil {
		return
	}

	axis := depth % 2

	distance := DistanceSquared(root.Point, Q)

	d := Node{
		vertex:   root.Point.Vertex,
		Distance: distance,
	}

	PushCurrentNode(heap, k, d)

	var firstChield *KDNode
	var secondChield *KDNode

	if CoordinateByAxis(Q, axis) < CoordinateByAxis(root.Point, axis) {
		firstChield = root.Left
		secondChield = root.Right
	} else {
		firstChield = root.Right
		secondChield = root.Left
	}

	NearestSearchKPoints(firstChield, Q, depth+1, k, heap)
	// (8 ,7)

	planeDist := DistanceToSplitLine(root.Point, Q, axis)
	if heap.Len() < k || planeDist <= heap.Top().Distance {
		NearestSearchKPoints(secondChield, Q, depth+1, k, heap)
	}
}

func CreateVectorFromHeap(root *KDNode, x int32, y int32, k int) []uint32 {

	if root == nil || k <= 0 {
		return []uint32{}
	}

	Q := KDPoint{
		X: x,
		Y: y,
	}

	heap := &MaxHeap{}
	NearestSearchKPoints(root, Q, 0, k, heap)

	vector := make([]uint32, heap.Len())
	for i := heap.Len() - 1; i >= 0; i-- {
		popElement := heap.Pop()
		vector[i] = popElement.vertex
	}
	return vector
}
