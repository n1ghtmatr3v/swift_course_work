package kdtree

type Node struct {
	vertex   uint32
	Distance int64
}

type MaxHeap struct {
	vector []Node
}

func (x *MaxHeap) Len() int {
	return len(x.vector)
}

func (x *MaxHeap) isEmpty() bool {
	return len(x.vector) == 0
}

func (x *MaxHeap) siftUP(i int) {
	for i > 0 {
		parent := (i - 1) / 2

		if x.vector[i].Distance < x.vector[parent].Distance {
			break
		}

		x.vector[i], x.vector[parent] = x.vector[parent], x.vector[i]

		i = parent
	}
}

func (x *MaxHeap) siftDown(i int) {

	for true {
		left := 2*i + 1
		right := 2*i + 2

		max_element := i

		if left < len(x.vector) && x.vector[max_element].Distance < x.vector[left].Distance {
			max_element = left
		}

		if right < len(x.vector) && x.vector[max_element].Distance < x.vector[right].Distance {
			max_element = right
		}

		if max_element == i {
			break
		}

		x.vector[i], x.vector[max_element] = x.vector[max_element], x.vector[i]
		i = max_element
	}
}

func (x *MaxHeap) Push(d Node) {
	x.vector = append(x.vector, d)
	x.siftUP(len(x.vector) - 1)
}

func (x *MaxHeap) Pop() Node {

	pop_el := x.vector[0]
	last_index := len(x.vector) - 1

	x.vector[0] = x.vector[last_index]
	x.vector = x.vector[:last_index]
	if len(x.vector) > 0 {
		x.siftDown(0)
	}

	return pop_el
}

func (x *MaxHeap) Top() Node {
	return x.vector[0]
}
