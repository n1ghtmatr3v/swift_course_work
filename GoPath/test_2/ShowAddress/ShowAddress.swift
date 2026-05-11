import SwiftUI
import Combine
import MapKit
import UIKit

enum ShowAddressTarget
{
    case start
    case end
}

@MainActor
final class ShowAddress: ObservableObject
{
    @Published var isPickerVisible = false
    @Published var target: ShowAddressTarget?
    @Published var selectedCoordinate = MapConstant.moscowCenter
    @Published var locatorCoordinate: CLLocationCoordinate2D?
    @Published var isResolvingAddress = false
    @Published var errorText: String?
    @Published var resolvedAddress: AddressResolveResponse?
    @Published var resolvedCoordinateNonce = 0
    private var resolveRequestSerial = 0

    func open(
        target: ShowAddressTarget,
        initialCoordinate: CLLocationCoordinate2D?,
        locatorCoordinate: CLLocationCoordinate2D?
    )
    {
        self.target = target
        self.selectedCoordinate = initialCoordinate ?? MapConstant.moscowCenter
        self.locatorCoordinate = locatorCoordinate

        self.errorText = nil
        self.isResolvingAddress = false
        self.resolvedAddress = nil
        self.resolvedCoordinateNonce = 0

        withAnimation(.easeInOut(duration: 0.24)) {
            self.isPickerVisible = true
        }
    }

    func close()
    {
        withAnimation(.easeInOut(duration: 0.24)) {
            isPickerVisible = false
        }

        isResolvingAddress = false
        errorText = nil
        resolvedAddress = nil
        resolvedCoordinateNonce = 0
        resolveRequestSerial += 1
    }

    func updateCoordinate(_ coordinate: CLLocationCoordinate2D)
    {
        selectedCoordinate = coordinate
    }

    func resolveSelectedAddress(
        using service: BackendInitalizer
    ) async throws -> AddressResolveResponse
    {
        let coordinate = selectedCoordinate
        resolveRequestSerial += 1
        let requestSerial = resolveRequestSerial

        isResolvingAddress = true
        errorText = nil
        resolvedAddress = nil
        defer {
            if resolveRequestSerial == requestSerial {
                isResolvingAddress = false
            }
        }

        do {
            guard isInsideAllowedZone(coordinate) else {
                throw BackendError.message("Точку можно выбрать только внутри зоны")
            }

            let nearest = try await service.findNearestPoint(
                lat: coordinate.latitude,
                lon: coordinate.longitude
            )

            guard resolveRequestSerial == requestSerial,
                  isSameCoordinate(coordinate, selectedCoordinate) else {
                throw CancellationError()
            }

            let snappedCoordinate = CLLocationCoordinate2D(
                latitude: nearest.point.lat,
                longitude: nearest.point.lon
            )

            let response = try await resolveDisplayAddress(
                coordinate: coordinate,
                snappedCoordinate: snappedCoordinate,
                using: service
            )

            guard resolveRequestSerial == requestSerial,
                  isSameCoordinate(coordinate, selectedCoordinate) else {
                throw CancellationError()
            }

            let snappedResponse = AddressResolveResponse(
                fullName: response.fullName,
                lat: snappedCoordinate.latitude,
                lon: snappedCoordinate.longitude
            )

            service.rememberCoordinateAlias(snappedResponse)
            selectedCoordinate = snappedCoordinate
            resolvedAddress = snappedResponse
            resolvedCoordinateNonce += 1
            return snappedResponse
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if resolveRequestSerial == requestSerial,
               isSameCoordinate(coordinate, selectedCoordinate) {
                errorText = error.localizedDescription
            }

            throw error
        }
    }

    private func resolveDisplayAddress(
        coordinate: CLLocationCoordinate2D,
        snappedCoordinate: CLLocationCoordinate2D,
        using service: BackendInitalizer
    ) async throws -> AddressResolveResponse
    {
        do {
            return try await service.resolveAddressByCoordinate(
                lat: coordinate.latitude,
                lon: coordinate.longitude
            )
        } catch {
            return try await service.resolveAddressByCoordinate(
                lat: snappedCoordinate.latitude,
                lon: snappedCoordinate.longitude
            )
        }
    }

