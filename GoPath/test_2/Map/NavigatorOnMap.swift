import SwiftUI
import MapKit
import Combine

struct AddressHistoryEntry: Identifiable, Codable, Hashable
{
    let id: UUID
    let startQuery: String
    let endQuery: String

    init(
        id: UUID = UUID(),
        startQuery: String,
        endQuery: String
    )
    {
        self.id = id
        self.startQuery = startQuery
        self.endQuery = endQuery
    }
}

@MainActor
final class AddressHistoryStore: ObservableObject
{
    @Published private(set) var items: [AddressHistoryEntry] = []

    private let storageKey = "address_query_history_v1"
    private let limit = 20

    init()
    {
        load()
    }

    func add(startQuery: String, endQuery: String)
    {
        let trimmedStart = startQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnd = endQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedStart.isEmpty == false, trimmedEnd.isEmpty == false else {
            return
        }

        let entry = AddressHistoryEntry(
            startQuery: trimmedStart,
            endQuery: trimmedEnd
        )

        let normalizedKey = makeKey(startQuery: trimmedStart, endQuery: trimmedEnd)
        items.removeAll {
            makeKey(startQuery: $0.startQuery, endQuery: $0.endQuery) == normalizedKey
        }

        items.insert(entry, at: 0)
        items = Array(items.prefix(limit))
        save()
    }

    func remove(startQuery: String, endQuery: String)
    {
        let normalizedKey = makeKey(startQuery: startQuery, endQuery: endQuery)
        let oldCount = items.count

        items.removeAll {
            makeKey(startQuery: $0.startQuery, endQuery: $0.endQuery) == normalizedKey
        }

        if items.count != oldCount {
            save()
        }
    }

    func clear()
    {
        guard items.isEmpty == false else {
            return
        }

        items = []
        save()
    }

    private func load()
    {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            items = try JSONDecoder().decode([AddressHistoryEntry].self, from: data)
        } catch {
            items = []
        }
    }

    private func save()
    {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
        }
    }

    private func makeKey(startQuery: String, endQuery: String) -> String
    {
        let start = startQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let end = endQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(start)||\(end)"
    }
}

struct NavigatorOnMap: View
{
    private let preferredStartDisplayText = "Мое местоположение"
    private let outOfBoundsAddressText = "Введенный адрес выходит за границы карты"

    private enum MapUI
    {
        // логотип GoPath
        static let goPathTopPadding: CGFloat = 1
        static let goPathLeadingPadding: CGFloat = 14
        static let goPathLeafSize: CGFloat = 13.5
        static let goPathLeafOffsetX: CGFloat = 2
        static let goPathLeafOffsetY: CGFloat = -10
        static let goPathFontSize: CGFloat = 20.5
        static let goPathHeight: CGFloat = 50
        static let goPathHorizontalPadding: CGFloat = 16
        static let goPathCornerRadius: CGFloat = 18
        static let goPathGlowOpacity: CGFloat = 0.15
        static let goPathOffsetX: CGFloat = 0
        static let goPathOffsetY: CGFloat = -6

        // информационная панель
        static let infoTopPadding: CGFloat = 1
        static let infoTrailingPadding: CGFloat = 14
        static let infoIconToTextSpacing: CGFloat = 7
        static let infoIconSize: CGFloat = 12
        static let infoIconOffsetX: CGFloat = -2
        static let infoIconOffsetY: CGFloat = 0
        static let infoFontSize: CGFloat = 11.8
        static let infoBadgeWidth: CGFloat = 140
        static let infoBadgeHeight: CGFloat = 44
        static let infoHorizontalPadding: CGFloat = 13
        static let infoCornerRadius: CGFloat = 14
        static let infoGlowOpacity: CGFloat = 0.13
        static let infoOffsetX: CGFloat = 2
        static let infoOffsetY: CGFloat = -6

        // кнопка открыти меню "Маршрут"
        static let routeMenuButtonAnchorLeadingPadding: CGFloat = 10
        static let routeMenuButtonAnchorBottomPadding: CGFloat = 2
        static let routeMenuButtonIconSize: CGFloat = 25
        static let routeMenuButtonIconOffsetX: CGFloat = 0
        static let routeMenuButtonIconOffsetY: CGFloat = 0
        static let routeMenuButtonWidth: CGFloat = 62
        static let routeMenuButtonHeight: CGFloat = 65
        static let routeMenuButtonCornerRadius: CGFloat = 22
        static let routeMenuButtonGlowOpacity: CGFloat = 0.18
        static let routeMenuButtonLeadingPadding: CGFloat = -1
        static let routeMenuButtonBottomPadding: CGFloat = 10

