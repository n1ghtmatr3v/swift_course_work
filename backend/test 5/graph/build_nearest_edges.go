package graph

import (
	"math"
	"sort"
	"test/kdtree"
)

type Edges struct {
	U uint32
	V uint32
}

type ProjectStruct struct {
	U        uint32
	V        uint32
	Dist2    float64
	T        float64
	ProjectX float64
	ProjectY float64
	LatE7    int32
	LonE7    int32
}

func (g *Graph) BuildVectorEdges() []Edges {
	g.EdgesOnce.Do(func() { // единожды строим спиок ребер, чтоб не создавать его несколько раз заново
		edges := make([]Edges, 0, len(g.To_csr)/2)

		for u := uint32(0); u < uint32(len(g.LatE7)); u++ {
			begin := g.Offset[u]
			end := g.Offset[u+1]

			for i := begin; i < end; i++ {
				v := g.To_csr[i]
				if u >= v {
					continue
				}

				edges = append(edges, Edges{
					U: u,
					V: v,
				})
			}
		}

		g.Edges = edges
	})

	return g.Edges
}

func CoordinateFromT(a int32, b int32, t float64) int32 {
	return int32(math.Round(float64(a) + (float64(b)-float64(a))*t))
}

func CountSamplePoints(lengthMeters uint32) int {
	count := int(math.Ceil(float64(lengthMeters) / 5.0))
	if count < 1 {
		return 1
	}

	return count
}

func AddSampleEdge(samples *[]EdgePoint, points *[]kdtree.KDPoint, edgeIndex uint32, latE7 int32, lonE7 int32) {
	sampleIndex := uint32(len(*samples))

	*samples = append(*samples, EdgePoint{
		EdgeIndex: edgeIndex,
		LatE7:     latE7,
		LonE7:     lonE7,
	})

	*points = append(*points, kdtree.KDPoint{
		Vertex: sampleIndex,
		X:      latE7,
		Y:      lonE7,
	})
}

func (g *Graph) BuildSampleEdgeIndex() (*kdtree.KDNode, []EdgePoint) {
	g.EdgePointsOnce.Do(func() {
		edges := g.BuildVectorEdges()

		samples := make([]EdgePoint, 0, len(edges))
		points := make([]kdtree.KDPoint, 0, len(edges))

		for edgeIndex, edge := range edges {
			lengthMeters := DistanceMeters(
				g.LatE7[edge.U],
				g.LonE7[edge.U],
				g.LatE7[edge.V],
				g.LonE7[edge.V],
			)

			sampleCount := CountSamplePoints(lengthMeters)

			AddSampleEdge(&samples, &points, uint32(edgeIndex), g.LatE7[edge.U], g.LonE7[edge.U])
			AddSampleEdge(&samples, &points, uint32(edgeIndex), g.LatE7[edge.V], g.LonE7[edge.V])

			for i := 0; i < sampleCount; i++ {
				t := float64(i+1) / float64(sampleCount+1)

				latE7 := CoordinateFromT(g.LatE7[edge.U], g.LatE7[edge.V], t)
				lonE7 := CoordinateFromT(g.LonE7[edge.U], g.LonE7[edge.V], t)
				AddSampleEdge(&samples, &points, uint32(edgeIndex), latE7, lonE7)
			}
		}

		g.EdgePoints = samples

		if len(points) == 0 {
			g.RootEdgePoints = nil
			return
		}

		g.RootEdgePoints = kdtree.BuildKDtree(points, 0, len(points)-1, 0)
	})

	return g.RootEdgePoints, g.EdgePoints
}

func (g *Graph) AppendEdgesFromVertex(result []Edges, visited map[[2]uint32]struct{}, vertex uint32) []Edges {
	begin := g.Offset[vertex]
	end := g.Offset[vertex+1]

	for i := begin; i < end; i++ {
		u := vertex
		v := g.To_csr[i]
		if u > v {
			u, v = v, u
		}

		key := [2]uint32{u, v}
		if _, found := visited[key]; found {
			continue
		}

		visited[key] = struct{}{}
		result = append(result, Edges{U: u, V: v})
	}

	return result
}

func (g *Graph) CreateEdgesFromVertices(vertices []uint32) []Edges {
	visited := make(map[[2]uint32]struct{}, len(vertices)*4)
	result := make([]Edges, 0, len(vertices)*6)

	for i := 0; i < len(vertices); i++ {
		result = g.AppendEdgesFromVertex(result, visited, vertices[i])
	}

	return result
}

