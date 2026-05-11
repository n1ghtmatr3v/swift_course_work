import SwiftUI
import UIKit

struct AddressMenu: View {
    
    private enum HistoryConfirmAction {
        case deleteItem(AddressHistoryEntry)
        case clearAll
    }

    private enum FocusField {
        case start
        case end
    }

    @Binding var startAddress: String
    @Binding var endAddress: String
    let errorMessage: String?
    let isLoading: Bool

    let startResults: [SearchSuggestion]
    let endResults: [SearchSuggestion]
    let historyItems: [AddressHistoryEntry]

    let selectStartSuggestion: (SearchSuggestion) -> Void
    let selectEndSuggestion: (SearchSuggestion) -> Void
    let selectHistoryItem: (AddressHistoryEntry) -> Void
    let deleteHistoryItem: (AddressHistoryEntry) -> Void
    let clearHistory: () -> Void
    let openSavedAddresses: () -> Void
    let swapAddresses: () -> Void
    let updateStartText: (String) -> Void
    let updateEndText: (String) -> Void
    let setStartEditing: (Bool) -> Void
    let setEndEditing: (Bool) -> Void
    let showOnMap: (ShowAddressTarget) -> Void

    let closeMenu: () -> Void
    let onApply: () -> Void

    @State private var focusField: FocusField?
    @State private var openHistoryRowID: UUID?
    @State private var deletingHistoryRowID: UUID?
    @State private var historyAction: HistoryConfirmAction?
    @State private var showHistoryConfirm = false
    @GestureState private var isSearchPressed = false

    private let mapButtonTrailingPadding: CGFloat = 15
    private let mapButtonTopPadding: CGFloat = 130

    private var mapTarget: ShowAddressTarget? {
        switch focusField {
        case .start:
            return .start
        case .end:
            return .end
        case nil:
            return nil
        }
    }

