//
//  ContentView.swift
//  course_work
//
//  Created by Капульцевич Георгий Константинович on 13.01.2026.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
}

struct ContentView: View {
    
    let points = [
        MapPoint(coordinate: CLLocationCoordinate2D(
            latitude: 55.7558,
            longitude: 37.6173), name: "Старт"
        ),
        MapPoint(coordinate: CLLocationCoordinate2D (
            latitude: 55.7600,
            longitude: 37.6300
        ), name: "Финиш")
    ]
    
    @State private var route: [CLLocationCoordinate2D] = []
    
    
    
    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D (
            latitude: (points[0].coordinate.latitude + points[1].coordinate.latitude)/2,
            longitude: (points[0].coordinate.longitude + points[1].coordinate.longitude)/2
        )
    }
    
    let span = MKCoordinateSpan(
        latitudeDelta: 0.015,
        longitudeDelta: 0.015
    )
    
    
    var body: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(center: center, span: span))) {
                ForEach(points) { item in
                    Marker(item.name, coordinate: item.coordinate)
                }
                
                if (route.count > 1) {
                    let polyline = MKPolyline(coordinates: route, count: route.count)
                    MapPolyline(polyline)
                        .stroke(.blue,
                                style: StrokeStyle(
                                    lineWidth: 4,
                                    lineCap: .butt,
                                    dash: [3, 3]
                                )
                        )
                }
            }
        
            .mapStyle(.hybrid)
            .ignoresSafeArea()
        
        Button ("Посторить маршрут") {
            let start = points[0].coordinate
            let end = points[1].coordinate
            route = BuildRout(start: start, end: end, steps: 50)
        }
        
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 24)
        
        Button ("Очистить маршрут") {
            route.removeAll()
        }
        
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 24)
        
        Button("Отправить Координаты точки 1") {
            
            sendPoint(1,
                      points[0].coordinate.latitude,
                      points[0].coordinate.longitude
            )
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 24)
        
        Button("Отправить Координаты точки 2") {
            
            sendPoint(2,
                      points[1].coordinate.latitude,
                      points[1].coordinate.longitude
            )
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 24)
    }
    
    func BuildRout(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D, steps: Int) -> [CLLocationCoordinate2D] {
        
        if (steps <= 0) {
            return [start, end]
        }
        
        var result: [CLLocationCoordinate2D] = []
        
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            
            let lat = start.latitude + t * (end.latitude - start.latitude)
            let long = start.longitude + t * (end.longitude - start.longitude)
            
            result.append(CLLocationCoordinate2D(
                latitude: lat,
                longitude: long))
        }
        
        return result
    }
    
    
    
    
    
    func sendPoint(_ point: Int, _ x: Double, _ y: Double) {
        let routeCount = route.count
        let url = URL(string: "http://127.0.0.1:8080/number?point=\(point)&x=\(x)&y=\(y)&routeCount=\(routeCount)")!
        URLSession.shared.dataTask(with: url).resume()
    }
    
    
        
    
}

#Preview {
    ContentView()
}
