package routing

import (
	"test/graph"
	"test/kdtree"
)

func BuildRouteByCoords(g *graph.Graph,
	root *kdtree.KDNode,
	latSt int32,
	lonSt int32,
	latEnd int32,
	lonEnd int32) graph.AStarResult {

	startVertex := kdtree.FindNearestVertex(root, latSt, lonSt)
	endVertex := kdtree.FindNearestVertex(root, latEnd, lonEnd)

	route_path := g.AStar(startVertex, endVertex)

	return route_path
}

func ConvertPathToCoords(g *graph.Graph, route_path graph.AStarResult) []RoutePoint {

	var route_points []RoutePoint

	for i := 0; i < len(route_path.Path); i++ {
		v := route_path.Path[i]
		point := RoutePoint{
			Lat: float64(g.LatE7[v]) / 1e7,
			Lon: float64(g.LonE7[v]) / 1e7,
		}

		route_points = append(route_points, point)
	}
	return route_points
}
