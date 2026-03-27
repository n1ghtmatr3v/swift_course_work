package main

import (
	"log"
	"net/http"
	"test/binary"
)

func main() {

	g, err := binary.LoadGraph("data/graph.bin")
	if err != nil {
		log.Fatal(err)
	}
	root, err := binary.LoadKDtree("data/kdtree.bin")
	if err != nil {
		log.Fatal(err)
	}

	server := &Server{
		Graph: g,
		Root:  root,
	}

	http.HandleFunc("/route", server.routeHandler)
	http.HandleFunc("/health", server.healthHandler)
	http.HandleFunc("/stats", server.statsHandler)
	http.HandleFunc("/nearest", server.nearestHandler)
	http.HandleFunc("/bbox", server.bboxHandler)
	http.HandleFunc("/route-debug", server.routedebugHandler)

	log.Println("server started on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))

}
