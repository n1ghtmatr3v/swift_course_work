package main

import (
	"log"
	"test/binary"
	"test/graph"
	"test/kdtree"
)

func main() {
	log.Println("building graph...")

	g := graph.BuildGraphFromPBF("data/Moscow.osm.pbf")

	err := binary.SaveGraph("data/graph.bin", g)
	if err != nil {
		log.Fatal(err)
	}

	log.Println("graph.bin built successfully")

	log.Println("building kdtree...")

	points := make([]kdtree.KDPoint, len(g.LatE7))
	for i := 0; i < len(g.LatE7); i++ {
		points[i] = kdtree.KDPoint{
			Vertex: uint32(i),
			X:      g.LatE7[i],
			Y:      g.LonE7[i],
		}
	}

	root := kdtree.BuildKDtree(points, 0, len(points)-1, 0)

	err = binary.SaveKDtree(root, "data/kdtree.bin")
	if err != nil {
		log.Fatal(err)
	}

	log.Println("kdtree.bin built successfully")
}