        // Данные кнопки "Маршрут"
        static let routeInfoCardAnchorBottomPadding: CGFloat = -19
        static let routeInfoCardAnchorCenterBias: CGFloat = 27
        static let routeInfoCardAutoWidth: CGFloat = 299
        static let routeInfoCardWidth: CGFloat? = nil
        static let routeInfoCardHeight: CGFloat = 98
        static let routeInfoCardBottomPadding: CGFloat = 0
        static let routeInfoCardHorizontalOffset: CGFloat = 0
        static let routeInfoCardCornerRadius: CGFloat = 24
        static let routeInfoCardGlowOpacity: CGFloat = 0.16
        static let routeInfoCardInnerHorizontalPadding: CGFloat = 16

        static let routeSummarySpacing: CGFloat = 14

        static let routeSummaryIconContainerSize: CGFloat = 52
        static let routeSummaryIconCornerRadius: CGFloat = 16
        static let routeSummaryIconSize: CGFloat = 18
        static let routeSummaryIconOffsetX: CGFloat = 0
        static let routeSummaryIconOffsetY: CGFloat = 0
        static let routeSummaryTextStackSpacing: CGFloat = 8
        static let routeSummaryDistanceRowSpacing: CGFloat = 15
        static let routeSummaryAddressStackSpacing: CGFloat = 9
        static let routeSummaryDistanceFontSize: CGFloat = 15
        static let routeSummaryDurationFontSize: CGFloat = 15
        static let routeSummaryAddressFontSize: CGFloat = 14
        static let routeSummaryChevronSize: CGFloat = 14
        static let routeSummaryChevronOffsetX: CGFloat = 0
        static let routeSummaryChevronOffsetY: CGFloat = 0

        // Кнопка удаления маршрута
        static let routeTrashButtonAnchorTrailingPadding: CGFloat = 10
        
        static let routeTrashButtonAnchorBottomPadding: CGFloat = 12
        static let routeTrashButtonOffsetY: CGFloat = -718

        
        static let routeTrashIconSize: CGFloat = 18
        
        static let routeTrashIconOffsetX: CGFloat = 0
        static let routeTrashIconOffsetY: CGFloat = 0
        
        static let routeTrashButtonSize: CGFloat = 56
        static let routeTrashButtonHeight: CGFloat = 56
        
        static let routeTrashCornerRadius: CGFloat = 18
        static let routeTrashGlowOpacity: CGFloat = 0.16
    }

    @State private var startPoint: CLLocationCoordinate2D?
    @State private var endPoint: CLLocationCoordinate2D?
    @State private var routePoints: [RoutePoint] = []
    @State private var routeLengthMeters: Double?
    @State private var routeDurationSeconds: Double?
    @State private var preferredCenterPoint: CLLocationCoordinate2D?
    @State private var preferredCenterNonce = 0
    @State private var recenterRequestNonce = 0

    @State private var isAddressMenuVisible = false
    @State private var isSavedAddressesMenuVisible = false
    @State private var startAddress = ""
    @State private var endAddress = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didPerformInitialPreferredCenter = false
    @State private var shouldCenterPreferredAddressAfterClose = false

    private let routeService = BackendInitalizer()
    @StateObject private var searchAddress = SearchAddress()
    @StateObject private var addressHistory = AddressHistoryStore()
    @StateObject private var savedAddressesStore = SavedAddressesStore()
    @StateObject private var idleOverlayController = HideMenu()
    @StateObject private var showAddress = ShowAddress()

