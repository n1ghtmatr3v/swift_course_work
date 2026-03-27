package main

import (
	"test/graph"
	"test/kdtree"
)

type Server struct {
	Graph *graph.Graph
	Root  *kdtree.KDNode
}