func (g *Graph) CheckNeighbotsEdges(seed []Edges) []Edges {
	visited := make(map[[2]uint32]struct{}, len(seed)*4)
	result := make([]Edges, 0, len(seed)*6)

	for i := 0; i < len(seed); i++ {
		u := seed[i].U
		v := seed[i].V
		if u > v {
			u, v = v, u
		}

		key := [2]uint32{u, v}
		if _, found := visited[key]; !found {
			visited[key] = struct{}{}
			result = append(result, Edges{U: u, V: v})
		}

		result = g.AppendEdgesFromVertex(result, visited, seed[i].U)
		result = g.AppendEdgesFromVertex(result, visited, seed[i].V)
	}

	return result
}

func (g *Graph) FindProjectionOnSection(latQe7 int32, lonQe7 int32, edge Edges) ProjectStruct {
	latA := float64(g.LatE7[edge.U]) / 1e7
	lonA := float64(g.LonE7[edge.U]) / 1e7

	latB := float64(g.LatE7[edge.V]) / 1e7
	lonB := float64(g.LonE7[edge.V]) / 1e7

	latQ := float64(latQe7) / 1e7
	lonQ := float64(lonQe7) / 1e7

	lat0 := latQ
	lon0 := lonQ
	lat0rad := (lat0 * math.Pi) / 180.0

	xQ := 0.0
	yQ := 0.0

	xA := (lonA - lon0) * 111320.0 * math.Cos(lat0rad)
	yA := (latA - lat0) * 111320.0

	xB := (lonB - lon0) * 111320.0 * math.Cos(lat0rad)
	yB := (latB - lat0) * 111320.0

	ABx := xB - xA
	ABy := yB - yA

	AQx := xQ - xA
	AQy := yQ - yA

	AQAB := AQx*ABx + AQy*ABy
	ABAB := ABx*ABx + ABy*ABy

	if ABAB == 0 {
		dx := xQ - xA
		dy := yQ - yA
		dist2 := dx*dx + dy*dy

		projectLat := lat0 + yA/111320.0
		projectLon := lon0 + xA/(111320.0*math.Cos(lat0rad))

		return ProjectStruct{
			U:        edge.U,
			V:        edge.V,
			Dist2:    dist2,
			T:        0,
			ProjectX: xA,
			ProjectY: yA,
			LatE7:    int32(math.Round(projectLat * 1e7)),
			LonE7:    int32(math.Round(projectLon * 1e7)),
		}
	}

	t := AQAB / ABAB

	var projectX float64
	var projectY float64

	if t < 0 {
		projectX = xA
		projectY = yA
	} else if t > 1 {
		projectX = xB
		projectY = yB
	} else {
		projectX = xA + t*ABx
		projectY = yA + t*ABy
	}

	dx := xQ - projectX
	dy := yQ - projectY
	dist2 := dx*dx + dy*dy

	projectLat := lat0 + projectY/111320.0
	projectLon := lon0 + projectX/(111320.0*math.Cos(lat0rad))

	return ProjectStruct{
		U:        edge.U,
		V:        edge.V,
		Dist2:    dist2,
		T:        t,
		ProjectX: projectX,
		ProjectY: projectY,
		LatE7:    int32(math.Round(projectLat * 1e7)),
		LonE7:    int32(math.Round(projectLon * 1e7)),
	}
}

func (g *Graph) FindNearestEdge(arrayEdges []Edges, latQe7 int32, lonQe7 int32) ProjectStruct {
	minEdge := ProjectStruct{
		Dist2: math.MaxFloat64,
	}

	for i := 0; i < len(arrayEdges); i++ {
		currentEdge := g.FindProjectionOnSection(latQe7, lonQe7, arrayEdges[i])

		if currentEdge.Dist2 < minEdge.Dist2 {
			minEdge = currentEdge
		}
	}

	return minEdge
}

func (g *Graph) FindNearestEdgeBySamples(latQe7 int32, lonQe7 int32) ProjectStruct {
	return g.FindNearestEdgeBySamplesLimit(latQe7, lonQe7, 1024)
}

func (g *Graph) SearchNearestEdgesBySamplesPoints(latQe7 int32, lonQe7 int32, limit int) []Edges {
	if limit <= 0 {
		return nil
	}

	root, samples := g.BuildSampleEdgeIndex()
	if root == nil || len(samples) == 0 {
		return nil
	}

	nearestSampleID := kdtree.CreateVectorFromHeap(root, latQe7, lonQe7, limit)
	if len(nearestSampleID) == 0 {
		return nil
	}

	allEdges := g.BuildVectorEdges()
	candidateEdges := make([]Edges, 0, len(nearestSampleID))
	visited := make(map[uint32]struct{})

	for i := 0; i < len(nearestSampleID); i++ {
		sampleIndex := nearestSampleID[i]
		if int(sampleIndex) >= len(samples) {
			continue
		}

		edgeIndex := samples[sampleIndex].EdgeIndex
		if _, found := visited[edgeIndex]; found {
			continue
		}

		visited[edgeIndex] = struct{}{}
		candidateEdges = append(candidateEdges, allEdges[edgeIndex])
	}

	if len(candidateEdges) == 0 {
		return nil
	}

	return candidateEdges
}

