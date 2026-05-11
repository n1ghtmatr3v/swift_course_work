import SwiftUI
import MapKit

final class BorderOverlay: MKPolygon
{
}

final class BorderGlowOverlay: MKPolygon
{
}

final class ActiveZoneOverlay: MKPolygon
{
}

final class ShadingOverlay: MKPolygon
{
}

enum MapBorders
{
    static let minLatitude: CLLocationDegrees = 55.5660000
    static let minLongitude: CLLocationDegrees = 37.3220000
    static let maxLatitude: CLLocationDegrees = 55.9160000
    static let maxLongitude: CLLocationDegrees = 37.8810000

    // Серая зона 300 км от чёрной линии
    private static let grayPaddingMeters: CLLocationDistance = 150_000.0
    // Барьер листания 50 км от чёрной линии
    private static let panPaddingMeters: CLLocationDistance = 50_000.0



    static let defaultCenterLatitude: CLLocationDegrees = 55.751244
    static let defaultCenterLongitude: CLLocationDegrees = 37.618423

    static let defaultLatitudeDelta: CLLocationDegrees = 0.42
    static let defaultLongitudeDelta: CLLocationDegrees = 0.42

    private static let zoomOutPaddingMeters: CLLocationDistance = 70_000.0

    private static let maxZoomOutMultiplier: CLLocationDegrees = 0.999


    static var centerLatitude: CLLocationDegrees
    {
        return (minLatitude + maxLatitude) / 2.0
    }

    static var centerLongitude: CLLocationDegrees
    {
        return (minLongitude + maxLongitude) / 2.0
    }

    private static func metersToLatitudeDegrees(_ meters: CLLocationDistance) -> CLLocationDegrees
    {
        return meters / 111_000.0
    }

    private static func metersToLongitudeDegrees(_ meters: CLLocationDistance) -> CLLocationDegrees
    {
        let latitudeRadians = centerLatitude * .pi / 180.0
        let metersPerDegreeLongitude = 111_000.0 * cos(latitudeRadians)
        return meters / metersPerDegreeLongitude
    }

    static var grayLatitudePaddingDegrees: CLLocationDegrees
    {
        return metersToLatitudeDegrees(grayPaddingMeters)
    }

    static var grayLongitudePaddingDegrees: CLLocationDegrees
    {
        return metersToLongitudeDegrees(grayPaddingMeters)
    }

    static var panLatitudePaddingDegrees: CLLocationDegrees
    {
        return metersToLatitudeDegrees(panPaddingMeters)
    }

    static var panLongitudePaddingDegrees: CLLocationDegrees
    {
        return metersToLongitudeDegrees(panPaddingMeters)
    }
    
    static var zoomOutLatitudePaddingDegrees: CLLocationDegrees
    {
        return metersToLatitudeDegrees(zoomOutPaddingMeters)
    }

    static var zoomOutLongitudePaddingDegrees: CLLocationDegrees
    {
        return metersToLongitudeDegrees(zoomOutPaddingMeters)
    }


    // Серая зона
    static var outerMinLatitude: CLLocationDegrees
    {
        return minLatitude - grayLatitudePaddingDegrees
    }

    static var outerMaxLatitude: CLLocationDegrees
    {
        return maxLatitude + grayLatitudePaddingDegrees
    }

    static var outerMinLongitude: CLLocationDegrees
    {
        return minLongitude - grayLongitudePaddingDegrees
    }

    static var outerMaxLongitude: CLLocationDegrees
    {
        return maxLongitude + grayLongitudePaddingDegrees
    }

    // Барьер листания 50 км от чёрной линии
    static var rawPanMinLatitude: CLLocationDegrees
    {
        return minLatitude - panLatitudePaddingDegrees
    }

    static var rawPanMaxLatitude: CLLocationDegrees
    {
        return maxLatitude + panLatitudePaddingDegrees
    }

    static var rawPanMinLongitude: CLLocationDegrees
    {
        return minLongitude - panLongitudePaddingDegrees
    }

    static var rawPanMaxLongitude: CLLocationDegrees
    {
        return maxLongitude + panLongitudePaddingDegrees
    }

    // Размер барьера листания
    static var panLatitudeSpan: CLLocationDegrees
    {
        return rawPanMaxLatitude - rawPanMinLatitude
    }

    static var panLongitudeSpan: CLLocationDegrees
    {
        return rawPanMaxLongitude - rawPanMinLongitude
    }

    static var maximumVisibleLatitudeDelta: CLLocationDegrees
    {
        return (
            (maxLatitude - minLatitude) +
            (zoomOutLatitudePaddingDegrees * 2.0)
        ) * maxZoomOutMultiplier
    }


    static var maximumVisibleLongitudeDelta: CLLocationDegrees
    {
        return (
            (maxLongitude - minLongitude) +
            (zoomOutLongitudePaddingDegrees * 2.0)
        ) * maxZoomOutMultiplier
    }


    // Максимум листания одинаково на всех уровнях зума
    static var panBoundaryMinLatitude: CLLocationDegrees
    {
        return rawPanMinLatitude
    }

    static var panBoundaryMaxLatitude: CLLocationDegrees
    {
        return rawPanMaxLatitude
    }

    static var panBoundaryMinLongitude: CLLocationDegrees
    {
        return rawPanMinLongitude
    }

    static var panBoundaryMaxLongitude: CLLocationDegrees
    {
        return rawPanMaxLongitude
    }

