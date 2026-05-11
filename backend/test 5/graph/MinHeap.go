package graph

type Node struct {
	vertex uint32
	f      uint32
}

type MinHeap struct { // min - куча
	vector []Node
}

func (x *MinHeap) Len() int {
	return len(x.vector)
}

func (x *MinHeap) isEmpty() bool {
	return len(x.vector) == 0
}

func (x *MinHeap) siftUP(i int) {
	for i > 0 {
		parent := (i - 1) / 2

		if x.vector[parent].f <= x.vector[i].f {
			break
		}

		x.vector[parent], x.vector[i] = x.vector[i], x.vector[parent]
		i = parent
	}
}

func (x *MinHeap) siftDown(i int) {

	for true {
		left := 2*i + 1
		right := 2*i + 2

		min_element := i

		if left < len(x.vector) && x.vector[left].f < x.vector[min_element].f {
			min_element = left
		}

		if right < len(x.vector) && x.vector[right].f < x.vector[min_element].f {
			min_element = right
		}

		if min_element == i {
			break
		}

		x.vector[i], x.vector[min_element] = x.vector[min_element], x.vector[i]
		i = min_element
	}
}

func (x *MinHeap) Push(a Node) {
	x.vector = append(x.vector, a)
	x.siftUP(len(x.vector) - 1)
}

func (x *MinHeap) Pop() Node {
	minEl := x.vector[0]
	last_index := len(x.vector) - 1

	x.vector[0] = x.vector[last_index]
	x.vector = x.vector[:last_index]
	if len(x.vector) > 0 {
		x.siftDown(0)
	}

	return minEl
}
