//
//  ContentView.swift
//  course_work
//
//  Created by Капульцевич Георгий Константинович on 13.01.2026.
//

import SwiftUI
import MapKit

struct ContentView: View {
    
    
    let center = CLLocationCoordinate2D(
        latitude: 55.7558,
        longitude: 37.6173
    )
    
    let span = MKCoordinateSpan(
        latitudeDelta: 0.1,
        longitudeDelta: 0.1
    )
    
    
    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: center, span: span)))
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
