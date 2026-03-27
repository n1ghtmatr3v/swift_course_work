package graph

func (g *Graph) AStar(start uint32, goal uint32) AStarResult {

	n := len(g.LatE7)
	const INF uint32 = ^uint32(0)

	parent := make([]int32, n)
	closed := make([]bool, n)
	dist := make([]uint32, n)

	for i := 0; i < n; i++ {
		dist[i] = INF
		closed[i] = false
		parent[i] = -1
	}
	dist[start] = 0

	min_heap := MinHeap{
		vector: make([]Node, 0),
	}

	start_f := g.Heuristic(start, goal)

	min_heap.Push(Node{
		vertex: start,
		f:      start_f,
	})

	for !min_heap.isEmpty() {
		current_Node := min_heap.Pop()
		v := current_Node.vertex // текущаю вершина

		if closed[v] == true {
			continue
		}

		if v == goal {

			return AStarResult{
				Path:         RestoreParent(parent, start, goal),
				LengthMeters: dist[goal],
			}
		}
		closed[v] = true

		begin := g.Offset[v]
		end := g.Offset[v+1]

		for i := begin; i < end; i++ {
			to := g.To_csr[i]    // куда ведет текущее ребро
			w := g.Weight_csr[i] // вес того куда ведет текущее ребро

			if closed[to] == true { // если закрыта то чекаем другого соседа тогда
				continue
			}

			newDist := dist[v] + w // релаксация ребра
			if newDist < dist[to] {
				dist[to] = newDist

				parent[to] = int32(v)
				newF := newDist + g.Heuristic(to, goal) // f(v) = g(v) + h(v)

				min_heap.Push(Node{
					vertex: to,
					f:      newF,
				})
			}
		}
	}
	return AStarResult{}
}

/*func (g *Graph) AStarZero(start uint32, goal uint32) []uint32 { // дейкстра
	n := len(g.LatE7)

	const INF uint32 = ^uint32(0)

	dist := make([]uint32, n)
	parent := make([]int32, n)
	closed := make([]bool, n)

	for i := 0; i < n; i++ {
		dist[i] = INF
		parent[i] = -1
		closed[i] = false
	}

	dist[start] = 0

	pq := MinHeap{
		vector: make([]Node, 0),
	}

	pq.Push(Node{
		vertex: start,
		f:      0,
	})

	for !pq.isEmpty() {
		currentNode := pq.Pop()
		v := currentNode.vertex

		if closed[v] {
			continue
		}

		if v == goal {
			return RestoreParent(parent, start, goal)
		}

		closed[v] = true

		begin := g.Offset[v]
		end := g.Offset[v+1]

		for i := begin; i < end; i++ {
			to := g.To_csr[i]
			w := g.Weight_csr[i]

			if closed[to] {
				continue
			}

			newDist := dist[v] + w

			if newDist < dist[to] {
				dist[to] = newDist
				parent[to] = int32(v)

				pq.Push(Node{
					vertex: to,
					f:      newDist,
				})
			}
		}
	}

	return nil
} */
