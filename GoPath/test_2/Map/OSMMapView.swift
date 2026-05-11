import SwiftUI
import MapKit
import UIKit

final class OverZoomOSMTileOverlay: MKTileOverlay
{
    private let baseMaxZ = 18
    private let tileCache: Tilecache

    init(urlTemplate: String?, tileCache: Tilecache)
    {
        self.tileCache = tileCache
        super.init(urlTemplate: urlTemplate)
    }

    private func loadBaseTile(
        at path: MKTileOverlayPath,
        result: @escaping (Data?, Error?) -> Void
    )
    {
        if let cached = tileCache.cacheData(
            z: path.z,
            x: path.x,
            y: path.y,
            scale: path.contentScaleFactor
        ) {
            result(cached, nil)
            return
        }

        super.loadTile(at: path) { [weak self] data, error in
            guard let self else {
                result(data, error)
                return
            }

            guard let data, error == nil else {
                result(nil, error)
                return
            }

            self.tileCache.saveTile(
                data: data,
                z: path.z,
                x: path.x,
                y: path.y,
                scale: path.contentScaleFactor
            )

            result(data, nil)
        }
    }

    override func loadTile(
        at path: MKTileOverlayPath,
        result: @escaping (Data?, Error?) -> Void
    )
    {
        if path.z <= baseMaxZ {
            loadBaseTile(at: path, result: result)
            return
        }

        let dz = path.z - baseMaxZ
        let parentZ = baseMaxZ
        let parentX = path.x >> dz
        let parentY = path.y >> dz

        let parentPath = MKTileOverlayPath(
            x: parentX,
            y: parentY,
            z: parentZ,
            contentScaleFactor: path.contentScaleFactor
        )

        loadBaseTile(at: parentPath) { data, error in
            guard let data,
                  let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                result(nil, error)
                return
            }

            let tilesPerSide = 1 << dz
            let childX = path.x & (tilesPerSide - 1)
            let childY = path.y & (tilesPerSide - 1)

            let parentWidth = cgImage.width
            let parentHeight = cgImage.height

            let cropWidth = parentWidth / tilesPerSide
            let cropHeight = parentHeight / tilesPerSide

            let cropRect = CGRect(
                x: childX * cropWidth,
                y: childY * cropHeight,
                width: cropWidth,
                height: cropHeight
            )

            guard let cropped = cgImage.cropping(to: cropRect) else {
                result(nil, nil)
                return
            }

            let imageRenderer = UIGraphicsImageRenderer(
                size: CGSize(width: parentWidth, height: parentHeight)
            )

            let scaledImage = imageRenderer.image { _ in
                UIImage(cgImage: cropped).draw(
                    in: CGRect(
                        x: 0,
                        y: 0,
                        width: parentWidth,
                        height: parentHeight
                    )
                )
            }

            result(scaledImage.pngData(), nil)
        }
    }
}

private final class RouteGlowOverlay: MKPolyline
{
}

private final class RouteCoreOverlay: MKPolyline
{
}

private final class PreferredLocationAnnotation: NSObject, MKAnnotation
{
    dynamic var coordinate: CLLocationCoordinate2D
    let title: String? = "Мое местоположение"

    init(coordinate: CLLocationCoordinate2D)
    {
        self.coordinate = coordinate
        super.init()
    }
}

private final class RouteEndpointAnnotation: NSObject, MKAnnotation
{
    enum Kind
    {
        case start
        case end
    }

    dynamic var coordinate: CLLocationCoordinate2D
    let kind: Kind
    let title: String?

    init(coordinate: CLLocationCoordinate2D, kind: Kind)
    {
        self.coordinate = coordinate
        self.kind = kind
        switch kind {
        case .start:
            self.title = "Start"
        case .end:
            self.title = "End"
        }
        super.init()
    }
}

private final class PulsingLocationAnnotationView: MKAnnotationView
{
    static let reuseIdentifier = "PulsingLocationAnnotationView"