    private func isSameCoordinate(
        _ first: CLLocationCoordinate2D,
        _ second: CLLocationCoordinate2D
    ) -> Bool
    {
        abs(first.latitude - second.latitude) < 0.0000001 &&
            abs(first.longitude - second.longitude) < 0.0000001
    }

    private func isInsideAllowedZone(
        _ coordinate: CLLocationCoordinate2D
    ) -> Bool
    {
        coordinate.latitude >= MapBorders.minLatitude &&
        coordinate.latitude <= MapBorders.maxLatitude &&
        coordinate.longitude >= MapBorders.minLongitude &&
        coordinate.longitude <= MapBorders.maxLongitude
    }
}

struct ShowAddressPickerScreen: View
{
    @ObservedObject var showAddress: ShowAddress
    let routeService: BackendInitalizer
    let onAddressResolved: (ShowAddressTarget, AddressResolveResponse) -> Void
    let onClose: () -> Void

    @State private var zoomInNonce = 0
    @State private var zoomOutNonce = 0
    @State private var recenterNonce = 0

    var body: some View
    {
        ZStack {
            ShowAddressPickerMapView(
                selectedCoordinate: $showAddress.selectedCoordinate,
                locatorCoordinate: showAddress.locatorCoordinate,
                resolvedCoordinateNonce: showAddress.resolvedCoordinateNonce,
                zoomInNonce: zoomInNonce,
                zoomOutNonce: zoomOutNonce,
                recenterNonce: recenterNonce,
                onCoordinateCommitted: { coordinate in
                    showAddress.updateCoordinate(coordinate)
                    resolvePickedCoordinate()
                }
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(alignment: .bottom, spacing: 10) {
                    pickerBackButton
                    selectedAddressBadge

                    if showAddress.resolvedAddress != nil {
                        pickerSelectButton
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            resolvePickedCoordinate()
        }
        .animation(.easeInOut(duration: 0.20), value: showAddress.isResolvingAddress)
        .animation(.easeInOut(duration: 0.20), value: showAddress.errorText)
        .animation(.easeInOut(duration: 0.20), value: showAddress.resolvedAddress?.fullName)
    }

    private var pickerBackButton: some View
    {
        Button(action: {
            showAddress.close()
            onClose()
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.94))
                .frame(width: 54, height: 54)
                .background(
                    GlassCardBackground(isSelected: false, cornerRadius: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(MenuTheme.softGlowGradient, lineWidth: 1)
                                .opacity(0.16)
                        )
                )
        }
        .buttonStyle(
            GlassPressButtonStyle(
                cornerRadius: 18,
                scale: 0.94,
                shadowColor: Color.black.opacity(0.16),
                shadowRadius: 12,
                shadowY: 8
            )
        )
        .accessibilityLabel("Вернуться назад")
    }

    private var selectedAddressBadge: some View
    {
        HStack(spacing: 10) {
            if showAddress.isResolvingAddress {
                ProgressView()
                    .tint(MenuTheme.green)
                    .scaleEffect(0.82)

                Text("Определяю адрес…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
            } else if let errorText = showAddress.errorText {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.45))

                Text(errorText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if let resolvedAddress = showAddress.resolvedAddress {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MenuTheme.green)

                Text(resolvedAddress.fullName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                    .lineLimit(2)
                    .truncationMode(.tail)
            } else {
                ProgressView()
                    .tint(MenuTheme.green)
                    .scaleEffect(0.82)

                Text("Определяю адрес…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(
            GlassCardBackground(isSelected: false, cornerRadius: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MenuTheme.softGlowGradient, lineWidth: 1)
                        .opacity(0.16)
                )
        )
    }

    private var pickerSelectButton: some View
    {
        Button(action: selectPickedAddress) {
            Text("Выбрать")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.03, green: 0.10, blue: 0.08))
                .frame(width: 96, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MenuTheme.green)
                )
        }
        .buttonStyle(
            GlassPressButtonStyle(
                cornerRadius: 18,
                scale: 0.94,
                shadowColor: MenuTheme.green.opacity(0.18),
                shadowRadius: 14,
                shadowY: 9
            )
        )
        .accessibilityLabel("Выбрать адрес на карте")
    }

    private func resolvePickedCoordinate()
    {
        Task {
            do {
                _ = try await showAddress.resolveSelectedAddress(using: routeService)
            } catch is CancellationError {
            } catch {
            }
        }
    }

    private func selectPickedAddress()
    {
        guard let target = showAddress.target,
              let response = showAddress.resolvedAddress else {
            return
        }

        onAddressResolved(target, response)
        showAddress.close()
    }
}

struct ShowAddressPickerMapView: UIViewRepresentable
{
    @Binding var selectedCoordinate: CLLocationCoordinate2D
    let locatorCoordinate: CLLocationCoordinate2D?
    let resolvedCoordinateNonce: Int
    let zoomInNonce: Int
    let zoomOutNonce: Int
    let recenterNonce: Int
    let onCoordinateCommitted: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator
    {
        Coordinator(
            selectedCoordinate: $selectedCoordinate,
            locatorCoordinate: locatorCoordinate,
            onCoordinateCommitted: onCoordinateCommitted
        )
    }

