package main

import (
	"fmt"
	"net/http"
)

func NumberHandler(w http.ResponseWriter, r *http.Request) {
	point := r.URL.Query().Get("point")
	x := r.URL.Query().Get("x")
	y := r.URL.Query().Get("y")
	routeCount := r.URL.Query().Get("routeCount")


	if (point == "1") {
		fmt.Println("Координаты точки '1': ",x, y)
		fmt.Println("Длина пути (точек): ", routeCount)
	} else if (point == "2") {
		fmt.Println("Координаты точки '2': ",x, y)
		fmt.Println("Длина пути (точек): ", routeCount)
	} else {
		fmt.Println("Неизвестная точка")
	}

	

	w.Write([]byte("ok"))
}

func main() {

	http.HandleFunc("/number", NumberHandler)
	fmt.Println("Server started on 127.0.0.1:8080")
	http.ListenAndServe("127.0.0.1:8080", nil)

}

