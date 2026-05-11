import SwiftUI
import MapKit

struct MapScreenView: View {
    @State private var routePoints: [RoutePoint] = []
    @State private var errorText: String?
    
    @StateObject private var hideMenu = HideMenu()
    
    private let routeService = BackendInitalizer()

    var body: some View {
        ZStack(alignment: .bottom) {
            OSMMapView(
                startPoint: MapConstant.testStartPoint,
                endPoint: MapConstant.testEndPoint,
                routePoints: routePoints,
                preferredCenterPoint: nil,
                usePreferredLocationAsStartMarker: false,
                preferredCenterNonce: 0,
                recenterNonce: 0
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                if let errorText {
                    Text(errorText)
                        .padding()
                        .background(.white)
                        .cornerRadius(12)
                }

                Button("Build Route") {
                    Task {
                        await loadRoute()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
        }
    }

    private func loadRoute() async {
        do {
            let response = try await routeService.buildRoute(
                startLat: MapConstant.testStartPoint.latitude,
                startLon: MapConstant.testStartPoint.longitude,
                endLat: MapConstant.testEndPoint.latitude,
                endLon: MapConstant.testEndPoint.longitude
            )

            routePoints = response.route
            errorText = nil
            print("route points count =", routePoints.count)
        } catch {
            errorText = error.localizedDescription
            print("route load error =", error.localizedDescription)
        }
    }
}