    private let pulseLayer = CAShapeLayer()
    private let dotLayer = CAShapeLayer()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?)
    {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        configure()
    }

    override func prepareForReuse()
    {
        super.prepareForReuse()
        startPulseAnimation()
    }

    override func didMoveToWindow()
    {
        super.didMoveToWindow()

        if window == nil {
            pulseLayer.removeAnimation(forKey: "pulse")
        } else {
            startPulseAnimation()
        }
    }

    override func layoutSubviews()
    {
        super.layoutSubviews()

        pulseLayer.frame = bounds
        dotLayer.frame = bounds

        let pulseRect = pulseLayer.bounds.insetBy(dx: 3, dy: 3)
        pulseLayer.path = UIBezierPath(ovalIn: pulseRect).cgPath

        let dotSize: CGFloat = 12
        let dotRect = CGRect(
            x: (dotLayer.bounds.width - dotSize) / 2,
            y: (dotLayer.bounds.height - dotSize) / 2,
            width: dotSize,
            height: dotSize
        )
        dotLayer.path = UIBezierPath(ovalIn: dotRect).cgPath
    }

    private func configure()
    {
        frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        backgroundColor = .clear
        centerOffset = .zero
        displayPriority = .required
        canShowCallout = false

        let dotColor = UIColor(red: 0.95, green: 0.20, blue: 0.28, alpha: 1.0)





        pulseLayer.frame = bounds
        pulseLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        pulseLayer.fillColor = dotColor.withAlphaComponent(0.24).cgColor
        pulseLayer.strokeColor = dotColor.withAlphaComponent(0.64).cgColor
        pulseLayer.lineWidth = 1.2
        layer.addSublayer(pulseLayer)

        dotLayer.frame = bounds
        dotLayer.fillColor = dotColor.cgColor
        dotLayer.strokeColor = UIColor.white.withAlphaComponent(0.96).cgColor
        dotLayer.lineWidth = 1.5

        dotLayer.shadowColor = UIColor.black.cgColor
        dotLayer.shadowOpacity = 0.28
        dotLayer.shadowRadius = 4
        dotLayer.shadowOffset = CGSize(width: 0, height: 1)
        layer.addSublayer(dotLayer)

        startPulseAnimation()
    }

    private func startPulseAnimation()
    {
        pulseLayer.removeAnimation(forKey: "pulse")

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.55
        scale.toValue = 1.25

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.85
        opacity.toValue = 0.05

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 2.05
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false

        pulseLayer.add(group, forKey: "pulse")
    }
}

private final class RouteEndpointAnnotationView: MKAnnotationView
{
    static let reuseIdentifier = "RouteEndpointAnnotationView"

