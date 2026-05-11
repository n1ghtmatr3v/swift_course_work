package graph

type VirtualVertex struct {
	LeftVertex  uint32
	RightVertex uint32
	ProjectX    float64
	ProjectY    float64
	DistToLeft  uint32
	DistToRight uint32
	Vertex      uint32
	LatE7       int32
	LonE7       int32
}

type AllNeighbors struct {
	Vertex uint32
	Weight uint32
}

func isVirtualOnSameEdge(a VirtualVertex, b VirtualVertex) bool {
	if a.Vertex == ^uint32(0) || b.Vertex == ^uint32(0) {
		return false
	}

	return a.LeftVertex == b.LeftVertex && a.RightVertex == b.RightVertex
}

func DistanceBetweenVirtuals(a VirtualVertex, b VirtualVertex) uint32 {
	if isVirtualOnSameEdge(a, b) == false {
		return 0
	}

	if a.DistToLeft >= b.DistToLeft {
		return a.DistToLeft - b.DistToLeft
	}

	return b.DistToLeft - a.DistToLeft
}

func (g *Graph) GetAllNeighbors(vertex uint32, startVirtual VirtualVertex, endVirtual VirtualVertex) []AllNeighbors {

	neighbors := make([]AllNeighbors, 0)

	if vertex == startVirtual.Vertex {
		neighbors = append(neighbors, AllNeighbors{
			Vertex: startVirtual.LeftVertex,
			Weight: startVirtual.DistToLeft,
		})
		neighbors = append(neighbors, AllNeighbors{
			Vertex: startVirtual.RightVertex,
			Weight: startVirtual.DistToRight,
		})

		if isVirtualOnSameEdge(startVirtual, endVirtual) {
			neighbors = append(neighbors, AllNeighbors{
				Vertex: endVirtual.Vertex,
				Weight: DistanceBetweenVirtuals(startVirtual, endVirtual),
			})
		}

		return neighbors
	}

	if vertex == endVirtual.Vertex {
		neighbors = append(neighbors, AllNeighbors{
			Vertex: endVirtual.LeftVertex,
			Weight: endVirtual.DistToLeft,
		})
		neighbors = append(neighbors, AllNeighbors{
			Vertex: endVirtual.RightVertex,
			Weight: endVirtual.DistToRight,
		})

		if isVirtualOnSameEdge(startVirtual, endVirtual) {
			neighbors = append(neighbors, AllNeighbors{
				Vertex: startVirtual.Vertex,
				Weight: DistanceBetweenVirtuals(startVirtual, endVirtual),
			})
		}

		return neighbors
	}

	begin := g.Offset[vertex]
	end := g.Offset[vertex+1]

	for i := begin; i < end; i++ {
		neighbors = append(neighbors, AllNeighbors{
			Vertex: g.To_csr[i],
			Weight: g.Weight_csr[i],
		})
	}

	if vertex == startVirtual.LeftVertex {
		neighbors = append(neighbors, AllNeighbors{
			Vertex: startVirtual.Vertex,
			Weight: startVirtual.DistToLeft,
		})
	} else if vertex == startVirtual.RightVertex {
		neighbors = append(neighbors, AllNeighbors{
			Vertex: startVirtual.Vertex,
			Weight: startVirtual.DistToRight,
		})
	}

	if vertex == endVirtual.LeftVertex {
		neighbors = append(neighbors, AllNeighbors{
			Vertex: endVirtual.Vertex,
			Weight: endVirtual.DistToLeft,
		})
	} else if vertex == endVirtual.RightVertex {
		neighbors = append(neighbors, AllNeighbors{
			Vertex: endVirtual.Vertex,
			Weight: endVirtual.DistToRight,
		})
	}

	return neighbors
}

func (g *Graph) GetVertexCoords(vertex uint32, startVirtual VirtualVertex, endVirtual VirtualVertex) (int32, int32) {
	if vertex == startVirtual.Vertex {
		return startVirtual.LatE7, startVirtual.LonE7
	}

	if vertex == endVirtual.Vertex {
		return endVirtual.LatE7, endVirtual.LonE7
	}

	return g.LatE7[vertex], g.LonE7[vertex]
}
