import MapKit

struct MapConstant {
    static let moscowCenter = CLLocationCoordinate2D(
        latitude: 55.751244,
        longitude: 37.618423
    )
    static let startSpan = MKCoordinateSpan(
        latitudeDelta: 0.4,
        longitudeDelta: 0.4
    )
    
    static let testStartPoint = CLLocationCoordinate2D(
        latitude: 55.8905505,  // 05505
        longitude: 37.4838629
    )
    static let testEndPoint = CLLocationCoordinate2D(
        latitude: 55.7577416,
        longitude: 37.5378913
    )
}