    private let glowLayer = CAShapeLayer()
    private let outerRingLayer = CAShapeLayer()
    private let innerFillLayer = CAShapeLayer()
    private let iconImageView = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?)
    {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        configure()
    }

    override func prepareForReuse()
    {
        super.prepareForReuse()
        updateAppearance()
    }

    override var annotation: MKAnnotation?
    {
        didSet {
            updateAppearance()
        }
    }

    override func layoutSubviews()
    {
        super.layoutSubviews()

        glowLayer.frame = bounds
        outerRingLayer.frame = bounds
        innerFillLayer.frame = bounds

        let glowRect = bounds.insetBy(dx: 3, dy: 3)
        glowLayer.path = UIBezierPath(ovalIn: glowRect).cgPath

        let outerRect = bounds.insetBy(dx: 7, dy: 7)
        outerRingLayer.path = UIBezierPath(ovalIn: outerRect).cgPath

        let innerRect = bounds.insetBy(dx: 11, dy: 11)
        innerFillLayer.path = UIBezierPath(ovalIn: innerRect).cgPath
    }

    private func configure()
    {
        frame = CGRect(x: 0, y: 0, width: 48, height: 48)
        backgroundColor = .clear
        centerOffset = CGPoint(x: 0, y: -2)
        displayPriority = .required
        canShowCallout = false

        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.lineWidth = 10
        layer.addSublayer(glowLayer)

        outerRingLayer.fillColor = UIColor.clear.cgColor
        outerRingLayer.lineWidth = 2
        layer.addSublayer(outerRingLayer)

        innerFillLayer.strokeColor = UIColor.clear.cgColor
        innerFillLayer.lineWidth = 0
        layer.addSublayer(innerFillLayer)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16)
        ])

        updateAppearance()
    }

    private func updateAppearance()
    {
        guard let endpoint = annotation as? RouteEndpointAnnotation else {
            return
        }

        let baseColor: UIColor
        let iconName: String

        switch endpoint.kind {
        case .start:
            baseColor = UIColor(red: 0.33, green: 0.66, blue: 1.0, alpha: 1.0)
            iconName = "figure.walk"
        case .end:
            baseColor = UIColor(red: 0.20, green: 0.56, blue: 0.98, alpha: 1.0)
            iconName = "mappin.and.ellipse"
        }

        glowLayer.strokeColor = UIColor.clear.cgColor
        outerRingLayer.strokeColor = UIColor.clear.cgColor
        innerFillLayer.strokeColor = baseColor.withAlphaComponent(0.95).cgColor
        innerFillLayer.lineWidth = 1.5
        innerFillLayer.fillColor = UIColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 0.96).cgColor

        iconImageView.image = UIImage(systemName: iconName)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        iconImageView.tintColor = UIColor(red: 0.82, green: 0.82, blue: 1.0, alpha: 1.0)
    }

}

struct OSMMapView: UIViewRepresentable
{
    let startPoint: CLLocationCoordinate2D?
    let endPoint: CLLocationCoordinate2D?
    let routePoints: [RoutePoint]
    let preferredCenterPoint: CLLocationCoordinate2D?
    let usePreferredLocationAsStartMarker: Bool
    let preferredCenterNonce: Int
    let recenterNonce: Int
    var onUserInteraction: (() -> Void)? = nil