    static func makeInitialRegion() -> MKCoordinateRegion
    {
        let center = CLLocationCoordinate2D(
            latitude: defaultCenterLatitude,
            longitude: defaultCenterLongitude
        )

        let span = MKCoordinateSpan(
            latitudeDelta: defaultLatitudeDelta,
            longitudeDelta: defaultLongitudeDelta
        )

        return MKCoordinateRegion(
            center: center,
            span: span
        )
    }

    static func makeMaximumZoomOutRegion() -> MKCoordinateRegion
    {
        let center = CLLocationCoordinate2D(
            latitude: centerLatitude,
            longitude: centerLongitude
        )

        let span = MKCoordinateSpan(
            latitudeDelta: maximumVisibleLatitudeDelta,
            longitudeDelta: maximumVisibleLongitudeDelta
        )

        return MKCoordinateRegion(
            center: center,
            span: span
        )
    }

    static func makePanBoundaryRegion() -> MKCoordinateRegion
    {
        let center = CLLocationCoordinate2D(
            latitude: (panBoundaryMinLatitude + panBoundaryMaxLatitude) / 2.0,
            longitude: (panBoundaryMinLongitude + panBoundaryMaxLongitude) / 2.0
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max(0.0001, panBoundaryMaxLatitude - panBoundaryMinLatitude),
            longitudeDelta: max(0.0001, panBoundaryMaxLongitude - panBoundaryMinLongitude)
        )

        return MKCoordinateRegion(
            center: center,
            span: span
        )
    }

    static func makeOverlays() -> [MKOverlay]
    {
        let topShade = makeShadingRectangle(
            topLatitude: outerMaxLatitude,
            bottomLatitude: maxLatitude,
            leftLongitude: outerMinLongitude,
            rightLongitude: outerMaxLongitude
        )

        let bottomShade = makeShadingRectangle(
            topLatitude: minLatitude,
            bottomLatitude: outerMinLatitude,
            leftLongitude: outerMinLongitude,
            rightLongitude: outerMaxLongitude
        )

        let leftShade = makeShadingRectangle(
            topLatitude: maxLatitude,
            bottomLatitude: minLatitude,
            leftLongitude: outerMinLongitude,
            rightLongitude: minLongitude
        )

        let rightShade = makeShadingRectangle(
            topLatitude: maxLatitude,
            bottomLatitude: minLatitude,
            leftLongitude: maxLongitude,
            rightLongitude: outerMaxLongitude
        )

        let activeZone = makeActiveZoneOverlay()
        let borderGlow = makeBorderGlowOverlay()
        let border = makeBorderOverlay()

        return [
            topShade,
            bottomShade,
            leftShade,
            rightShade,
            activeZone,
            borderGlow,
            border
        ]
    }

    private static func makeBorderGlowOverlay() -> BorderGlowOverlay
    {
        var coordinates = makeRectangleCoordinates(
            topLatitude: maxLatitude,
            bottomLatitude: minLatitude,
            leftLongitude: minLongitude,
            rightLongitude: maxLongitude
        )

        return BorderGlowOverlay(
            coordinates: &coordinates,
            count: coordinates.count
        )
    }

    private static func makeBorderOverlay() -> BorderOverlay
    {
        var coordinates = makeRectangleCoordinates(
            topLatitude: maxLatitude,
            bottomLatitude: minLatitude,
            leftLongitude: minLongitude,
            rightLongitude: maxLongitude
        )

        return BorderOverlay(
            coordinates: &coordinates,
            count: coordinates.count
        )
    }

    private static func makeActiveZoneOverlay() -> ActiveZoneOverlay
    {
        var coordinates = makeRectangleCoordinates(
            topLatitude: maxLatitude,
            bottomLatitude: minLatitude,
            leftLongitude: minLongitude,
            rightLongitude: maxLongitude
        )

        return ActiveZoneOverlay(
            coordinates: &coordinates,
            count: coordinates.count
        )
    }

    private static func makeShadingRectangle(
        topLatitude: CLLocationDegrees,
        bottomLatitude: CLLocationDegrees,
        leftLongitude: CLLocationDegrees,
        rightLongitude: CLLocationDegrees
    ) -> ShadingOverlay
    {
        var coordinates = makeRectangleCoordinates(
            topLatitude: topLatitude,
            bottomLatitude: bottomLatitude,
            leftLongitude: leftLongitude,
            rightLongitude: rightLongitude
        )

        return ShadingOverlay(
            coordinates: &coordinates,
            count: coordinates.count
        )
    }

    private static func makeRectangleCoordinates(
        topLatitude: CLLocationDegrees,
        bottomLatitude: CLLocationDegrees,
        leftLongitude: CLLocationDegrees,
        rightLongitude: CLLocationDegrees
    ) -> [CLLocationCoordinate2D]
    {
        let leftTop = CLLocationCoordinate2D(
            latitude: topLatitude,
            longitude: leftLongitude
        )

        let rightTop = CLLocationCoordinate2D(
            latitude: topLatitude,
            longitude: rightLongitude
        )

        let rightBottom = CLLocationCoordinate2D(
            latitude: bottomLatitude,
            longitude: rightLongitude
        )

        let leftBottom = CLLocationCoordinate2D(
            latitude: bottomLatitude,
            longitude: leftLongitude
        )

        return [
            leftTop,
            rightTop,
            rightBottom,
            leftBottom
        ]
    }
}

private struct FullScreenPreviewWrapper: View
{
    var body: some View
    {
        NavigatorOnMap()
    }
}

#Preview("Full iPhone Screen") {
    FullScreenPreviewWrapper()
}
