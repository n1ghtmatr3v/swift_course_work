package routing

import (
	"math"
	"test/graph"
	"test/kdtree"
)

func BuildRouteWithVirtual(g *graph.Graph, start_nearest_edge graph.ProjectStruct, end_nearest_edge graph.ProjectStruct) graph.AnswerVirtualResult {
	var start uint32
	var goal uint32

	var startVirtual graph.VirtualVertex
	var endVirtual graph.VirtualVertex

	startVirtual.Vertex = ^uint32(0)
	endVirtual.Vertex = ^uint32(0)

	startVirtual.LeftVertex = ^uint32(0)
	startVirtual.RightVertex = ^uint32(0)

	endVirtual.LeftVertex = ^uint32(0)
	endVirtual.RightVertex = ^uint32(0)

	if start_nearest_edge.T <= 0 {
		start = start_nearest_edge.U
	} else if start_nearest_edge.T >= 1 {
		start = start_nearest_edge.V
	} else {
		startVirtual.LeftVertex = start_nearest_edge.U
		startVirtual.RightVertex = start_nearest_edge.V
		startVirtual.LatE7 = start_nearest_edge.LatE7
		startVirtual.LonE7 = start_nearest_edge.LonE7
		startVirtual.Vertex = uint32(len(g.LatE7))

		startVirtual.DistToLeft = graph.DistanceMeters(
			startVirtual.LatE7,
			startVirtual.LonE7,
			g.LatE7[start_nearest_edge.U],
			g.LonE7[start_nearest_edge.U],
		)

		startVirtual.DistToRight = graph.DistanceMeters(
			startVirtual.LatE7,
			startVirtual.LonE7,
			g.LatE7[start_nearest_edge.V],
			g.LonE7[start_nearest_edge.V],
		)

		start = startVirtual.Vertex
	}

	if end_nearest_edge.T <= 0 {
		goal = end_nearest_edge.U
	} else if end_nearest_edge.T >= 1 {
		goal = end_nearest_edge.V
	} else {
		endVirtual.LeftVertex = end_nearest_edge.U
		endVirtual.RightVertex = end_nearest_edge.V
		endVirtual.Vertex = uint32(len(g.LatE7) + 1)
		endVirtual.LatE7 = end_nearest_edge.LatE7
		endVirtual.LonE7 = end_nearest_edge.LonE7

		endVirtual.DistToLeft = graph.DistanceMeters(
			endVirtual.LatE7,
			endVirtual.LonE7,
			g.LatE7[end_nearest_edge.U],
			g.LonE7[end_nearest_edge.U],
		)

		endVirtual.DistToRight = graph.DistanceMeters(
			endVirtual.LatE7,
			endVirtual.LonE7,
			g.LatE7[end_nearest_edge.V],
			g.LonE7[end_nearest_edge.V],
		)

		goal = endVirtual.Vertex
	}

	routePath := g.AStar(start, goal, startVirtual, endVirtual)

	return graph.AnswerVirtualResult{
		Route:        routePath,
		StartVirtual: startVirtual,
		EndVirtual:   endVirtual,
	}
}

func BuildRouteByCoords(g *graph.Graph, root *kdtree.KDNode, latSt int32, lonSt int32, latEnd int32, lonEnd int32) graph.AnswerVirtualResult {

	start_nearest_edge := g.FindNearestEdgeByCompareCandidates(root, latSt, lonSt)
	end_nearest_edge := g.FindNearestEdgeByCompareCandidates(root, latEnd, lonEnd)

	if start_nearest_edge.Dist2 == math.MaxFloat64 || end_nearest_edge.Dist2 == math.MaxFloat64 {
		return graph.AnswerVirtualResult{}
	}

	return BuildRouteWithVirtual(g, start_nearest_edge, end_nearest_edge)
}

func ConvertPathToCoords(g *graph.Graph, route_path graph.AnswerVirtualResult) []RoutePoint {
	var route_points []RoutePoint

	var graphLat float64
	var graphLon float64

	for i := 0; i < len(route_path.Route.Path); i++ {
		v := route_path.Route.Path[i]

		if v == route_path.StartVirtual.Vertex {
			graphLat = float64(route_path.StartVirtual.LatE7) / 1e7
			graphLon = float64(route_path.StartVirtual.LonE7) / 1e7
		} else if v == route_path.EndVirtual.Vertex {
			graphLat = float64(route_path.EndVirtual.LatE7) / 1e7
			graphLon = float64(route_path.EndVirtual.LonE7) / 1e7
		} else {
			graphLat = float64(g.LatE7[v]) / 1e7
			graphLon = float64(g.LonE7[v]) / 1e7
		}

		point := RoutePoint{
			Lat: graphLat,
			Lon: graphLon,
		}

		route_points = append(route_points, point)
	}
	return route_points
}