    func makeCoordinator() -> Coordinator
    {
        return Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView
    {
        let mapView = MKMapView()

        mapView.delegate = context.coordinator
        mapView.isOpaque = false
        mapView.backgroundColor = UIColor(red: 0.05, green: 0.08, blue: 0.10, alpha: 1.0)
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        let urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"

        let tileOverlay = OverZoomOSMTileOverlay(
            urlTemplate: urlTemplate,
            tileCache: context.coordinator.tileCache
        )
        tileOverlay.canReplaceMapContent = false
        tileOverlay.minimumZ = 0
        tileOverlay.maximumZ = 21

        context.coordinator.prefetcher = TilePrefetcher(
            tileCache: context.coordinator.tileCache,
            urlTemplate: urlTemplate
        )

        mapView.addOverlay(tileOverlay, level: .aboveRoads)

        mapView.addOverlays(
            MapBorders.makeOverlays(),
            level: .aboveLabels
        )

        let initialRegion = MapBorders.makeInitialRegion()
        let maxZoomOutRegion = MapBorders.makeMaximumZoomOutRegion()

        let maxDistance = max(
            maxZoomOutRegion.span.latitudeDelta,
            maxZoomOutRegion.span.longitudeDelta
        ) * 111_000.0

        let zoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 150,
            maxCenterCoordinateDistance: maxDistance
        )
        mapView.setCameraZoomRange(zoomRange, animated: false)
        mapView.setCameraBoundary(
            MKMapView.CameraBoundary(coordinateRegion: MapBorders.makePanBoundaryRegion()),
            animated: false
        )

        context.coordinator.minimumZoomDistance = 150
        context.coordinator.maximumZoomDistance = maxDistance

        mapView.setRegion(initialRegion, animated: false)

        context.coordinator.mapView = mapView
        context.coordinator.onUserInteraction = onUserInteraction
        context.coordinator.installZoomButtons(on: mapView)
        context.coordinator.installMapTouchTracking(on: mapView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            context.coordinator.prefetcher?.prefetchVisibleAndNeighbors(for: mapView)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context)
    {
        context.coordinator.onUserInteraction = onUserInteraction
        context.coordinator.setPreferredLocationCoordinate(preferredCenterPoint)
        updateAnnotations(on: mapView)

        let routeSignature = makeRouteSignature(for: routePoints)

        let oldPolylines = mapView.overlays.compactMap { overlay in
            overlay as? MKPolyline
        }

        if routePoints.isEmpty {
            if oldPolylines.isEmpty == false {
                mapView.removeOverlays(oldPolylines)
            }
            context.coordinator.lastRouteSignature = routeSignature
        } else if context.coordinator.lastRouteSignature != routeSignature {
            context.coordinator.lastRouteSignature = routeSignature

            mapView.removeOverlays(oldPolylines)
            let coordinates = routePoints.map { point in
                CLLocationCoordinate2D(
                    latitude: point.lat,
                    longitude: point.lon
                )
            }

            let corePolyline = RouteCoreOverlay(
                coordinates: coordinates,
                count: coordinates.count
            )

            mapView.addOverlay(corePolyline, level: .aboveLabels)


            let routeRect = corePolyline.boundingMapRect
            let visibleRect = mapView.visibleMapRect

            if visibleRect.contains(routeRect) == false {
                mapView.setVisibleMapRect(
                    routeRect,
                    edgePadding: UIEdgeInsets(
                        top: 80,
                        left: 40,
                        bottom: 140,
                        right: 40
                    ),
                    animated: true
                )
            }
        }

        if routePoints.isEmpty, let startPoint, let endPoint {
            centerMapBetweenPoints(
                mapView: mapView,
                start: startPoint,
                end: endPoint
            )
        }

        if let preferredCenterPoint,
           context.coordinator.lastPreferredCenterNonce != preferredCenterNonce {
            context.coordinator.lastPreferredCenterNonce = preferredCenterNonce
            centerMap(
                on: mapView,
                coordinate: preferredCenterPoint,
                coordinator: context.coordinator
            )
        }

        if context.coordinator.lastRecenterNonce != recenterNonce {
            context.coordinator.lastRecenterNonce = recenterNonce

            if routePoints.isEmpty == false {
                centerMapOnRoute(
                    mapView: mapView,
                    points: routePoints
                )
            } else if let startPoint, let endPoint {
                centerMapBetweenPoints(
                    mapView: mapView,
                    start: startPoint,
                    end: endPoint
                )
            } else if let preferredCenterPoint {
                centerMap(
                    on: mapView,
                    coordinate: preferredCenterPoint,
                    coordinator: context.coordinator
                )
            } else {
                mapView.setRegion(MapBorders.makeInitialRegion(), animated: true)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            context.coordinator.prefetcher?.prefetchVisibleAndNeighbors(for: mapView)
        }
    }

    private func makeRouteSignature(for points: [RoutePoint]) -> Int
    {
        var hasher = Hasher()
        hasher.combine(points.count)

        for point in points {
            hasher.combine(point.lat)
            hasher.combine(point.lon)
        }

        return hasher.finalize()
    }

    private func updateAnnotations(on mapView: MKMapView)
    {
        let oldAnnotations = mapView.annotations
        mapView.removeAnnotations(oldAnnotations)

        if let startPoint,
           !(usePreferredLocationAsStartMarker && preferredCenterPoint != nil) {
            let startAnnotation = RouteEndpointAnnotation(
                coordinate: startPoint,
                kind: .start
            )
            mapView.addAnnotation(startAnnotation)
        }


        if let endPoint {
            let endAnnotation = RouteEndpointAnnotation(
                coordinate: endPoint,
                kind: .end
            )
            mapView.addAnnotation(endAnnotation)
        }

        if let preferredCenterPoint {
            let preferredAnnotation = PreferredLocationAnnotation(
                coordinate: preferredCenterPoint
            )
            mapView.addAnnotation(preferredAnnotation)
        }
    }

    private func centerMapBetweenPoints(
        mapView: MKMapView,
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    )
    {
        let center = CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2.0,
            longitude: (start.longitude + end.longitude) / 2.0
        )

        let latDelta = abs(start.latitude - end.latitude) * 1.8
        let lonDelta = abs(start.longitude - end.longitude) * 1.8

        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.02),
            longitudeDelta: max(lonDelta, 0.02)
        )

