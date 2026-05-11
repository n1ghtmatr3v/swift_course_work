package graph

import (
	"math"
	"test/kdtree"
)

type FlagPointResult struct {
	Vertex             uint32
	LatE7              int32
	LonE7              int32
	isSnapped          bool
	SnapDistanceMeters uint32
}

func ProjectVertexForFlag(edge ProjectStruct) uint32 {
	if edge.T >= 0.5 {
		return edge.V
	}

	return edge.U
}

func (g *Graph) PointNearToFlag(root *kdtree.KDNode, latE7 int32, lonE7 int32) FlagPointResult {

	nearestVertex := kdtree.FindNearestVertex(root, latE7, lonE7)
	nearestPoint := kdtree.FindNearestPoint(root, latE7, lonE7)

	answer := FlagPointResult{
		Vertex:             nearestVertex,
		LatE7:              nearestPoint.X,
		LonE7:              nearestPoint.Y,
		isSnapped:          false,
		SnapDistanceMeters: 0,
	}

	nearestEdge := g.FindNearestEdgeByCompareSampleAndVerticies(
		root,
		latE7,
		lonE7,
		4096,
		192,
	)

	if nearestEdge.Dist2 == math.MaxFloat64 {
		return answer
	}

	snapDistanceMeters := uint32(math.Round(math.Sqrt(nearestEdge.Dist2)))
	if snapDistanceMeters <= 2 {
		return FlagPointResult{
			Vertex:             ProjectVertexForFlag(nearestEdge),
			LatE7:              latE7,
			LonE7:              lonE7,
			isSnapped:          false,
			SnapDistanceMeters: snapDistanceMeters,
		}
	}

	return FlagPointResult{
		Vertex:             ProjectVertexForFlag(nearestEdge),
		LatE7:              nearestEdge.LatE7,
		LonE7:              nearestEdge.LonE7,
		isSnapped:          true,
		SnapDistanceMeters: snapDistanceMeters,
	}
}