func (g *Graph) FindNearestEdgeBySamplesLimit(latQe7 int32, lonQe7 int32, limit int) ProjectStruct {
	candidateEdges := g.SearchNearestEdgesBySamplesPoints(latQe7, lonQe7, limit)
	if len(candidateEdges) == 0 {
		return ProjectStruct{Dist2: math.MaxFloat64}
	}

	candidateEdges = g.CheckNeighbotsEdges(candidateEdges)

	return g.FindNearestEdge(candidateEdges, latQe7, lonQe7)
}

func (g *Graph) FindNearestEdgeByVertex(root *kdtree.KDNode, latQe7 int32, lonQe7 int32, limit int) ProjectStruct {
	if root == nil || limit <= 0 {
		return ProjectStruct{Dist2: math.MaxFloat64}
	}

	nearestVertices := kdtree.CreateVectorFromHeap(root, latQe7, lonQe7, limit)
	if len(nearestVertices) == 0 {
		return ProjectStruct{Dist2: math.MaxFloat64}
	}

	candidateEdges := g.CreateEdgesFromVertices(nearestVertices)
	if len(candidateEdges) == 0 {
		return ProjectStruct{Dist2: math.MaxFloat64}
	}

	candidateEdges = g.CheckNeighbotsEdges(candidateEdges)
	return g.FindNearestEdge(candidateEdges, latQe7, lonQe7)
}

func MergeUniqueEdges(groups ...[]Edges) []Edges { // передаем любое кол-во список ребер и потои убираем дубликаты
	size := 0
	for i := 0; i < len(groups); i++ {
		size += len(groups[i])
	}

	result := make([]Edges, 0, size)
	visited := make(map[[2]uint32]struct{}, size)

	for i := 0; i < len(groups); i++ {
		for j := 0; j < len(groups[i]); j++ {
			u := groups[i][j].U
			v := groups[i][j].V
			if u > v {
				u, v = v, u
			}

			key := [2]uint32{u, v}
			if _, found := visited[key]; found {
				continue
			}

			visited[key] = struct{}{}
			result = append(result, Edges{
				U: u,
				V: v,
			})
		}
	}

	return result
}

func (g *Graph) FindNearestEdgeByCompareSampleAndVerticies(root *kdtree.KDNode, latQe7 int32, lonQe7 int32, sampleLimit int, vertexLimit int) ProjectStruct {

	sampleEdges := g.SearchNearestEdgesBySamplesPoints(latQe7, lonQe7, sampleLimit)

	var vertexEdges []Edges

	if root != nil && vertexLimit > 0 {
		nearestVertices := kdtree.CreateVectorFromHeap(root, latQe7, lonQe7, vertexLimit)
		if len(nearestVertices) > 0 {
			vertexEdges = g.CreateEdgesFromVertices(nearestVertices)
		}
	}

	candidateEdges := MergeUniqueEdges(sampleEdges, vertexEdges)
	if len(candidateEdges) == 0 {
		return ProjectStruct{Dist2: math.MaxFloat64}
	}

	candidateEdges = g.CheckNeighbotsEdges(candidateEdges)
	return g.FindNearestEdge(candidateEdges, latQe7, lonQe7)
}

func (g *Graph) FindNearestEdgeByCompareCandidates(root *kdtree.KDNode, latQe7 int32, lonQe7 int32) ProjectStruct {

	return g.FindNearestEdgeByCompareSampleAndVerticies(
		root,
		latQe7,
		lonQe7,
		1024,
		64,
	)
}

func (g *Graph) FindNearestEdges(arrayEdges []Edges, latQe7 int32, lonQe7 int32, limit int) []ProjectStruct {

	if limit <= 0 {
		return nil
	}

	projects := make([]ProjectStruct, 0, len(arrayEdges))
	for i := 0; i < len(arrayEdges); i++ {
		currentEdge := g.FindProjectionOnSection(latQe7, lonQe7, arrayEdges[i])
		if currentEdge.Dist2 == math.MaxFloat64 {
			continue
		}
		projects = append(projects, currentEdge)
	}

	sort.Slice(projects, func(i int, j int) bool {
		return projects[i].Dist2 < projects[j].Dist2
	})

	if len(projects) > limit {
		projects = projects[:limit]
	}

	return projects
}