    func makeUIView(context: Context) -> MKMapView
    {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.pointOfInterestFilter = .includingAll

        let tileOverlay = OverZoomOSMTileOverlay(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            tileCache: Tilecache(folderName: "show_address_osm_tiles")
        )
        tileOverlay.canReplaceMapContent = true
        tileOverlay.minimumZ = 0
        tileOverlay.maximumZ = 21
        mapView.addOverlay(tileOverlay, level: .aboveLabels)
        mapView.addOverlays(
            MapBorders.makeOverlays(),
            level: .aboveLabels
        )

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


        context.coordinator.configureInitialState(on: mapView)
        context.coordinator.installZoomButtons(on: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context)
    {
        context.coordinator.onCoordinateCommitted = onCoordinateCommitted
        context.coordinator.selectedCoordinate = $selectedCoordinate
        context.coordinator.locatorCoordinate = locatorCoordinate

        context.coordinator.updateAnnotation(
            coordinate: selectedCoordinate,
            on: mapView,
            recenterIfNeeded: false
        )
        context.coordinator.updateLocatorAnnotation(on: mapView)

        context.coordinator.applyResolvedCoordinateIfNeeded(
            nonce: resolvedCoordinateNonce,
            coordinate: selectedCoordinate,
            on: mapView
        )

        context.coordinator.applyControlRequests(
            zoomInNonce: zoomInNonce,
            zoomOutNonce: zoomOutNonce,
            recenterNonce: recenterNonce,
            on: mapView
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate
    {
        var selectedCoordinate: Binding<CLLocationCoordinate2D>
        var locatorCoordinate: CLLocationCoordinate2D?
        var onCoordinateCommitted: (CLLocationCoordinate2D) -> Void

        private let annotation = ShowAddressPointAnnotation(coordinate: MapConstant.moscowCenter)
        private let locatorAnnotation = ShowAddressLocatorAnnotation(coordinate: MapConstant.moscowCenter)
        private weak var zoomButtons: ZoomButtons?
        private weak var mapView: MKMapView?
        private weak var mapTouchGesture: UILongPressGestureRecognizer?
        private var lastZoomInNonce = 0
        private var lastZoomOutNonce = 0
        private var lastRecenterNonce = 0
        private var lastResolvedCoordinateNonce = 0
        private var didConfigureInitialState = false
        private var isDraggingAnnotation = false
        private var isApplyingResolvedCoordinate = false
        private var isLocatingLocatorPoint = false
        private var isZoomingFromLocator = false


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

        init(
            selectedCoordinate: Binding<CLLocationCoordinate2D>,
            locatorCoordinate: CLLocationCoordinate2D?,
            onCoordinateCommitted: @escaping (CLLocationCoordinate2D) -> Void
        )
        {
            self.selectedCoordinate = selectedCoordinate
            self.locatorCoordinate = locatorCoordinate
            self.onCoordinateCommitted = onCoordinateCommitted
        }

        func configureInitialState(on mapView: MKMapView)
        {
            guard didConfigureInitialState == false else {
                return
            }

            didConfigureInitialState = true
            self.mapView = mapView

            let region = MKCoordinateRegion(
                center: selectedCoordinate.wrappedValue,
                span: MapConstant.startSpan
            )
            mapView.setRegion(region, animated: false)

            updateAnnotation(
                coordinate: selectedCoordinate.wrappedValue,
                on: mapView,
                recenterIfNeeded: false
            )
            updateLocatorAnnotation(on: mapView)
            installMapTouchTracking(on: mapView)
        }

        func updateAnnotation(
            coordinate: CLLocationCoordinate2D,
            on mapView: MKMapView,
            recenterIfNeeded: Bool
        )
        {
            annotation.coordinate = coordinate

            if mapView.annotations.contains(where: { $0 === annotation }) == false {
                mapView.addAnnotation(annotation)
            }

            if recenterIfNeeded {
                mapView.setCenter(coordinate, animated: true)
            }
        }

        func updateLocatorAnnotation(on mapView: MKMapView)
        {
            guard let locatorCoordinate else {
                if mapView.annotations.contains(where: { $0 === locatorAnnotation }) {
                    mapView.removeAnnotation(locatorAnnotation)
                }

                zoomButtons?.setLocateButtonEnabled(false)
                zoomButtons?.setLocateButtonActive(false)
                return
            }

            locatorAnnotation.coordinate = locatorCoordinate

            if mapView.annotations.contains(where: { $0 === locatorAnnotation }) == false {
                mapView.addAnnotation(locatorAnnotation)
            }

            zoomButtons?.setLocateButtonEnabled(true)
        }

        func applyControlRequests(
            zoomInNonce: Int,
            zoomOutNonce: Int,
            recenterNonce: Int,
            on mapView: MKMapView
        )
        {
            if zoomInNonce != lastZoomInNonce {
                lastZoomInNonce = zoomInNonce
                changeZoom(scale: 0.62)
            }

            if zoomOutNonce != lastZoomOutNonce {
                lastZoomOutNonce = zoomOutNonce
                changeZoom(scale: 1.65)
            }

            if recenterNonce != lastRecenterNonce {
                lastRecenterNonce = recenterNonce
                focusLocator()
            }
        }

        func applyResolvedCoordinateIfNeeded(
            nonce: Int,
            coordinate: CLLocationCoordinate2D,
            on mapView: MKMapView
        )
        {
            guard nonce != lastResolvedCoordinateNonce else {
                return
            }

            lastResolvedCoordinateNonce = nonce
            isApplyingResolvedCoordinate = true
            updateAnnotation(
                coordinate: coordinate,
                on: mapView,
                recenterIfNeeded: false
            )
            setAnnotationMoving(false, on: mapView)
            mapView.setCenter(coordinate, animated: true)
        }

        func installZoomButtons(on mapView: MKMapView)
        {
            guard zoomButtons == nil else {
                return
            }

            let controls = ZoomButtons()
            controls.onZoomIn = { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.mapView = mapView
                self.changeZoom(scale: 0.62)
            }
            controls.onZoomOut = { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.mapView = mapView
                self.changeZoom(scale: 1.65)
            }
            controls.onLocatePreferredPoint = { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.mapView = mapView
                self.focusLocator()
            }

            mapView.addSubview(controls)

            NSLayoutConstraint.activate([
                controls.trailingAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                controls.centerYAnchor.constraint(equalTo: mapView.centerYAnchor, constant: -8)
            ])

            controls.setLocateButtonEnabled(locatorCoordinate != nil)
            controls.setLocateButtonActive(false)
            zoomButtons = controls
        }

        private func focusLocator()
        {
            guard let mapView,
                  let locatorCoordinate else {
                zoomButtons?.setLocateButtonActive(false)
                return
            }

            isLocatingLocatorPoint = true
            zoomButtons?.setLocateButtonActive(true)
            animateCenterMap(
                on: mapView,
                coordinate: locatorCoordinate,
                distance: 500
            )
        }

        private func changeZoom(scale: Double)
        {
            guard let mapView else {
                return
            }

            isZoomingFromLocator = isCenteredOnLocator(in: mapView)

            if isZoomingFromLocator == false {
                isLocatingLocatorPoint = false
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

        private func animateCenterMap(
            on mapView: MKMapView,
            coordinate: CLLocationCoordinate2D,
            distance: CLLocationDistance
        )
        {
            centerAnimator?.invalidate()
            centerAnimator = nil
            zoomAnimator?.invalidate()
            zoomAnimator = nil

            guard let startCamera = mapView.camera.copy() as? MKMapCamera else {
                let targetCamera = MKMapCamera(
                    lookingAtCenter: coordinate,
                    fromDistance: distance,
                    pitch: 0,
                    heading: 0
                )
                mapView.setCamera(targetCamera, animated: true)
                return
            }

            let clampedDistance = min(max(distance, minimumZoomDistance), maximumZoomDistance)
            let targetCamera = MKMapCamera(
                lookingAtCenter: coordinate,
                fromDistance: clampedDistance,
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

        @objc private func handleMapTouchGesture(_ gesture: UILongPressGestureRecognizer)
        {
            guard gesture.state == .began else {
                return
            }

            isLocatingLocatorPoint = false
            isZoomingFromLocator = false
            zoomButtons?.setLocateButtonActive(false)
        }
        
        private func isCenteredOnLocator(in mapView: MKMapView) -> Bool
        {
            guard let locatorCoordinate else {
                return false
            }

            let centerPoint = MKMapPoint(mapView.centerCoordinate)
            let targetPoint = MKMapPoint(locatorCoordinate)
            let horizontalTolerance = max(mapView.visibleMapRect.width * 0.025, 24)
            let verticalTolerance = max(mapView.visibleMapRect.height * 0.025, 24)

            return
                abs(centerPoint.x - targetPoint.x) <= horizontalTolerance &&
                abs(centerPoint.y - targetPoint.y) <= verticalTolerance
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
                isLocatingLocatorPoint = false
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
                isZoomingFromLocator = false
            }

        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer
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
                renderer.strokeColor = UIColor(
                    red: 0.62,
                    green: 0.96,
                    blue: 0.88,
                    alpha: 0.36
                )
                renderer.fillColor = .clear
                renderer.lineWidth = 11
                return renderer
            }

            if overlay is BorderOverlay {
                let renderer = MKPolygonRenderer(overlay: overlay)
                renderer.strokeColor = UIColor(
                    red: 0.76,
                    green: 0.99,
                    blue: 0.92,
                    alpha: 0.92
                )
                renderer.fillColor = UIColor(
                    red: 0.85,
                    green: 1.0,
                    blue: 0.96,
                    alpha: 0.018
                )
                renderer.lineWidth = 2.6
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
        {
            if annotation is ShowAddressLocatorAnnotation {
                let reuseIdentifier = "ShowAddressLocatorAnnotationView"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? ShowAddressLocatorAnnotationView
                    ?? ShowAddressLocatorAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)

                view.annotation = annotation
                return view
            }

            guard annotation is ShowAddressPointAnnotation else {
                return nil
            }

            let reuseIdentifier = "ShowAddressPointAnnotationView"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? ShowAddressPointAnnotationView
                ?? ShowAddressPointAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)

            view.annotation = annotation
            view.canShowCallout = false
            view.isDraggable = true
            view.displayPriority = .required

            return view
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            didChange newState: MKAnnotationView.DragState,
            fromOldState oldState: MKAnnotationView.DragState
        )
        {
            switch newState {
            case .starting:
                isDraggingAnnotation = true
                (view as? ShowAddressPointAnnotationView)?.setMoving(true, animated: true)
                view.dragState = .dragging
            case .ending, .canceling:
                view.dragState = .none
                isDraggingAnnotation = false
                (view as? ShowAddressPointAnnotationView)?.setMoving(false, animated: true)

                guard let coordinate = view.annotation?.coordinate else {
                    return
                }

                selectedCoordinate.wrappedValue = coordinate
                onCoordinateCommitted(coordinate)
            default:
                break
            }
        }

        func mapView(
            _ mapView: MKMapView,
            regionWillChangeAnimated animated: Bool
        )
        {
            guard isApplyingResolvedCoordinate == false else {
                return
            }

            if isLocatingLocatorPoint == false && isZoomingFromLocator == false {
                zoomButtons?.setLocateButtonActive(false)
            }

            setAnnotationMoving(true, on: mapView)
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView)
        {
            guard isDraggingAnnotation == false,
                  isApplyingResolvedCoordinate == false else {
                return
            }

            let coordinate = mapView.centerCoordinate
            annotation.coordinate = coordinate
            selectedCoordinate.wrappedValue = coordinate
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool)
        {
            if isApplyingResolvedCoordinate {
                isApplyingResolvedCoordinate = false
                setAnnotationMoving(false, on: mapView)
                return
            }

            guard isDraggingAnnotation == false else {
                return
            }

            let coordinate = mapView.centerCoordinate
            annotation.coordinate = coordinate
            selectedCoordinate.wrappedValue = coordinate
            setAnnotationMoving(false, on: mapView)
            onCoordinateCommitted(coordinate)
        }

        private func setAnnotationMoving(_ isMoving: Bool, on mapView: MKMapView)
        {
            guard let view = mapView.view(for: annotation) as? ShowAddressPointAnnotationView else {
                return
            }

            view.setMoving(isMoving, animated: true)
        }
    }
}

private final class ShowAddressPointAnnotation: NSObject, MKAnnotation
{
    dynamic var coordinate: CLLocationCoordinate2D
    let title: String? = "Точка подачи"

    init(coordinate: CLLocationCoordinate2D)
    {
        self.coordinate = coordinate
        super.init()
    }
}

private final class ShowAddressLocatorAnnotation: NSObject, MKAnnotation
{
    dynamic var coordinate: CLLocationCoordinate2D
    let title: String? = "Мое местоположение"

    init(coordinate: CLLocationCoordinate2D)
    {
        self.coordinate = coordinate
        super.init()
    }
}

private final class ShowAddressLocatorAnnotationView: MKAnnotationView
{
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



private final class ShowAddressPointAnnotationView: MKAnnotationView
{
    private let badgeView = UIView()
    private let orangeView = UIView()
    private let glyphImageView = UIImageView()
    private let stemLayer = CAShapeLayer()
    private var isMoving = false

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
        setMoving(false, animated: false)
    }

    override func layoutSubviews()
    {
        super.layoutSubviews()

        let badgeSize = CGSize(width: 62, height: 62)
        badgeView.frame = CGRect(
            x: (bounds.width - badgeSize.width) / 2,
            y: 0,
            width: badgeSize.width,
            height: badgeSize.height
        )
        badgeView.layer.cornerRadius = 22

        orangeView.frame = badgeView.bounds.insetBy(dx: 7, dy: 7)
        orangeView.layer.cornerRadius = 17

        glyphImageView.frame = orangeView.bounds.insetBy(dx: 9, dy: 9)

        let stemPath = UIBezierPath()
        stemPath.move(to: CGPoint(x: bounds.midX, y: badgeView.frame.maxY - 1))
        stemPath.addLine(to: CGPoint(x: bounds.midX, y: bounds.height - 3))
        stemLayer.path = stemPath.cgPath
    }

    func setMoving(_ isMoving: Bool, animated: Bool)
    {
        guard self.isMoving != isMoving || animated == false else {
            return
        }

        self.isMoving = isMoving

        let changes = {
            if isMoving {
                self.transform = CGAffineTransform(translationX: 0, y: -10)
                    .scaledBy(x: 1.035, y: 1.035)
            } else {
                self.transform = .identity
            }
        }

        if animated {
            UIView.animate(
                withDuration: isMoving ? 0.16 : 0.22,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut],
                animations: changes
            )
        } else {
            changes()
        }
    }

    private func configure()
    {
        frame = CGRect(x: 0, y: 0, width: 72, height: 96)
        centerOffset = CGPoint(x: 0, y: -48)
        backgroundColor = .clear
        canShowCallout = false
        displayPriority = .required

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.20
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 6)

        stemLayer.strokeColor = UIColor(red: 0.03, green: 0.03, blue: 0.03, alpha: 1.0).cgColor
        stemLayer.fillColor = UIColor.clear.cgColor
        stemLayer.lineWidth = 5
        stemLayer.lineCap = .round
        layer.addSublayer(stemLayer)

        badgeView.backgroundColor = .white
        badgeView.layer.masksToBounds = false
        addSubview(badgeView)

        orangeView.backgroundColor = UIColor(red: 1.0, green: 0.53, blue: 0.05, alpha: 1.0)
        orangeView.layer.masksToBounds = true
        badgeView.addSubview(orangeView)

        glyphImageView.contentMode = .scaleAspectFit
        glyphImageView.tintColor = UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1.0)
        glyphImageView.image = UIImage(systemName: "figure.walk")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 25, weight: .bold))
        orangeView.addSubview(glyphImageView)
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
