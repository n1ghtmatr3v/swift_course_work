package main

import (
	"test/routing"
)

type RequestStruct struct {
	LatSt  float64 `json:"latSt"`
	LonSt  float64 `json:"lonSt"`
	LatEnd float64 `json:"latEnd"`
	LonEnd float64 `json:"lonEnd"`
}

type AnswerStruct struct {
	Route        []routing.RoutePoint `json:"route"`
	LengthMeters uint32               `json:"lengthMeters"`
}

type HealthResponse struct {
	Status string `json:"status"`
}

type StatsResponse struct {
	Vertexes int `json:"vertex"`
	Edges    int `json:"edges"`
}

type NearestRequest struct {
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}

type NearestResponse struct {
	Vertex uint32             `json:"vertex"`
	Point  routing.RoutePoint `json:"point"`
}

type BBoxResponse struct {
	MinLat float64 `json:"MinLat"`
	MinLon float64 `json:"MinLon"`
	MaxLat float64 `json:"MaxLat"`
	MaxLon float64 `json:"MaxLon"`
}

type RouteDebugRequest struct {
	LatSt  float64 `json:"latSt"`
	LonSt  float64 `json:"lonSt"`
	LatEnd float64 `json:"latEnd"`
	LonEnd float64 `json:"lonEnd"`
}

type RouteDebugResponse struct {
	StartNearestVertex     uint32               `json:"startNearestVertex"`
	EndNearestVertex       uint32               `json:"endNearestVertex"`
	StartNearestPoint      routing.RoutePoint   `json:"startNearestPoint"`
	EndNearestPoint        routing.RoutePoint   `json:"endNearestoint"`
	RoutePathVerticesCount int                  `json:"routeVerticesCount"`
	Route                  []routing.RoutePoint `json:"routePoints"`
	Path                   []uint32             `json:"pathIDs"`
	LengthMeters           uint32               `json:"lengthMeters"`
}
