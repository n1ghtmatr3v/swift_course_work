package graph

type AStarResult struct {
	Path         []uint32
	LengthMeters uint32
}

type AnswerVirtualResult struct {
	Route        AStarResult
	StartVirtual VirtualVertex
	EndVirtual   VirtualVertex
}

func (g *Graph) Heuristic(start uint32, goal uint32, startVirtual VirtualVertex, endVirtual VirtualVertex) uint32 {

	lat1, lon1 := g.GetVertexCoords(start, startVirtual, endVirtual)
	lat2, lon2 := g.GetVertexCoords(goal, startVirtual, endVirtual)

	return DistanceMeters(lat1, lon1, lat2, lon2)
}

func RestoreParent(parent []int32, start uint32, goal uint32) []uint32 {
	path := make([]uint32, 0)

	i := int32(goal)
	for true {
		if i == -1 {
			break
		}

		path = append(path, uint32(i))

		if uint32(i) == start {
			break
		}

		i = int32(parent[i])
	}

	if len(path) == 0 || path[len(path)-1] != start {
		return nil
	}

	left := 0
	right := len(path) - 1

	for left < right {
		path[left], path[right] = path[right], path[left]

		left++
		right--
	}

	return path
}