        let region = MKCoordinateRegion(
            center: center,
            span: span
        )

        mapView.setRegion(region, animated: true)
    }

    private func centerMapOnRoute(
        mapView: MKMapView,
        points: [RoutePoint]
    )
    {
        let coordinates = points.map { point in
            CLLocationCoordinate2D(
                latitude: point.lat,
                longitude: point.lon
            )
        }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(
                top: 120,
                left: 60,
                bottom: 190,
                right: 90
            ),
            animated: true
        )
    }

    private func centerMap(
        on mapView: MKMapView,
        coordinate: CLLocationCoordinate2D,
        coordinator: Coordinator
    )
    {
        coordinator.animateCenterMap(
            on: mapView,
            coordinate: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: 0.003,
                longitudeDelta: 0.003
            )
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate
    {
        var lastRouteSignature: Int = 0
        var lastPreferredCenterNonce: Int = -1
        var lastRecenterNonce: Int = -1
        let tileCache = Tilecache()
        var prefetcher: TilePrefetcher?

        weak var mapView: MKMapView?
        weak var zoomButtons: ZoomButtons?
        weak var mapTouchGesture: UILongPressGestureRecognizer?
        var preferredLocationCoordinate: CLLocationCoordinate2D?
        var onUserInteraction: (() -> Void)?
        private var isLocatingPreferredPoint = false
        
        private var isZoomingFromPreferredPoint = false
        
        private var zoomAnimator: CADisplayLink?
        private var zoomStartCamera: MKMapCamera?
        private var zoomTargetCamera: MKMapCamera?
        private var zoomAnimationStartTime: CFTimeInterval = 0
        private let zoomAnimationDuration: CFTimeInterval = 0.17
        private var centerAnimator: CADisplayLink?
        private var centerStartCamera: MKMapCamera?
        private var centerTargetCamera: MKMapCamera?
        private var centerAnimationStartTime: CFTimeInterval = 0
        private let centerAnimationDuration: CFTimeInterval = 0.42
        var minimumZoomDistance: CLLocationDistance = 150
        var maximumZoomDistance: CLLocationDistance = 1_000_000

        func setPreferredLocationCoordinate(_ coordinate: CLLocationCoordinate2D?)
        {
            let didChange = preferredLocationCoordinate?.latitude != coordinate?.latitude ||
                preferredLocationCoordinate?.longitude != coordinate?.longitude

            preferredLocationCoordinate = coordinate
            zoomButtons?.setLocateButtonEnabled(coordinate != nil)

            if didChange {
                zoomButtons?.setLocateButtonActive(false)
            } else if let mapView {
                updateLocateButtonActiveState(for: mapView)
            }
        }

        func animateCenterMap(
            on mapView: MKMapView,
            coordinate: CLLocationCoordinate2D,
            span: MKCoordinateSpan
        )
        {
            centerAnimator?.invalidate()
            centerAnimator = nil
            zoomAnimator?.invalidate()
            zoomAnimator = nil

            guard let startCamera = mapView.camera.copy() as? MKMapCamera else {
                let region = MKCoordinateRegion(center: coordinate, span: span)
                mapView.setRegion(region, animated: true)
                return
            }

            let targetDistance = preferredCameraDistance(for: span)
            let targetCamera = MKMapCamera(
                lookingAtCenter: coordinate,
                fromDistance: targetDistance,
                pitch: 0,
                heading: 0
            )

            centerStartCamera = startCamera
            centerTargetCamera = targetCamera
            centerAnimationStartTime = CACurrentMediaTime()

            let displayLink = CADisplayLink(target: self, selector: #selector(handleCenterAnimationFrame))
            displayLink.add(to: .main, forMode: .common)
            centerAnimator = displayLink
        }

        func mapView(
            _ mapView: MKMapView,
            rendererFor overlay: MKOverlay
        ) -> MKOverlayRenderer
        {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }

            if overlay is ShadingOverlay {
                let renderer = MKPolygonRenderer(overlay: overlay)
                renderer.strokeColor = .clear
                renderer.fillColor = UIColor(
                    red: 0.03,
                    green: 0.08,
                    blue: 0.09,
                    alpha: 0.36
                )
                return renderer
            }

            if overlay is ActiveZoneOverlay {
                let renderer = MKPolygonRenderer(overlay: overlay)
                renderer.strokeColor = .clear
                renderer.fillColor = UIColor(
                    red: 0.58,
                    green: 0.96,
                    blue: 0.88,
                    alpha: 0.055
                )
                return renderer
            }

            if overlay is BorderGlowOverlay {
                let renderer = MKPolygonRenderer(overlay: overlay)
                renderer.strokeColor = UIColor(red: 0.62, green: 0.96, blue: 0.88, alpha: 0.36)
                renderer.fillColor = .clear
                renderer.lineWidth = 11
                return renderer
            }

            if overlay is BorderOverlay {
                let renderer = MKPolygonRenderer(overlay: overlay)
                renderer.strokeColor = UIColor(red: 0.76, green: 0.99, blue: 0.92, alpha: 0.92)
                renderer.fillColor = UIColor(red: 0.85, green: 1.0, blue: 0.96, alpha: 0.018)
                renderer.lineWidth = 2.6
                return renderer
            }

            if let polyline = overlay as? RouteCoreOverlay {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.6, green: 0.50, blue: 1, alpha: 0.95)
                renderer.lineWidth = 10
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView?
        {
            if annotation is PreferredLocationAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: PulsingLocationAnnotationView.reuseIdentifier
                ) as? PulsingLocationAnnotationView

                if let view {
                    view.annotation = annotation
                    return view
                }

                return PulsingLocationAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: PulsingLocationAnnotationView.reuseIdentifier
                )
            }

            if annotation is RouteEndpointAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: RouteEndpointAnnotationView.reuseIdentifier
                ) as? RouteEndpointAnnotationView

                if let view {
                    view.annotation = annotation
                    return view
                }

                return RouteEndpointAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: RouteEndpointAnnotationView.reuseIdentifier
                )
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool)
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.prefetcher?.prefetchVisibleAndNeighbors(for: mapView)
            }

            if isLocatingPreferredPoint == false && isZoomingFromPreferredPoint == false {
                updateLocateButtonActiveState(for: mapView)
            }
        }



        func installMapTouchTracking(on mapView: MKMapView)
        {
            if mapTouchGesture != nil {
                return
            }

            let gesture = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleMapTouchGesture(_:))
            )
            gesture.minimumPressDuration = 0
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            mapView.addGestureRecognizer(gesture)
            mapTouchGesture = gesture
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool
        {
            guard gestureRecognizer === mapTouchGesture else {
                return true
            }

            guard let zoomButtons else {
                return true
            }

            var touchedView = touch.view
            while let currentView = touchedView {
                if currentView === zoomButtons {
                    return false
                }
                touchedView = currentView.superview
            }

            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool
        {
            gestureRecognizer === mapTouchGesture
        }

        func installZoomButtons(on mapView: MKMapView)
        {
            if zoomButtons != nil {
                return
            }

            let controls = ZoomButtons()

            controls.onZoomIn = { [weak self] in
                self?.zoomIn()
            }

            controls.onZoomOut = { [weak self] in
                self?.zoomOut()
            }

            controls.onLocatePreferredPoint = { [weak self] in
                self?.focusPreferredLocation()
            }

            mapView.addSubview(controls)

            NSLayoutConstraint.activate([
                controls.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -10),
                controls.bottomAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.bottomAnchor, constant: -168)
            ])

            zoomButtons = controls
        }

        @objc private func handleMapTouchGesture(_ gesture: UILongPressGestureRecognizer)
        {
            guard gesture.state == .began else {
                return
            }

            onUserInteraction?()
            isLocatingPreferredPoint = false
            isZoomingFromPreferredPoint = false
            zoomButtons?.setLocateButtonActive(false)
        }


        private func zoomIn()
        {
            changeZoom(scale: 0.62)
        }

        private func zoomOut()
        {
            changeZoom(scale: 1.65)
        }

        private func focusPreferredLocation()
        {
            guard let mapView,
                  let preferredLocationCoordinate else {
                zoomButtons?.setLocateButtonActive(false)
                return
            }

            isLocatingPreferredPoint = true
            zoomButtons?.setLocateButtonActive(true)

            animateCenterMap(
                on: mapView,
                coordinate: preferredLocationCoordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: 0.003,
                    longitudeDelta: 0.003
                )
            )
        }
        
        private func isCenteredOnPreferredPoint(in mapView: MKMapView) -> Bool
        {
            guard let preferredLocationCoordinate else {
                return false
            }

            let centerPoint = MKMapPoint(mapView.centerCoordinate)
            let targetPoint = MKMapPoint(preferredLocationCoordinate)
            let horizontalTolerance = max(mapView.visibleMapRect.width * 0.025, 24)
            let verticalTolerance = max(mapView.visibleMapRect.height * 0.025, 24)

            return
                abs(centerPoint.x - targetPoint.x) <= horizontalTolerance &&
                abs(centerPoint.y - targetPoint.y) <= verticalTolerance
        }





        private func updateLocateButtonActiveState(for mapView: MKMapView)
        {
            guard let preferredLocationCoordinate else {
                zoomButtons?.setLocateButtonActive(false)
                return
            }

            let centerPoint = MKMapPoint(mapView.centerCoordinate)
            let targetPoint = MKMapPoint(preferredLocationCoordinate)
            let horizontalTolerance = max(mapView.visibleMapRect.width * 0.025, 24)
            let verticalTolerance = max(mapView.visibleMapRect.height * 0.025, 24)
            let isCenteredOnPreferredPoint =
                abs(centerPoint.x - targetPoint.x) <= horizontalTolerance &&
                abs(centerPoint.y - targetPoint.y) <= verticalTolerance

            zoomButtons?.setLocateButtonActive(isCenteredOnPreferredPoint)

            if isCenteredOnPreferredPoint {
                isLocatingPreferredPoint = false
            }
        }

        private func changeZoom(scale: Double)
        {
            guard let mapView else {
                return
            }

            isZoomingFromPreferredPoint = isCenteredOnPreferredPoint(in: mapView)

            if isZoomingFromPreferredPoint == false {
                isLocatingPreferredPoint = false
                zoomButtons?.setLocateButtonActive(false)
            }

            centerAnimator?.invalidate()
            centerAnimator = nil
            zoomAnimator?.invalidate()
            zoomAnimator = nil


            guard let startCamera = mapView.camera.copy() as? MKMapCamera else {
                return
            }

            let minDistance = minimumZoomDistance
            let maxDistance = maximumZoomDistance

            var targetDistance = startCamera.centerCoordinateDistance * scale
            targetDistance = min(max(targetDistance, minDistance), maxDistance)

            if scale > 1.0 && targetDistance > maxDistance * 0.88 {
                targetDistance = maxDistance
            } else if scale < 1.0 && targetDistance < minDistance * 1.12 {
                targetDistance = minDistance
            }

            guard abs(targetDistance - startCamera.centerCoordinateDistance) > 1 else {
                return
            }

            guard let targetCamera = startCamera.copy() as? MKMapCamera else {
                return
            }
            targetCamera.centerCoordinateDistance = targetDistance

            zoomStartCamera = startCamera
            zoomTargetCamera = targetCamera
            zoomAnimationStartTime = CACurrentMediaTime()

            let displayLink = CADisplayLink(target: self, selector: #selector(handleZoomAnimationFrame))
            displayLink.add(to: .main, forMode: .common)
            zoomAnimator = displayLink
        }

        private func preferredCameraDistance(for span: MKCoordinateSpan) -> CLLocationDistance
        {
            let spanMeters = max(span.latitudeDelta, span.longitudeDelta) * 111_000.0
            let targetDistance = spanMeters * 1.7
            return min(max(targetDistance, minimumZoomDistance), maximumZoomDistance)
        }

        private func easeInOutCubic(_ progress: Double) -> Double
        {
            if progress < 0.5 {
                return 4 * progress * progress * progress
            }

            return 1 - pow(-2 * progress + 2, 3) / 2
        }

        @objc private func handleCenterAnimationFrame()
        {
            guard let mapView,
                  let startCamera = centerStartCamera,
                  let targetCamera = centerTargetCamera else {
                centerAnimator?.invalidate()
                centerAnimator = nil
                return
            }

            let elapsed = CACurrentMediaTime() - centerAnimationStartTime
            let progress = min(max(elapsed / centerAnimationDuration, 0), 1)
            let eased = easeInOutCubic(progress)

            let latitude = startCamera.centerCoordinate.latitude
                + (targetCamera.centerCoordinate.latitude - startCamera.centerCoordinate.latitude) * eased

            let longitude = startCamera.centerCoordinate.longitude
                + (targetCamera.centerCoordinate.longitude - startCamera.centerCoordinate.longitude) * eased

            let distance = startCamera.centerCoordinateDistance
                + (targetCamera.centerCoordinateDistance - startCamera.centerCoordinateDistance) * eased

            guard let interpolatedCamera = startCamera.copy() as? MKMapCamera else {
                centerAnimator?.invalidate()
                centerAnimator = nil
                return
            }

            interpolatedCamera.centerCoordinate = CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )
            interpolatedCamera.centerCoordinateDistance = distance

            mapView.setCamera(interpolatedCamera, animated: false)

            if progress >= 1 {
                centerAnimator?.invalidate()
                centerAnimator = nil
                centerStartCamera = nil
                centerTargetCamera = nil

                if isLocatingPreferredPoint {
                    isLocatingPreferredPoint = false
                }

                updateLocateButtonActiveState(for: mapView)
            }
        }

        @objc private func handleZoomAnimationFrame()
        {
            guard let mapView,
                  let startCamera = zoomStartCamera,
                  let targetCamera = zoomTargetCamera else {
                zoomAnimator?.invalidate()
                zoomAnimator = nil
                return
            }

            let elapsed = CACurrentMediaTime() - zoomAnimationStartTime
            let progress = min(max(elapsed / zoomAnimationDuration, 0), 1)

            let eased = 1 - pow(1 - progress, 3)

            let latitude = startCamera.centerCoordinate.latitude
                + (targetCamera.centerCoordinate.latitude - startCamera.centerCoordinate.latitude) * eased

            let longitude = startCamera.centerCoordinate.longitude
                + (targetCamera.centerCoordinate.longitude - startCamera.centerCoordinate.longitude) * eased

            let distance = startCamera.centerCoordinateDistance
                + (targetCamera.centerCoordinateDistance - startCamera.centerCoordinateDistance) * eased

            guard let interpolatedCamera = startCamera.copy() as? MKMapCamera else {
                zoomAnimator?.invalidate()
                zoomAnimator = nil
                return
            }

            interpolatedCamera.centerCoordinate = CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )
            interpolatedCamera.centerCoordinateDistance = distance

            mapView.setCamera(interpolatedCamera, animated: false)

            if progress >= 1 {
                zoomAnimator?.invalidate()
                zoomAnimator = nil
                zoomStartCamera = nil
                zoomTargetCamera = nil
                isZoomingFromPreferredPoint = false
            }

        }
    }
}




#Preview {
    NavigatorOnMap()
}