    var body: some View {
        ZStack {
            MenuBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Маршрут")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundColor(.white)

                    VStack(spacing: 11) {
                        addressSection(
                            field: .start,
                            color: MenuTheme.redDot,
                            title: "Откуда",
                            text: $startAddress,
                            suggestions: startResults,
                            onTextChanged: updateStartText,
                            onSelectSuggestion: selectStartSuggestion
                        )

                        addressSection(
                            field: .end,
                            color: .white,
                            title: "Куда",
                            text: $endAddress,
                            suggestions: endResults,
                            onTextChanged: updateEndText,
                            onSelectSuggestion: selectEndSuggestion
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .trailing) {
                        PressableGlassIconButton(
                            action: {
                                focusField = nil
                                swapAddresses()
                            },
                            accessibilityLabel: "Поменять адреса местами",
                            cornerRadius: 17,
                            scale: 0.91,
                            shadowColor: Color.black.opacity(0.12),
                            shadowRadius: 7,
                            shadowY: 4,
                            overlayWidth: 34,
                            overlayHeight: 34
                        ) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(MenuTheme.green)
                                .frame(width: 34, height: 34)
                                // .background(MenuTheme.primaryGradient)
                                .background(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(MenuTheme.elevatedCardFill)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.trailing, -5)
                    }
                    .padding(.bottom, 2)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: {
                        focusField = nil
                        onApply()
                    }) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .medium))
                            }

                            Text(isLoading ? "Проверка..." : "Найти")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(MenuTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        // .shadow(color: MenuTheme.blue.opacity(0.20), radius: 14, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .modifier(
                        GradientGlassPressEffect(
                            isPressed: isSearchPressed,
                            cornerRadius: 16,
                            scale: 0.968,
                            shadowColor: MenuTheme.blue.opacity(0.20),
                            shadowRadius: 14,
                            shadowY: 8
                        )
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0, maximumDistance: 28)
                            .updating($isSearchPressed) { value, state, _ in
                                if isLoading {
                                    state = false
                                } else {
                                    state = value
                                }
                            }
                    )
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.82 : 1.0)

                    if historyItems.isEmpty == false {
                        historySection
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 132)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard openHistoryRowID != nil,
                          historyAction == nil,
                          deletingHistoryRowID == nil else {
                        return
                    }

                    closeHistoryRow()
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 8).onChanged { value in
                    guard openHistoryRowID != nil,
                          historyAction == nil,
                          deletingHistoryRowID == nil,
                          abs(value.translation.height) > abs(value.translation.width) else {
                        return
                    }

                    closeHistoryRow()
                }
            )

            VStack(spacing: 0) {
                topBar
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let mapTarget {
                showOnMapButton(target: mapTarget)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, mapButtonTrailingPadding)
                    .padding(.top, mapButtonTopPadding)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    .zIndex(30)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: focusField)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: focusField) { _, newValue in
            setStartEditing(newValue == .start)
            setEndEditing(newValue == .end)
        }
        .alert(
            historyConfirmTitle,
            isPresented: $showHistoryConfirm
        ) {
            Button("Отмена", role: .cancel) {
                let currentAction = historyAction
                showHistoryConfirm = false

                switch currentAction {
                case .deleteItem:
                    deletingHistoryRowID = nil

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
                        openHistoryRowID = nil
                        historyAction = nil
                    }
                case .clearAll:
                    historyAction = nil
                case nil:
                    break
                }
            }

            switch historyAction {
            case .deleteItem(let item):
                Button("Удалить", role: .destructive) {
                    showHistoryConfirm = false

                    withAnimation(.easeInOut(duration: 0.20)) {
                        deleteHistoryItem(item)
                        deletingHistoryRowID = nil
                        openHistoryRowID = nil
                    }

                    historyAction = nil
                }
            case .clearAll:
                Button("Очистить", role: .destructive) {
                    showHistoryConfirm = false

                    withAnimation(.easeInOut(duration: 0.20)) {
                        clearHistory()
                        deletingHistoryRowID = nil
                        openHistoryRowID = nil
                    }

                    historyAction = nil
                }
            case nil:
                EmptyView()
            }
        } message: {
            Text(historyConfirmMessage)
        }
    }

    private var historyConfirmTitle: String {
        switch historyAction {
        case .deleteItem:
            return "Удалить этот запрос\nиз истории?"
        case .clearAll:
            return "Очистить историю?"
        case nil:
            return ""
        }
    }

    private var historyConfirmMessage: String {
        switch historyAction {
        case .deleteItem:
            return "Запись будет удалена\nиз истории."
        case .clearAll:
            return "Вы действительно хотите удалить всю историю маршрутов?"
        case nil:
            return ""
        }
    }

    private var topBar: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.14),
                    Color.black.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 138)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.040))
                        .frame(width: 188, height: 188)
                        .blur(radius: 72)
                        .position(x: 12, y: 8)

                    Circle()
                        .fill(Color.white.opacity(0.032))
                        .frame(width: 214, height: 214)
                        .blur(radius: 82)
                        .position(x: 28, y: 18)

                    Circle()
                        .fill(Color.white.opacity(0.040))
                        .frame(width: 188, height: 188)
                        .blur(radius: 72)
                        .position(x: proxy.size.width - 12, y: 8)

                    Circle()
                        .fill(Color.white.opacity(0.032))
                        .frame(width: 214, height: 214)
                        .blur(radius: 82)
                        .position(x: proxy.size.width - 28, y: 18)
                }
            }
            .frame(height: 138)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.034),
                            Color.white.opacity(0.026),
                            Color.white.opacity(0.020)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 236, height: 96)
                .blur(radius: 44)
                .offset(y: 18)
                .allowsHitTesting(false)

            Ellipse()
                .fill(Color.white.opacity(0.030))
                .frame(width: 216, height: 78)
                .blur(radius: 38)
                .offset(y: 4)
                .allowsHitTesting(false)

            Ellipse()
                .fill(Color.white.opacity(0.020))
                .frame(width: 140, height: 54)
                .blur(radius: 30)
                .offset(y: 8)
                .allowsHitTesting(false)

            Ellipse()
                .fill(Color.white.opacity(0.024))
                .frame(width: 150, height: 34)
                .blur(radius: 22)
                .offset(y: -6)
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.024),
                            Color.white.opacity(0.020),
                            Color.white.opacity(0.018),
                            Color.white.opacity(0.016)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 296, height: 74)
                .blur(radius: 34)
                .offset(y: 34)
                .allowsHitTesting(false)

            Ellipse()
                .fill(Color.white.opacity(0.018))
                .frame(width: 196, height: 50)
                .blur(radius: 32)
                .offset(y: 36)
                .allowsHitTesting(false)

            Ellipse()
                .fill(MenuTheme.green.opacity(0.050))
                .frame(width: 90, height: 36)
                .blur(radius: 18)
                .offset(x: 32, y: 34)
                .allowsHitTesting(false)

            ZStack {
                HStack(alignment: .center) {
                    topButton(
                        title: "Адреса",
                        systemImage: "mappin.circle",
                        action: {
                            focusField = nil
                            openSavedAddresses()
                        }
                    )

                    Spacer()

                    topButton(
                        title: "Отменить",
                        systemImage: "xmark.circle",
                        action: closeMenu
                    )
                }

                VStack(spacing: 2) {
                    HStack(spacing: 0) {
                        Text("Go")
                            .foregroundColor(.white)
                            .shadow(color: Color.white.opacity(0.26), radius: 5, x: 0, y: 0)
                            .shadow(color: Color.white.opacity(0.10), radius: 11, x: 0, y: 0)

                        Text("Path")
                            .foregroundColor(MenuTheme.green)
                            .shadow(color: MenuTheme.green.opacity(0.32), radius: 5, x: 0, y: 0)
                            .shadow(color: MenuTheme.green.opacity(0.12), radius: 11, x: 0, y: 0)

                        Image(systemName: "leaf.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MenuTheme.green.opacity(0.95))
                            .offset(x: 2, y: -10)
                    }
                    .font(.custom("AvenirNext-Bold", size: 33))
                    .lineLimit(1)

                    Text("Ваш путь, ваш город")
                        .font(.system(size: 12.5, weight: .semibold)) // 11
                        // .foregroundColor(MenuTheme.green.opacity(0.95))
                    
                        .foregroundColor(MenuTheme.mutedText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(width: 140)
                .padding(.top, 7)
            }
            .padding(.horizontal, 15)
            .padding(.top, 23)
            .frame(maxWidth: .infinity)

        }
        .frame(maxWidth: .infinity)
        .frame(height: 128)
    }

    private func showOnMapButton(target: ShowAddressTarget) -> some View {
        Button(action: {
            closeHistoryRow()
            focusField = nil
            showOnMap(target)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 12.5, weight: .semibold))

                Text("Показать на карте?")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1) // 2
            }
            .foregroundColor(Color.black.opacity(0.86))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.76, blue: 0.46).opacity(0.84))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color(red: 1.0, green: 0.55, blue: 0.18).opacity(0.88), lineWidth: 1.15)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.48, blue: 0.16).opacity(0.20), radius: 9, x: 0, y: 4)
            )
        }
        .buttonStyle(
            GlassPressButtonStyle(
                cornerRadius: 13,
                scale: 0.955,
                shadowColor: Color.black.opacity(0.12),
                shadowRadius: 8,
                shadowY: 5
            )
        )
        .accessibilityLabel("Показать выбранное поле на карте")
    }

    private func topButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        let isCancelButton = title == "Отменить"
        let foregroundColor = isCancelButton
            ? Color(red: 0.72, green: 0.84, blue: 0.98)
            : Color.white.opacity(0.90)

        return Button(action: {
            closeHistoryRow()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular))

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .foregroundColor(foregroundColor)
            .frame(width: isCancelButton ? 96 : 86, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(red: 0.23, green: 0.26, blue: 0.30).opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.11), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(
            GlassPressButtonStyle(
                cornerRadius: 13,
                scale: 0.952,
                shadowColor: Color.black.opacity(0.12),
                shadowRadius: 8,
                shadowY: 5
            )
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(MenuTheme.green)

                Text("История")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                PressableGlassTextButton(
                    action: {
                        historyAction = .clearAll
                        showHistoryConfirm = true
                    },
                    accessibilityLabel: "Очистить историю",
                    scale: 0.955
                ) {
                    Text("Очистить")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.72, green: 0.84, blue: 0.98))
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(historyItems.prefix(20)), id: \.id) { item in
                    HistorySwipeRow(
                        item: item,
                        openRowID: $openHistoryRowID,
                        deletingRowID: $deletingHistoryRowID,
                        useRow: {
                            focusField = nil
                            selectHistoryItem(item)
                        },
                        onDelete: {
                            deletingHistoryRowID = item.id
                            historyAction = .deleteItem(item)
                            showHistoryConfirm = true
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func closeHistoryRow() {
        guard openHistoryRowID != nil else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            openHistoryRowID = nil
        }
    }

    private func addressSection(
        field: FocusField,
        color: Color,
        title: String,
        text: Binding<String>,
        suggestions: [SearchSuggestion],
        onTextChanged: @escaping (String) -> Void,
        onSelectSuggestion: @escaping (SearchSuggestion) -> Void
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                LocatorPulseDot(
                    color: color,
                    isActive: focusField == field
                )

                ZStack(alignment: .leading) {
                    if text.wrappedValue.isEmpty && focusField != field {
                        Text(title)
                            .foregroundColor(MenuTheme.mutedText)
                            .font(.system(size: 16, weight: .medium))
                            .allowsHitTesting(false)
                    }

                    if focusField == field {
                        AddressInputTextView(
                            text: Binding(
                                get: { text.wrappedValue },
                                set: { newValue in
                                    text.wrappedValue = newValue
                                    onTextChanged(newValue)
                                }
                            ),
                            isFirstResponder: true,
                            setEditing: { isEditing in
                                if isEditing {
                                    focusField = field
                                } else if focusField == field {
                                    focusField = nil
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if text.wrappedValue.isEmpty == false {
                        Text(shortInputAddress(text.wrappedValue))
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if text.wrappedValue.isEmpty == false {
                    AddressFieldClearButton {
                        let shouldKeepFocus = focusField == field
                        text.wrappedValue = ""
                        onTextChanged("")

                        if shouldKeepFocus {
                            focusField = field
                        }
                    }
                    .accessibilityLabel("Очистить поле")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(GlassCardBackground(isSelected: false, cornerRadius: 16))
            .contentShape(Rectangle())
            .onTapGesture {
                focusField = field
            }

            if focusField == field && suggestions.isEmpty == false {
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.prefix(6).enumerated()), id: \.offset) { index, item in
                        Button(action: {
                            focusField = nil
                            onSelectSuggestion(item)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .foregroundColor(.white)
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if item.subtitle.isEmpty == false {
                                    Text(item.subtitle)
                                        .foregroundColor(.gray)
                                        .font(.system(size: 13))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(MenuTheme.elevatedCardFill)
                        }
                        .buttonStyle(.plain)

                        if index < min(suggestions.count, 6) - 1 {
                            Divider()
                                .background(Color.white.opacity(0.08))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MenuTheme.cardStroke, lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shortInputAddress(_ address: String) -> String {
        
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLength = 32

        guard trimmed.count > maxLength else {
            return trimmed
        }

        let prefix = trimmed.prefix(maxLength - 3)
        return "\(prefix)..."
    }

}

private struct PressableGlassTextButton<Label: View>: View {
    
    let action: () -> Void
    let accessibilityLabel: String
    let scale: CGFloat
    @ViewBuilder let label: () -> Label

    @GestureState private var isPressed = false

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
        .modifier(GlassTextPressEffect(isPressed: isPressed, scale: scale))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PressableGlassIconButton<Label: View>: View {
    
    let action: () -> Void
    let accessibilityLabel: String
    let cornerRadius: CGFloat
    let scale: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let overlayWidth: CGFloat
    let overlayHeight: CGFloat
    @ViewBuilder let label: () -> Label

    @GestureState private var isPressed = false

    var body: some View {
        
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
        .modifier(
            GlassIconPressEffect(
                isPressed: isPressed,
                cornerRadius: cornerRadius,
                scale: scale,
                shadowColor: shadowColor,
                shadowRadius: shadowRadius,
                shadowY: shadowY,
                overlayWidth: overlayWidth,
                overlayHeight: overlayHeight
            )
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct AddressFieldClearButton: View {
    
    let action: () -> Void

    var body: some View {
        
        PressableGlassIconButton(
            action: action,
            accessibilityLabel: "Очистить поле",
            cornerRadius: 22,
            scale: 0.90,
            shadowColor: Color.black.opacity(0.10),
            shadowRadius: 4,
            shadowY: 2,
            overlayWidth: 20,
            overlayHeight: 20
        ) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.18)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .frame(width: 20, height: 20)

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.62))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
    }
}

private struct LocatorPulseDot: View {
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let color: Color
    let isActive: Bool

    @State private var firstWaveExpanded = false
    @State private var secondWaveExpanded = false
    @State private var isDotPulsing = false
    @State private var pulseID = UUID()

    var body: some View {
        ZStack {
            if reduceMotion == false {
                Circle()
                    .stroke(color.opacity(isActive ? 0.24 : 0.0), lineWidth: 1)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isActive ? (firstWaveExpanded ? 2.05 : 1.0) : 1.0)
                    .opacity(isActive ? (firstWaveExpanded ? 0.0 : 0.36) : 0.0)

                Circle()
                    .stroke(color.opacity(isActive ? 0.18 : 0.0), lineWidth: 1)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isActive ? (secondWaveExpanded ? 2.55 : 1.10) : 1.0)
                    .opacity(isActive ? (secondWaveExpanded ? 0.0 : 0.24) : 0.0)
            } else if isActive {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 20, height: 20)
                    .blur(radius: 4)
            }

            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .shadow(
                    color: color.opacity(isActive ? 0.54 : 0.40),
                    radius: isActive ? 7 : 6,
                    x: 0,
                    y: 0
                )
                .scaleEffect(
                    reduceMotion
                    ? 1.0
                    : (isActive ? (isDotPulsing ? 1.08 : 0.98) : 1.0)
                )
        }
        .frame(width: 28, height: 28)
        .onAppear {
            refreshPulse()
        }
        .onChange(of: isActive) { _, _ in
            refreshPulse()
        }
    }

    private func refreshPulse() {
        let runID = UUID()
        pulseID = runID

        guard isActive, reduceMotion == false else {
            firstWaveExpanded = false
            secondWaveExpanded = false
            isDotPulsing = false
            return
        }

        firstWaveExpanded = false
        secondWaveExpanded = false
        isDotPulsing = false

        withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
            isDotPulsing = true
        }

        withAnimation(.easeOut(duration: 1.18).repeatForever(autoreverses: false)) {
            firstWaveExpanded = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard pulseID == runID, isActive else {
                return
            }

            withAnimation(.easeOut(duration: 1.18).repeatForever(autoreverses: false)) {
                secondWaveExpanded = true
            }
        }
    }
}


private struct HistorySwipeRow: View {
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: AddressHistoryEntry
    @Binding var openRowID: UUID?
    @Binding var deletingRowID: UUID?
    let useRow: () -> Void
    let onDelete: () -> Void

    @State private var horizontalOffset: CGFloat = 0
    @State private var pinnedOffset: CGFloat = 0
    @State private var didFullSwipeDelete = false
    @State private var closeAnimID = UUID()
    @GestureState private var isChevronPressed = false

    private let revealWidth: CGFloat = 78
    private let rowHeight: CGFloat = 72
    
    // скругление ячеек
    private let cornerRadius: CGFloat = 16
    
    // сколько процентов должна занимать мусорка чтобы пояивлось меню
    private let deleteSwipeThreshold: CGFloat = 0.70
    
    private let fullDeleteThreshold: CGFloat = 0.98
    private let destructiveColor = Color(red: 0.86, green: 0.20, blue: 0.20)

    private func limitedOffset(_ translation: CGFloat, fullSwipeWidth: CGFloat) -> CGFloat {
        min(0, max(-fullSwipeWidth, translation))
    }

    private func isHorizontalSwipe(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height) + 10
    }

    private var swipeCloseAnimation: Animation {
        reduceMotion
        ? .easeOut(duration: 0.20)
        : .spring(response: 0.54, dampingFraction: 0.92, blendDuration: 0.05)
    }

    private var swipeCloseDuration: Double {
        reduceMotion ? 0.20 : 0.54
    }

    private func closeSwipe(resetOpenRow: Bool = true) {
        guard horizontalOffset != 0 || pinnedOffset != 0 || openRowID == item.id else {
            return
        }

        let animationID = UUID()
        closeAnimID = animationID

        withAnimation(swipeCloseAnimation) {
            horizontalOffset = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + swipeCloseDuration) {
            guard closeAnimID == animationID else {
                return
            }

            pinnedOffset = 0
            didFullSwipeDelete = false

            if resetOpenRow && openRowID == item.id {
                openRowID = nil
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            
            let rowShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let fullSwipeWidth = max(revealWidth, proxy.size.width)
            let currentOffset = limitedOffset(
                deletingRowID == item.id
                ? min(
                    horizontalOffset,
                    pinnedOffset == 0
                    ? -(fullSwipeWidth * deleteSwipeThreshold)
                    : pinnedOffset
                )
                : horizontalOffset,
                fullSwipeWidth: fullSwipeWidth
            )
            
            let revealedWidth = max(0, -currentOffset)
            let revealRatio = min(1, max(0, revealedWidth / revealWidth))
            let backgroundOpacity = min(1, max(0, revealedWidth / 22))
            let deleteIconOpacity = min(1, max(0, (revealedWidth - 4) / 85))
            let deleteIconScale = 0.75 + (revealRatio * 0.25)
            let rowIsPressed = isChevronPressed && horizontalOffset == 0
            let chevronOpacity = max(0, 1 - min(1, revealedWidth / 16))
            let isChevronInteractive = revealedWidth < 1 && deletingRowID != item.id
            let fadeStart = fullSwipeWidth * 0.62
            let fadeRange = max(1, fullSwipeWidth * 0.18)
            let isDeletePinned = deletingRowID == item.id
            let showRowContent = isDeletePinned == false
                && revealedWidth < (fullSwipeWidth * 0.92)
            let rowContentOpacity = max(
                0,
                1 - max(0, revealedWidth - fadeStart) / fadeRange
            )

            ZStack(alignment: .trailing) {
                if revealedWidth > 0.5 {
                    rowShape
                        .fill(destructiveColor)
                        .opacity(backgroundOpacity)
                        .mask(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .frame(width: revealedWidth, height: rowHeight)
                        }


                    Image(systemName: "trash.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                        .opacity(deleteIconOpacity)
                        .scaleEffect(deleteIconScale)
                        .frame(width: revealedWidth, height: rowHeight)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }




                if showRowContent {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(MenuTheme.green)
                            .frame(width: 38, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(MenuTheme.green.opacity(0.12))
                            )

                        VStack(alignment: .leading, spacing: 8) {
                            historyLine(
                                color: MenuTheme.redDot,
                                label: "Откуда",
                                address: item.startQuery
                            )

                            historyLine(
                                color: .white,
                                label: "Куда",
                                address: item.endQuery
                            )
                        }

                        Spacer(minLength: 0)

                        Button(action: {
                            guard horizontalOffset == 0 else {
                                closeDeleteSwipe()
                                return
                            }

                            useRow()
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.52))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(HistoryChevronPressButtonStyle())
                        .opacity(chevronOpacity)
                        .allowsHitTesting(isChevronInteractive)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .updating($isChevronPressed) { _, state, _ in
                                    guard isChevronInteractive else {
                                        state = false
                                        return
                                    }

                                    state = true
                                }
                        )
                        .accessibilityLabel("Вставить адреса из истории")
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(GlassCardBackground(isSelected: false, cornerRadius: cornerRadius))
                    .modifier(
                        HistoryCellPressModifier(
                            isPressed: rowIsPressed,
                            cornerRadius: cornerRadius
                        )
                    )
                    .opacity(rowContentOpacity)
                    .offset(x: currentOffset)
                    .onTapGesture {
                        if horizontalOffset != 0 {
                            closeDeleteSwipe()
                        }
                    }
                }
            }
            .clipShape(rowShape)
            .overlay {
                if showRowContent {
                    rowShape.stroke(MenuTheme.cardStroke, lineWidth: 1)
                }
            }
            .contentShape(rowShape)
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        guard isHorizontalSwipe(value.translation) else {
                            return
                        }

                        guard didFullSwipeDelete == false else {
                            return
                        }

                        if value.translation.width >= 0 {
                            closeSwipe()
                            return
                        }

                        closeAnimID = UUID()
                        openRowID = item.id
                        horizontalOffset = limitedOffset(
                            value.translation.width,
                            fullSwipeWidth: fullSwipeWidth
                        )

                        let reachedFullDelete = abs(horizontalOffset) >= (fullSwipeWidth * fullDeleteThreshold)

                        guard reachedFullDelete else {
                            return
                        }

                        didFullSwipeDelete = true
                        pinnedOffset = -fullSwipeWidth
                        horizontalOffset = -fullSwipeWidth
                        openRowID = item.id
                        deletingRowID = item.id

                        onDelete()
                    }
                    .onEnded { value in
                        guard isHorizontalSwipe(value.translation) else {
                            return
                        }

                        guard didFullSwipeDelete == false else {
                            return
                        }

                        let proposedOffset = limitedOffset(
                            value.translation.width,
                            fullSwipeWidth: fullSwipeWidth
                        )
                        let shouldRequestDelete = abs(proposedOffset) >= (fullSwipeWidth * deleteSwipeThreshold)

                        if shouldRequestDelete {
                            closeAnimID = UUID()
                            pinnedOffset = -fullSwipeWidth
                            horizontalOffset = -fullSwipeWidth
                            openRowID = item.id
                            deletingRowID = item.id

                            onDelete()
                        } else {
                            closeSwipe()
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
        .onChange(of: openRowID) { _, newValue in
            guard newValue != item.id,
                  deletingRowID != item.id,
                  horizontalOffset != 0 else {
                return
            }

            closeSwipe(resetOpenRow: false)
        }
        .onChange(of: deletingRowID) { _, newValue in
            guard newValue != item.id else {
                return
            }

            guard horizontalOffset != 0 || pinnedOffset != 0 else {
                pinnedOffset = 0
                didFullSwipeDelete = false
                return
            }

            closeSwipe(resetOpenRow: false)
        }
    }

    private func closeDeleteSwipe() {
        guard horizontalOffset != 0 || openRowID == item.id else {
            return
        }

        closeSwipe()
    }

    private func historyLine(
        color: Color,
        label: String,
        address: String
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(MenuTheme.faintText)
                .frame(width: 50, alignment: .leading)

            Text(shortHistoryAddress(address))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func shortHistoryAddress(_ address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLength = 32

        guard trimmed.count > maxLength else {
            return trimmed
        }

        let prefix = trimmed.prefix(maxLength - 3)
        return "\(prefix)..."
    }
}

private struct AddressInputTextView: UIViewRepresentable {
    @Binding var text: String
    let isFirstResponder: Bool
    let setEditing: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> AddressNativeTextView {
        let textView = AddressNativeTextView(frame: .zero, textContainer: nil)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.tintColor = .white
        textView.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartInsertDeleteType = .no
        textView.returnKeyType = .done
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = false
        textView.alwaysBounceHorizontal = false
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.clipsToBounds = true
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.maximumNumberOfLines = 1
        textView.textContainer.lineBreakMode = .byClipping
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.size = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.text = text
        textView.setContentOffset(.zero, animated: false)

        return textView
    }

    func updateUIView(_ uiView: AddressNativeTextView, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
            if uiView.isFirstResponder == false {
                uiView.setContentOffset(.zero, animated: false)
            }
        }

        if isFirstResponder {
            if uiView.isFirstResponder == false {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: AddressInputTextView

        init(_ parent: AddressInputTextView) {
            self.parent = parent
        }

        func applyText(_ newValue: String) {
            if parent.text != newValue {
                parent.text = newValue
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.setEditing(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.setEditing(false)
            textView.setContentOffset(.zero, animated: false)
        }

        func textViewDidChange(_ textView: UITextView) {
            applyText(textView.text)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if text == "\n" {
                textView.resignFirstResponder()
                return false
            }

            return true
        }
    }
}

private final class AddressNativeTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        textContainer.size = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: bounds.height
        )

        let lineHeight = font?.lineHeight ?? 0
        let verticalInset = max(0, (bounds.height - lineHeight) / 2)
        textContainerInset = UIEdgeInsets(
            top: verticalInset,
            left: 0,
            bottom: verticalInset,
            right: 0
        )
    }
}

private struct FullScreenPreviewWrapper: View {
    var body: some View {
        NavigatorOnMap()
    }
}

#Preview("iPhone") {
    FullScreenPreviewWrapper()
}