    var body: some View
    {
        ZStack {
            OSMMapView(
                startPoint: startPoint,
                endPoint: endPoint,
                routePoints: routePoints,
                preferredCenterPoint: preferredCenterPoint,
                usePreferredLocationAsStartMarker: isPreferredAlias(startAddress),
                preferredCenterNonce: preferredCenterNonce,
                recenterNonce: recenterRequestNonce,
                onUserInteraction: {
                    idleOverlayController.registerUserInteraction()
                }
            )
            .ignoresSafeArea()


            if isAddressMenuVisible == false {
                mapChromeOverlay
                    .zIndex(2)
            }

            if isAddressMenuVisible {
                MenuBackgroundView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(9)

                if isSavedAddressesMenuVisible {
                    SavedAddressesMenu(
                        store: savedAddressesStore,
                        onBack: {
                            idleOverlayController.registerUserInteraction()
                            isSavedAddressesMenuVisible = false

                            Task {
                                await syncPreferredAddressState(centerMap: false)
                            }
                        },
                        onClose: {
                            idleOverlayController.registerUserInteraction()
                            isSavedAddressesMenuVisible = false
                            isAddressMenuVisible = false
                            errorMessage = nil

                            searchAddress.clearStartResults()
                            searchAddress.clearEndResults()
                            centerPreferredAddressAfterMenuCloseIfNeeded()
                        },
                        onSelectionChanged: {
                            shouldCenterPreferredAddressAfterClose = false

                            Task {
                                await syncPreferredAddressState(centerMap: false)
                            }
                        },
                        onResolveAddress: { id, address in
                            await resolveSavedAddress(
                                id: id,
                                address: address
                            )
                        },
                        onCreateAddress: { address in
                            await createSavedAddress(address: address)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(11)
                } else {
                    AddressMenu(
                        startAddress: $startAddress,
                        endAddress: $endAddress,
                        errorMessage: errorMessage,
                        isLoading: isLoading,
                        startResults: searchAddress.startResults,
                        endResults: searchAddress.endResults,
                        historyItems: addressHistory.items,
                        selectStartSuggestion: { suggestion in
                            startAddress = suggestion.displayText
                            errorMessage = nil
                            searchAddress.clearStartResults()
                        },
                        selectEndSuggestion: { suggestion in
                            endAddress = suggestion.displayText
                            errorMessage = nil
                            searchAddress.clearEndResults()
                        },
                        selectHistoryItem: { item in
                            startAddress = item.startQuery
                            endAddress = item.endQuery
                            errorMessage = nil
                            searchAddress.clearStartResults()
                            searchAddress.clearEndResults()
                        },
                        deleteHistoryItem: { item in
                            addressHistory.remove(
                                startQuery: item.startQuery,
                                endQuery: item.endQuery
                            )
                        },
                        clearHistory: {
                            addressHistory.clear()
                        },
                        openSavedAddresses: {
                            idleOverlayController.registerUserInteraction()
                            errorMessage = nil
                            searchAddress.clearStartResults()
                            searchAddress.clearEndResults()

                            isSavedAddressesMenuVisible = true
                        },
                        swapAddresses: {
                            let currentStart = startAddress
                            startAddress = endAddress
                            endAddress = currentStart
                            errorMessage = nil
                            searchAddress.clearStartResults()
                            searchAddress.clearEndResults()
                        },
                        updateStartText: { text in
                            errorMessage = nil
                            searchAddress.updateStartQuery(text)
                        },
                        updateEndText: { text in
                            errorMessage = nil
                            searchAddress.updateEndQuery(text)
                        },
                        setStartEditing: { isEditing in
                            if isEditing == false {
                                searchAddress.clearStartResults()
                            }
                        },
                        setEndEditing: { isEditing in
                            if isEditing == false {
                                searchAddress.clearEndResults()
                            }
                        },
                        showOnMap: { target in
                            openMapAddressPicker(for: target)
                        },
                        closeMenu: {
                            idleOverlayController.registerUserInteraction()
                            isAddressMenuVisible = false
                            errorMessage = nil
                            searchAddress.clearStartResults()
                            searchAddress.clearEndResults()
                            centerPreferredAddressAfterMenuCloseIfNeeded()
                        },
                        onApply: {
                            idleOverlayController.registerUserInteraction()
                            Task {
                                await applyAddresses()
                            }
                        }
                    )

                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(10)
                }
            }

            if showAddress.isPickerVisible {
                ShowAddressPickerScreen(
                    showAddress: showAddress,
                    routeService: routeService,
                    onAddressResolved: { target, response in
                        applyMapPickedAddress(target: target, response: response)
                    },
                    onClose: {
                        errorMessage = nil
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .zIndex(30)
            }
        }
        .onAppear {
            idleOverlayController.startIdleTimer()
        }
        .onDisappear {
            idleOverlayController.stopIdleTimer()
        }
        .task {
            guard didPerformInitialPreferredCenter == false else {
                return
            }

            didPerformInitialPreferredCenter = true
            await syncPreferredAddressState(centerMap: true)
        }
        .task(id: savedAddressesStore.preferredSyncKey) {
            guard didPerformInitialPreferredCenter,
                  isSavedAddressesMenuVisible == false else {
                return
            }

            await syncPreferredAddressState(centerMap: false)
        }
    }

    

    private var mapChromeOverlay: some View
    {
        VStack(spacing: 0) {
            mapTopBar
            Spacer()
            mapBottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mapTopBar: some View
    {
        ZStack {
            HStack(spacing: 2) {
                Text("Go")
                    .foregroundColor(.white)

                Text("Path")
                    .foregroundColor(MenuTheme.green)

                Image(systemName: "leaf.fill")
                    .font(.system(size: MapUI.goPathLeafSize, weight: .bold))
                    .foregroundColor(MenuTheme.green.opacity(0.95))
                    .offset(x: MapUI.goPathLeafOffsetX, y: MapUI.goPathLeafOffsetY)
            }
            .font(.system(size: MapUI.goPathFontSize, weight: .bold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: MapUI.goPathHeight)
            .padding(.horizontal, MapUI.goPathHorizontalPadding)
            .background(
                mapGlassPillBackground(
                    cornerRadius: MapUI.goPathCornerRadius,
                    glowOpacity: MapUI.goPathGlowOpacity
                )
            )
            .offset(x: MapUI.goPathOffsetX, y: MapUI.goPathOffsetY)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, MapUI.goPathTopPadding)
            .padding(.leading, MapUI.goPathLeadingPadding)

            if shouldShowIdleDecorativeBadges {
                HStack(spacing: MapUI.infoIconToTextSpacing) {
                    Image(systemName: "info.circle")
                        .font(.system(size: MapUI.infoIconSize, weight: .semibold))
                        .foregroundColor(Color(red: 0.72, green: 0.84, blue: 1.0))
                        .offset(x: MapUI.infoIconOffsetX, y: MapUI.infoIconOffsetY)

                    Text("Зона построения маршрутов")
                        .font(.system(size: MapUI.infoFontSize, weight: .semibold))
                        .foregroundColor(Color(red: 0.72, green: 0.84, blue: 1.0))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(
                    width: MapUI.infoBadgeWidth,
                    height: MapUI.infoBadgeHeight
                )
                .padding(.horizontal, MapUI.infoHorizontalPadding)
                .background(
                    mapGlassPillBackground(
                        cornerRadius: MapUI.infoCornerRadius,
                        glowOpacity: MapUI.infoGlowOpacity
                    )
                )
                .offset(x: MapUI.infoOffsetX, y: MapUI.infoOffsetY)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, MapUI.infoTopPadding)
                .padding(.trailing, MapUI.infoTrailingPadding)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.35), value: shouldShowIdleDecorativeBadges)
    }

    private var mapBottomBar: some View
    {
        ZStack(alignment: .bottom) {
            if hasRoutePresentation {
                anchoredRouteInfoCard
                anchoredRouteMenuButton
                anchoredRouteTrashButton
            } else {
                anchoredRouteMenuButton
            }
        }
        .animation(.easeInOut(duration: 0.35), value: shouldShowIdleDecorativeBadges)

    }
    private var routeMenuButton: some View
    {
        Button(action: {
            idleOverlayController.registerUserInteraction()
            openRouteMenu()
        }) {
            Image(systemName: "scope")
                .font(.system(size: MapUI.routeMenuButtonIconSize, weight: .semibold))
                .foregroundColor(Color(red: 0.70, green: 0.95, blue: 0.88))
                .offset(
                    x: MapUI.routeMenuButtonIconOffsetX,
                    y: MapUI.routeMenuButtonIconOffsetY
                )
                .frame(
                    width: MapUI.routeMenuButtonWidth,
                    height: MapUI.routeMenuButtonHeight
                )
                .background(
                    mapGlassPillBackground(
                        cornerRadius: MapUI.routeMenuButtonCornerRadius,
                        glowOpacity: MapUI.routeMenuButtonGlowOpacity
                    )
                )
        }
        .buttonStyle(
            GlassPressButtonStyle(
                cornerRadius: MapUI.routeMenuButtonCornerRadius,
                scale: 0.955,
                shadowColor: MenuTheme.green.opacity(0.12),
                shadowRadius: 16,
                shadowY: 10
            )
        )
        .offset(
            x: MapUI.routeMenuButtonLeadingPadding,
            y: -MapUI.routeMenuButtonBottomPadding
        )
    }

    private var routeSummaryCard: some View
    {
        Button(action: {
            idleOverlayController.registerUserInteraction()
            openRouteMenu()
        }) {
            HStack(spacing: MapUI.routeSummarySpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: MapUI.routeSummaryIconCornerRadius, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.25, blue: 0.22).opacity(0.90))

                    Image(systemName: "figure.walk")
                        .font(.system(size: MapUI.routeSummaryIconSize, weight: .semibold))
                        .foregroundColor(MenuTheme.green)
                        .offset(
                            x: MapUI.routeSummaryIconOffsetX,
                            y: MapUI.routeSummaryIconOffsetY
                        )
                }
                .frame(
                    width: MapUI.routeSummaryIconContainerSize,
                    height: MapUI.routeSummaryIconContainerSize
                )

                VStack(alignment: .leading, spacing: MapUI.routeSummaryTextStackSpacing) {
                    HStack(spacing: MapUI.routeSummaryDistanceRowSpacing) {
                        distanceDisplayText
                            .font(.system(size: MapUI.routeSummaryDistanceFontSize))
                            .foregroundColor(MenuTheme.green)


                        durationDisplayText
                            .font(.system(size: MapUI.routeSummaryDurationFontSize))
                            .foregroundColor(MenuTheme.green)
                    }

                    VStack(alignment: .leading, spacing: MapUI.routeSummaryAddressStackSpacing) {
                            Text("От: \(routeStartDisplay)")
                                .foregroundColor(.white.opacity(0.82))
                                .font(.system(size: MapUI.routeSummaryAddressFontSize, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text("До: \(routeEndDisplay)")
                                .foregroundColor(.white.opacity(0.72))
                                .font(.system(size: MapUI.routeSummaryAddressFontSize, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: MapUI.routeSummaryChevronSize, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.42))
                    .offset(
                        x: MapUI.routeSummaryChevronOffsetX,
                        y: MapUI.routeSummaryChevronOffsetY
                    )
            }
            .padding(.horizontal, MapUI.routeInfoCardInnerHorizontalPadding)
            .frame(
                maxWidth: nil,
                minHeight: MapUI.routeInfoCardHeight
            )
            .frame(width: resolvedRouteInfoCardWidth)
            .background(
                GlassCardBackground(
                    isSelected: false,
                    cornerRadius: MapUI.routeInfoCardCornerRadius
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: MapUI.routeInfoCardCornerRadius, style: .continuous)
                    .stroke(MenuTheme.softGlowGradient, lineWidth: 1)
                    .opacity(MapUI.routeInfoCardGlowOpacity)
            )
        }
        .buttonStyle(
            GlassPressButtonStyle(
                cornerRadius: MapUI.routeInfoCardCornerRadius,
                scale: 0.988,
                shadowColor: Color.black.opacity(0.18),
                shadowRadius: 18,
                shadowY: 12
            )
        )
        .offset(
            x: MapUI.routeInfoCardHorizontalOffset,
            y: -MapUI.routeInfoCardBottomPadding
        )
    }

    private var routeTrashButton: some View
    {
        Button(action: {
            idleOverlayController.registerUserInteraction()
            clearRouteState()
        }) {
            Image(systemName: "trash")
                .font(.system(size: MapUI.routeTrashIconSize, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
                .offset(x: MapUI.routeTrashIconOffsetX, y: MapUI.routeTrashIconOffsetY)
                .frame(
                    width: MapUI.routeTrashButtonSize,
                    height: MapUI.routeTrashButtonHeight
                )
                .background(
                    mapGlassPillBackground(
                        cornerRadius: MapUI.routeTrashCornerRadius,
                        glowOpacity: MapUI.routeTrashGlowOpacity
                    )
                )
        }
        .buttonStyle(
            GlassPressButtonStyle(
                cornerRadius: MapUI.routeTrashCornerRadius,
                scale: 0.955,
                shadowColor: Color.black.opacity(0.16),
                shadowRadius: 12,
                shadowY: 8
            )
        )
    }

    private var anchoredRouteMenuButton: some View
    {
        routeMenuButton
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, MapUI.routeMenuButtonAnchorLeadingPadding)
            .padding(.bottom, MapUI.routeMenuButtonAnchorBottomPadding)
    }

    private var anchoredRouteInfoCard: some View
    {
        routeSummaryCard
            .frame(maxWidth: .infinity)
            .padding(.bottom, MapUI.routeInfoCardAnchorBottomPadding)
            .offset(x: MapUI.routeInfoCardAnchorCenterBias)
    }

    private var anchoredRouteTrashButton: some View
    {
        routeTrashButton
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, MapUI.routeTrashButtonAnchorTrailingPadding)
            .padding(.bottom, MapUI.routeTrashButtonAnchorBottomPadding)
            .offset(y: MapUI.routeTrashButtonOffsetY)
    }


    private var resolvedRouteInfoCardWidth: CGFloat
    {
        MapUI.routeInfoCardWidth ?? MapUI.routeInfoCardAutoWidth
    }

    private var hasRoutePresentation: Bool
    {
        hasRouteOnMap
    }

    private var shouldShowIdleDecorativeBadges: Bool
    {
        idleOverlayController.shouldShowDecorativeBadges && hasRoutePresentation == false
    }
    
    private var distanceDisplayText: Text
    {
        if routeDistanceDisplay.hasSuffix(" км") {
            let numberPart = String(routeDistanceDisplay.dropLast(3))

            return Text(
                "\(Text(numberPart).fontWeight(.bold))\(Text(" км").fontWeight(.regular))"
            )
        }

        if routeDistanceDisplay.hasSuffix(" м") {
            let numberPart = String(routeDistanceDisplay.dropLast(2))

            return Text(
                "\(Text(numberPart).fontWeight(.bold))\(Text(" м").fontWeight(.regular))"
            )
        }

        return Text(routeDistanceDisplay)
            .fontWeight(.bold)
    }





    private var durationDisplayText: Text
    {
        if routeDurationDisplay.contains(" ч ") && routeDurationDisplay.hasSuffix(" мин") {
            let parts = routeDurationDisplay.components(separatedBy: " ")

            if parts.count >= 4 {
                let hours = parts[0]
                let minutes = parts[2]

                return Text(
                    "\(Text(hours).fontWeight(.bold))\(Text(" ч ").fontWeight(.regular))\(Text(minutes).fontWeight(.bold))\(Text(" мин").fontWeight(.regular))"
                )
            }
        }

        if routeDurationDisplay.hasSuffix(" ч") {
            let hours = String(routeDurationDisplay.dropLast(2))

            return Text(
                "\(Text(hours).fontWeight(.bold))\(Text(" ч").fontWeight(.regular))"
            )
        }

        if routeDurationDisplay.hasSuffix(" мин") {
            let minutes = String(routeDurationDisplay.dropLast(4))

            return Text(
                "\(Text(minutes).fontWeight(.bold))\(Text(" мин").fontWeight(.regular))"
            )
        }

        return Text(routeDurationDisplay)
            .fontWeight(.bold)
    }


    private var routeDistanceDisplay: String
    {
        guard let routeLengthMeters else {
            return "4 820 м"
        }

        if routeLengthMeters >= 1_000 {
            let kilometersRoundedUp = (routeLengthMeters / 10).rounded(.up) / 100
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.decimalSeparator = ","
            formatter.groupingSeparator = " "
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2

            let formatted = formatter.string(
                from: NSNumber(value: kilometersRoundedUp)
            ) ?? String(format: "%.2f", kilometersRoundedUp)
                .replacingOccurrences(of: ".", with: ",")

            return "\(formatted) км"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0

        let metersValue = NSNumber(value: Int(routeLengthMeters.rounded()))
        let formatted = formatter.string(from: metersValue) ?? "\(Int(routeLengthMeters.rounded()))"
        return "\(formatted) м"
    }


    private var routeDurationDisplay: String
    {
        if let routeLengthMeters, routeLengthMeters <= 0 {
            return "0 мин"
        }

        let durationSeconds = routeDurationSeconds
            ?? routeLengthMeters.map { ($0 / 1.4).rounded(.up) }

        guard let durationSeconds else {
            return "?"
        }

        if durationSeconds <= 0 {
            return "0 мин"
        }

        let totalMinutes = max(1, Int((durationSeconds / 60).rounded(.up)))

        if totalMinutes < 60 {
            return "\(totalMinutes) мин"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if minutes == 0 {
            return "\(hours) ч"
        }

        return "\(hours) ч \(minutes) мин"
    }



    private var routeStartDisplay: String
    {
        mapCardAddressDisplay(startAddress, fallback: "...")
    }

    private var routeEndDisplay: String
    {
        mapCardAddressDisplay(endAddress, fallback: "...")
    }

    private func mapCardAddressDisplay(_ value: String, fallback: String) -> String
    {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.isEmpty == false else {
            return fallback
        }

        return trimmed
    }

    private func openRouteMenu()
    {
        restorePreferredStartDisplayIfNeeded()
        errorMessage = nil
        isSavedAddressesMenuVisible = false
        isAddressMenuVisible = true
    }

    private func openMapAddressPicker(for target: ShowAddressTarget)
    {
        idleOverlayController.registerUserInteraction()
        errorMessage = nil
        searchAddress.clearStartResults()
        searchAddress.clearEndResults()

        let initialCoordinate: CLLocationCoordinate2D?

        switch target {
        case .start:
            initialCoordinate = startPoint ?? preferredCenterPoint
        case .end:
            initialCoordinate = endPoint ?? preferredCenterPoint
        }

        showAddress.open(
            target: target,
            initialCoordinate: initialCoordinate,
            locatorCoordinate: preferredCenterPoint
        )

    }

    private func applyMapPickedAddress(
        target: ShowAddressTarget,
        response: AddressResolveResponse
    )
    {
        errorMessage = nil
        searchAddress.clearStartResults()
        searchAddress.clearEndResults()

        switch target {
        case .start:
            startAddress = response.fullName
        case .end:
            endAddress = response.fullName
        }
    }

    private var hasRouteOnMap: Bool
    {
        routePoints.isEmpty == false ||
        routeLengthMeters != nil ||
        startPoint != nil ||
        endPoint != nil
    }

    @ViewBuilder
    private func mapGlassPillBackground(
        cornerRadius: CGFloat,
        glowOpacity: Double
    ) -> some View
    {
        GlassCardBackground(
            isSelected: false,
            cornerRadius: cornerRadius
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MenuTheme.softGlowGradient, lineWidth: 1)
                .opacity(glowOpacity)
        )
    }

    private var routeLengthText: String?
    {
        guard let routeLengthMeters else {
            return nil
        }

        if routeLengthMeters < 1_000 {
            return "\(Int(routeLengthMeters.rounded())) м"
        }

        let kilometersRoundedUp = (routeLengthMeters / 10).rounded(.up) / 100
        let formatted = String(format: "%.2f", kilometersRoundedUp)
            .replacingOccurrences(of: ".", with: ",")
        return "\(formatted) км"
    }


    private var preferredQuery: String?
    {
        guard let preferredEntry = savedAddressesStore.preferredEntry else {
            return nil
        }

        let query = preferredEntry.routeQuery
        return query.isEmpty ? nil : query
    }

    private func isPreferredAlias(_ text: String) -> Bool
    {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == preferredStartDisplayText
    }

    private func effectiveQuery(for text: String) -> String
    {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed == preferredStartDisplayText {
            return preferredQuery ?? ""
        }

        return trimmed
    }

    private func restorePreferredStartDisplayIfNeeded(force: Bool = false)
    {
        if preferredQuery != nil {
            if force ||
               startAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               isPreferredAlias(startAddress) {
                startAddress = preferredStartDisplayText
            }
        } else if force || isPreferredAlias(startAddress) {
            startAddress = ""
        }
    }

    @MainActor
    private func centerPreferredAddressAfterMenuCloseIfNeeded()
    {
        guard shouldCenterPreferredAddressAfterClose else {
            return
        }

        shouldCenterPreferredAddressAfterClose = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            await syncPreferredAddressState(centerMap: true)
        }
    }

    @MainActor
    private func resolveSavedAddress(
        id: UUID,
        address: String
    ) async -> String?
    {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedAddress.isEmpty == false else {
            savedAddressesStore.updateResolvedAddress(
                fullName: nil,
                coordinate: nil,
                for: id,
                matchingAddress: trimmedAddress
            )
            return nil
        }

        if savedAddressesStore.reuseCachedResolvedAddress(
            for: id,
            matchingAddress: trimmedAddress
        ) {
            return nil
        }

        do {
            let response = try await routeService.resolveAddress(
                query: trimmedAddress
            )

            let coordinate = CLLocationCoordinate2D(
                latitude: response.lat,
                longitude: response.lon
            )

            savedAddressesStore.updateResolvedAddress(
                fullName: response.fullName,
                coordinate: coordinate,
                for: id,
                matchingAddress: trimmedAddress
            )
            return nil
        } catch {
            savedAddressesStore.updateResolvedAddress(
                fullName: nil,
                coordinate: nil,
                for: id,
                matchingAddress: trimmedAddress
            )
            return savedAddressResolveErrorText(for: error)
        }
    }

    private func savedAddressResolveErrorText(for error: Error) -> String
    {
        if let backendError = error as? BackendError {
            return backendError.localizedDescription
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
                return "Backend не отвечает на localhost:8080"
            default:
                return "Не удалось проверить адрес"
            }
        }

        return "Backend не нашел адрес"
    }

    @MainActor
    private func createSavedAddress(address: String) async -> String?
    {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedAddress.isEmpty == false else {
            return "Введите адрес"
        }

        guard savedAddressesStore.hasAddress(trimmedAddress) == false else {
            return "Поле с таким адресом уже есть"
        }

        do {
            let response = try await routeService.resolveAddress(
                query: trimmedAddress
            )

            let coordinate = CLLocationCoordinate2D(
                latitude: response.lat,
                longitude: response.lon
            )

            guard isInsideAllowedSavedAddressRect(coordinate) else {
                return "Введенный адрес выходит за границы карты"
            }

            guard savedAddressesStore.addResolvedEntry(
                address: trimmedAddress,
                resolvedAddress: response.fullName,
                coordinate: coordinate
            ) != nil else {
                return "Не удалось добавить адрес"
            }

            return nil
        } catch {
            return savedAddressResolveErrorText(for: error)
        }
    }

    private func isInsideAllowedSavedAddressRect(
        _ coordinate: CLLocationCoordinate2D
    ) -> Bool
    {
        coordinate.latitude >= MapBorders.minLatitude
            && coordinate.latitude <= MapBorders.maxLatitude
            && coordinate.longitude >= MapBorders.minLongitude
            && coordinate.longitude <= MapBorders.maxLongitude
    }

    private func routeAddressIsInsideAllowedRect(_ query: String) async throws -> Bool
    {
        let response = try await routeService.resolveAddress(query: query)
        let coordinate = CLLocationCoordinate2D(
            latitude: response.lat,
            longitude: response.lon
        )

        return isInsideAllowedSavedAddressRect(coordinate)
    }

    @MainActor
    private func syncPreferredAddressState(centerMap: Bool) async
    {
        guard let preferredEntry = savedAddressesStore.preferredEntry else {
            preferredCenterPoint = nil

            if isPreferredAlias(startAddress) {
                startAddress = ""
            }

            return
        }

        restorePreferredStartDisplayIfNeeded()

        var coordinate = preferredEntry.coordinate
        var resolvedAddress = preferredEntry.trimmedResolvedAddress

        if coordinate == nil || resolvedAddress.isEmpty {
            _ = await resolveSavedAddress(
                id: preferredEntry.id,
                address: preferredEntry.trimmedAddress
            )

            if let refreshedEntry = savedAddressesStore.preferredEntry {
                coordinate = refreshedEntry.coordinate
                resolvedAddress = refreshedEntry.trimmedResolvedAddress
            }
        }

        preferredCenterPoint = coordinate

        if centerMap, coordinate != nil {
            preferredCenterNonce += 1
        }
    }

    @MainActor
    private func clearRouteState()
    {
        startPoint = nil
        endPoint = nil
        routePoints = []
        routeLengthMeters = nil
        routeDurationSeconds = nil

        endAddress = ""
        errorMessage = nil
        isLoading = false

        searchAddress.clearStartResults()
        searchAddress.clearEndResults()
        restorePreferredStartDisplayIfNeeded(force: true)
    }

    @MainActor
    private func applyAddresses() async
    {
        let trimmedStart = startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnd = endAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        if isPreferredAlias(trimmedStart), preferredQuery == nil {
            errorMessage = "Для начала выберите адрес для \"Моего местоположения\"."
            return
        }

        if isPreferredAlias(trimmedEnd), preferredQuery == nil {
            errorMessage = "Для начала выберите адрес для \"Моего местоположения\"."
            return
        }

        let effectiveStartQuery = effectiveQuery(for: trimmedStart)
        let effectiveEndQuery = effectiveQuery(for: trimmedEnd)

        guard effectiveStartQuery.isEmpty == false, effectiveEndQuery.isEmpty == false else {
            errorMessage = "Заполните оба адреса."
            return
        }

        let isStartPreferredAlias = isPreferredAlias(trimmedStart)
        let isEndPreferredAlias = isPreferredAlias(trimmedEnd)

        isLoading = true
        errorMessage = nil
        searchAddress.clearStartResults()
        searchAddress.clearEndResults()

        do {
            if isStartPreferredAlias == false {
                guard try await routeAddressIsInsideAllowedRect(effectiveStartQuery) else {
                    addressHistory.remove(
                        startQuery: effectiveStartQuery,
                        endQuery: effectiveEndQuery
                    )
                    isLoading = false
                    errorMessage = outOfBoundsAddressText
                    return
                }
            }

            if isEndPreferredAlias == false {
                guard try await routeAddressIsInsideAllowedRect(effectiveEndQuery) else {
                    addressHistory.remove(
                        startQuery: effectiveStartQuery,
                        endQuery: effectiveEndQuery
                    )
                    isLoading = false
                    errorMessage = outOfBoundsAddressText
                    return
                }
            }

            let response = try await routeService.buildRouteByAddress(
                startQuery: effectiveStartQuery,
                endQuery: effectiveEndQuery
            )

            guard response.route.isEmpty == false else {
                addressHistory.remove(
                    startQuery: effectiveStartQuery,
                    endQuery: effectiveEndQuery
                )
                isLoading = false
                errorMessage = "Маршрут не найден."
                return
            }

            addressHistory.add(
                startQuery: effectiveStartQuery,
                endQuery: effectiveEndQuery
            )

            startAddress = isStartPreferredAlias
                ? preferredStartDisplayText
                : response.startFullName
            endAddress = isEndPreferredAlias
                ? preferredStartDisplayText
                : response.endFullName

            startPoint = CLLocationCoordinate2D(
                latitude: response.startLat,
                longitude: response.startLon
            )
            endPoint = CLLocationCoordinate2D(
                latitude: response.endLat,
                longitude: response.endLon
            )
            routeLengthMeters = response.routeLengthMeters
            routeDurationSeconds = response.routeDurationSeconds
            routePoints = []

            isAddressMenuVisible = false
            isSavedAddressesMenuVisible = false
            errorMessage = nil

            try? await Task.sleep(nanoseconds: 180_000_000)
            routePoints = response.route
            isLoading = false
        } catch {
            addressHistory.remove(
                startQuery: effectiveStartQuery,
                endQuery: effectiveEndQuery
            )
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}




#Preview {
    NavigatorOnMap()
}
