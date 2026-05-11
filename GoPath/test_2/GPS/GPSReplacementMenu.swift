import Foundation
import SwiftUI

private struct SavedAddressSwipeRow<Content: View>: View {
    let id: UUID
    let rowHeight: CGFloat
    @Binding var openedRowID: UUID?
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var horizontalOffset: CGFloat = 0

    private let revealWidth: CGFloat = 78
    private let cornerRadius: CGFloat = 16
    private let deleteTriggerThreshold: CGFloat = 0.70
    private let destructiveColor = Color(red: 0.86, green: 0.20, blue: 0.20)

    private func clampedOffset(_ translation: CGFloat, fullSwipeWidth: CGFloat) -> CGFloat {
        min(0, max(-fullSwipeWidth, translation))
    }

    private func isHorizontalSwipe(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height) + 10
    }

    var body: some View {
        GeometryReader { proxy in
            let rowShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let fullSwipeWidth = max(revealWidth, proxy.size.width - 12)
            let resolvedOffset = clampedOffset(horizontalOffset, fullSwipeWidth: fullSwipeWidth)
            let revealedWidth = max(0, -resolvedOffset)
            let revealProgress = min(1, max(0, revealedWidth / revealWidth))
            let backgroundOpacity = min(1, max(0, revealedWidth / 22))
            let deleteIconOpacity = min(1, max(0, (revealedWidth - 4) / 85))
            let deleteIconScale = 0.75 + (revealProgress * 0.25)

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

                content()
                    .offset(x: resolvedOffset)
            }
            .clipShape(rowShape)
            .contentShape(rowShape)
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        guard isHorizontalSwipe(value.translation) else {
                            return
                        }

                        if value.translation.width >= 0 {
                            withAnimation(.easeOut(duration: 0.12)) {
                                horizontalOffset = 0
                            }
                            return
                        }

                        openedRowID = id
                        horizontalOffset = clampedOffset(
                            value.translation.width,
                            fullSwipeWidth: fullSwipeWidth
                        )
                    }
                    .onEnded { value in
                        guard isHorizontalSwipe(value.translation) else {
                            return
                        }

                        let proposedOffset = clampedOffset(
                            value.translation.width,
                            fullSwipeWidth: fullSwipeWidth
                        )
                        let shouldRequestDelete = proposedOffset <= -(fullSwipeWidth * deleteTriggerThreshold)

                        if shouldRequestDelete {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                                horizontalOffset = proposedOffset
                                openedRowID = id
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                                onDelete()
                            }
                        } else {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                                horizontalOffset = 0
                                openedRowID = nil
                            }
                        }
                    }
            )
            .onChange(of: openedRowID) { _, newValue in
                guard newValue != id, horizontalOffset != 0 else {
                    return
                }

                withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                    horizontalOffset = 0
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
    }
}

struct SavedAddressesMenu: View {
    @ObservedObject var store: SavedAddressesStore

    let onBack: () -> Void
    let onClose: () -> Void
    let onSelectionChanged: () -> Void
    let onResolveAddress: (UUID, String) async -> String?
    let onCreateAddress: (String) async -> String?

    private let duplicateAddressText = "Поле с таким адресом уже есть"
    private let outOfBoundsAddressText = "Введенный адрес выходит за границы карты"
    @FocusState private var isNewAddressFocused: Bool
    @State private var resolveTasks: [UUID: Task<Void, Never>] = [:]
    @State private var resolvingIDs = Set<UUID>()
    @State private var resolveErrors: [UUID: String] = [:]
    @State private var isNewAddressEditorVisible = false
    @State private var newAddressText = ""
    @State private var newAddressError: String?
    @State private var isCreatingAddress = false
    @State private var duplicateHighlightedID: UUID?
    @State private var openedSwipeRowID: UUID?
    @State private var pendingDeleteEntryID: UUID?

    private var isDuplicateHighlightVisible: Bool {
        duplicateHighlightedID != nil
    }

    private var isBackdropHighlightVisible: Bool {
        isDuplicateHighlightVisible || isOutOfBoundsNewAddressError
    }

    private var isDeleteAlertPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteEntryID != nil },
            set: { isPresented in
                if isPresented == false {
                    pendingDeleteEntryID = nil
                }
            }
        )
    }

    private var newAddressEditorAccent: Color {
        Color(red: 0.78, green: 0.62, blue: 1.0)
    }

    private var duplicateHighlightStrokeColor: Color {
        Color(red: 1.0, green: 0.66, blue: 0.22).opacity(0.96)
    }

    private var isOutOfBoundsNewAddressError: Bool {
        newAddressError == outOfBoundsAddressText
    }

    var body: some View {
        ZStack {
            MenuBackgroundView(imageName: "SavedAddressesBackground")

            Color.black
                .opacity(isBackdropHighlightVisible ? 0.68 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerBlock
                        .opacity(isBackdropHighlightVisible ? 0.18 : 1.0)

                    if store.items.isEmpty && isNewAddressEditorVisible == false {
                        emptyState
                            .opacity(isBackdropHighlightVisible ? 0.18 : 1.0)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.items) { item in
                                addressRow(for: item)
                                    .opacity(rowOpacity(for: item))
                            }

                            if isNewAddressEditorVisible {
                                newAddressEditor
                            }
                        }
                    }

                    if store.canAddMore {
                        addAddressButton
                            .opacity(isBackdropHighlightVisible ? 0.18 : 1.0)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 98)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        guard openedSwipeRowID != nil else {
                            return
                        }

                        closeOpenSwipeRow()
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard openedSwipeRowID != nil,
                              abs(value.translation.height) > abs(value.translation.width) else {
                            return
                        }

                        closeOpenSwipeRow()
                    }
            )

            VStack {
                topBar
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(
            "Удалить данный адрес ?",
            isPresented: isDeleteAlertPresented
        ) {
            Button("Удалить", role: .destructive) {
                confirmPendingDelete()
            }

            Button("Отмена", role: .cancel) {
                closeOpenSwipeRow()
                pendingDeleteEntryID = nil
            }
        }
        .onDisappear {
            cancelResolveTasks()
        }
        .onChange(of: isNewAddressFocused) { _, isFocused in
            guard isFocused == false else {
                return
            }

            dismissEmptyNewAddressIfNeeded()
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Где я ?")
                .font(.system(size: 29, weight: .bold))
                .foregroundColor(.white)

            Text("Здесь вы можете добавить ваши избранные адреса. Выбрав один любой из них, карта будет всегда открываться по нему и показывать локатор, который демонстрирует ваше местоположение.")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(MenuTheme.mutedText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var addAddressButton: some View {
        Button(action: handleAddAddressButtonTapped) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(
                            MenuTheme.green.opacity(0.72),
                            style: StrokeStyle(lineWidth: 1.3, dash: [4, 5])
                        )

                    Image(systemName: isNewAddressEditorVisible ? "checkmark" : "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(MenuTheme.green)
                }
                .frame(width: 34, height: 34)

                Text(isNewAddressEditorVisible ? "Сохранить адрес" : "Добавить адрес")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isCreatingAddress {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("\(store.items.count)/\(store.limit)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MenuTheme.faintText)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .frame(maxWidth: .infinity)
            .background(GlassCardBackground(isSelected: false, cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isCreatingAddress)
        .opacity(isCreatingAddress ? 0.78 : 1.0)
    }

    private func rowOpacity(for item: SavedAddressEntry) -> Double {
        if isOutOfBoundsNewAddressError {
            return 0.12
        }

        guard let duplicateHighlightedID else {
            return 1.0
        }

        return duplicateHighlightedID == item.id ? 1.0 : 0.12
    }

    private var topBar: some View {
        ZStack(alignment: .top) {
            HStack {
                Button(action: {
                    closeOpenSwipeRow()
                    dismissEmptyNewAddressIfNeeded()
                    onBack()
                }) {
                    Text("Назад")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 36)
                        .background(GlassControlBackground(cornerRadius: 13))
                }
                .buttonStyle(GlassPressButtonStyle(cornerRadius: 13, scale: 0.955))
                .accessibilityLabel("Назад")

                Spacer()

                Button(action: {
                    closeOpenSwipeRow()
                    dismissEmptyNewAddressIfNeeded()
                    onClose()
                }) {
                    Text("Готово")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 96, height: 36)
                        .background(MenuTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(
                    GradientGlassPressButtonStyle(
                        cornerRadius: 13,
                        scale: 0.970,
                        shadowColor: MenuTheme.blue.opacity(0.20),
                        shadowRadius: 12,
                        shadowY: 6
                    )
                )
            }
            .padding(.top, -46)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 112)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Пока ничего нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("Добавьте адрес, который хотите использовать как стартовую точку по умолчанию.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(MenuTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlassCardBackground(isSelected: false, cornerRadius: 16))
    }

    private var newAddressEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                TextField(
                    "",
                    text: $newAddressText,
                    prompt: Text("Адрес")
                        .foregroundColor(Color.white.opacity(0.44))
                )
                    .focused($isNewAddressFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                    .disabled(isCreatingAddress)
                    .submitLabel(.done)
                    .onSubmit {
                        handleAddAddressButtonTapped()
                    }
                    .onChange(of: newAddressText) { _, _ in
                        newAddressError = nil
                        duplicateHighlightedID = nil
                    }

                Button(action: cancelNewAddressInput) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.62))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isCreatingAddress)
                .accessibilityLabel("Отменить добавление адреса")
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(GlassCardBackground(isSelected: false, cornerRadius: 16))
            .overlay {
                if newAddressError == nil {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.44, green: 0.31, blue: 0.72).opacity(0.15),
                                        Color(red: 0.52, green: 0.38, blue: 0.82).opacity(0.13),
                                        Color(red: 0.44, green: 0.31, blue: 0.72).opacity(0.15)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(newAddressEditorAccent.opacity(0.18), lineWidth: 1.5)
                            .blur(radius: 10)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        newAddressError == nil
                        ? newAddressEditorAccent.opacity(0.40)
                        : isOutOfBoundsNewAddressError
                        ? Color.red.opacity(0.52)
                        : duplicateHighlightStrokeColor,
                        lineWidth: newAddressError == duplicateAddressText ? 1.25 : 1
                    )
            )
            .overlay {
                if newAddressError == nil {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(newAddressEditorAccent.opacity(0.32), lineWidth: 1.15)
                        .blur(radius: 8)
                }
            }

            if let newAddressError {
                Text(newAddressError)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(
                        isOutOfBoundsNewAddressError
                        ? Color.red.opacity(0.95)
                        : Color.orange.opacity(0.92)
                    )
                    .lineLimit(isOutOfBoundsNewAddressError ? 2 : 1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
            } else if isCreatingAddress {
                Text("Проверяем адрес...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MenuTheme.mutedText)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
            }
        }
    }

    private func handleAddAddressButtonTapped() {
        closeOpenSwipeRow()

        guard isCreatingAddress == false else {
            return
        }

        guard isNewAddressEditorVisible else {
            newAddressText = ""
            newAddressError = nil
            isNewAddressEditorVisible = true

            DispatchQueue.main.async {
                isNewAddressFocused = true
            }
            return
        }

        let trimmedAddress = newAddressText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedAddress.isEmpty == false else {
            cancelNewAddressInput()
            return
        }

        guard store.hasAddress(trimmedAddress) == false else {
            newAddressError = duplicateAddressText
            duplicateHighlightedID = store.duplicateEntryID(for: trimmedAddress)
            isNewAddressFocused = true
            return
        }

        isCreatingAddress = true
        newAddressError = nil
        duplicateHighlightedID = nil

        Task {
            let errorText = await onCreateAddress(trimmedAddress)

            await MainActor.run {
                isCreatingAddress = false

                if let errorText {
                    newAddressError = errorText
                    isNewAddressFocused = true
                } else {
                    newAddressText = ""
                    newAddressError = nil
                    duplicateHighlightedID = nil
                    isNewAddressEditorVisible = false
                    isNewAddressFocused = false
                }
            }
        }
    }

    private func cancelNewAddressInput() {
        guard isCreatingAddress == false else {
            return
        }

        newAddressText = ""
        newAddressError = nil
        duplicateHighlightedID = nil
        isNewAddressEditorVisible = false
        isNewAddressFocused = false
    }

    private func closeOpenSwipeRow() {
        withAnimation(.easeInOut(duration: 0.18)) {
            openedSwipeRowID = nil
        }
    }

    private func dismissEmptyNewAddressIfNeeded() {
        guard isCreatingAddress == false,
              isNewAddressEditorVisible,
              newAddressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        cancelNewAddressInput()
    }

    private func confirmPendingDelete() {
        guard let pendingDeleteEntryID else {
            return
        }

        withAnimation(.easeInOut(duration: 0.20)) {
            store.removeEntry(id: pendingDeleteEntryID)
            openedSwipeRowID = nil
            self.pendingDeleteEntryID = nil
        }

        onSelectionChanged()
    }

    private func scheduleResolveAddress(
        id: UUID,
        address: String,
        delay: UInt64 = 550_000_000
    ) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        resolveTasks[id]?.cancel()

        guard trimmedAddress.isEmpty == false else {
            resolveTasks[id] = nil
            resolvingIDs.remove(id)
            resolveErrors[id] = nil
            return
        }

        if store.hasDuplicateAddress(id: id, address: trimmedAddress) {
            resolveTasks[id] = nil
            resolvingIDs.remove(id)
            resolveErrors[id] = duplicateAddressText
            return
        }

        if store.reuseCachedResolvedAddress(
            for: id,
            matchingAddress: trimmedAddress
        ) {
            resolveTasks[id] = nil
            resolvingIDs.remove(id)
            resolveErrors[id] = nil
            return
        }

        resolveTasks[id] = Task {
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }

            guard Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                resolvingIDs.insert(id)
                resolveErrors[id] = nil
            }

            let errorText = await onResolveAddress(id, trimmedAddress)

            guard Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                resolvingIDs.remove(id)
                resolveTasks[id] = nil

                if let errorText {
                    resolveErrors[id] = errorText
                } else {
                    resolveErrors[id] = nil
                }
            }
        }
    }

    private func cancelResolveTasks() {
        for task in resolveTasks.values {
            task.cancel()
        }

        resolveTasks = [:]
        resolvingIDs = []
    }

    private func addressRow(for item: SavedAddressEntry) -> some View {
        let isSelected = store.selectedID == item.id
        let isDuplicateHighlightMatch = duplicateHighlightedID == item.id
        let hasAddress = item.trimmedAddress.isEmpty == false
        let isDuplicate = store.hasDuplicateAddress(
            id: item.id,
            address: item.address
        )
        let hasStatusText = resolvingIDs.contains(item.id)
            || resolveErrors[item.id] != nil
            || isDuplicate
            || item.trimmedResolvedAddress.isEmpty == false
        let statusText: String? = {
            if resolvingIDs.contains(item.id) {
                return "Проверяем адрес..."
            }

            if isDuplicate {
                return duplicateAddressText
            }

            if let errorText = resolveErrors[item.id] {
                return errorText
            }

            if item.trimmedResolvedAddress.isEmpty == false {
                return item.trimmedResolvedAddress
            }

            return nil
        }()
        let statusColor: Color = {
            if isDuplicate {
                return Color.orange.opacity(0.92)
            }

            if resolveErrors[item.id] != nil {
                return Color(red: 1.0, green: 0.42, blue: 0.45).opacity(0.92)
            }

            return isSelected ? MenuTheme.green.opacity(0.92) : MenuTheme.mutedText
        }()
        let rowHeight: CGFloat = hasStatusText ? 101 : 87

        return SavedAddressSwipeRow(
            id: item.id,
            rowHeight: rowHeight,
            openedRowID: $openedSwipeRowID,
            onDelete: {
                dismissEmptyNewAddressIfNeeded()
                pendingDeleteEntryID = item.id
            }
        ) {
            HStack(spacing: 12) {
                Button(action: {
                    closeOpenSwipeRow()
                    dismissEmptyNewAddressIfNeeded()

                    guard isDuplicate == false else {
                        resolveErrors[item.id] = duplicateAddressText
                        return
                    }

                    let shouldResolveAfterSelection = store.selectedID != item.id

                    withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                        store.toggleSelection(id: item.id)
                    }

                    if shouldResolveAfterSelection, hasAddress {
                        scheduleResolveAddress(
                            id: item.id,
                            address: item.address,
                            delay: 0
                        )
                    }

                    onSelectionChanged()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(isSelected ? Color(red: 0.84, green: 1.0, blue: 0.88) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(
                                        isSelected
                                        ? MenuTheme.green.opacity(0.96)
                                        : Color.white.opacity(0.20),
                                        lineWidth: isSelected ? 2.2 : 1.8
                                    )
                            )
                            .shadow(
                                color: isSelected ? MenuTheme.green.opacity(0.24) : .clear,
                                radius: 10,
                                x: 0,
                                y: 0
                            )

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(MenuTheme.green)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(hasAddress == false || isDuplicate)
                .opacity(hasAddress && isDuplicate == false ? 1.0 : 0.55)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.trimmedAddress.isEmpty ? "Адрес не заполнен" : item.address)
                        .foregroundColor(item.trimmedAddress.isEmpty ? Color.white.opacity(0.40) : .white)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let statusText {
                        Text(statusText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(statusColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "mappin.circle.fill" : "mappin.circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? MenuTheme.green : Color.white.opacity(0.28))
            }
            .padding(.horizontal, 16)
            .frame(height: rowHeight)
            .background(SavedAddressRowBackground(isSelected: isSelected))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected
                        ? MenuTheme.selectedStroke
                        : isDuplicateHighlightMatch
                        ? duplicateHighlightStrokeColor
                        : isDuplicate
                        ? Color.orange.opacity(0.35)
                        : MenuTheme.cardStroke,
                        lineWidth: isSelected ? 1.8 : isDuplicateHighlightMatch ? 1.25 : 1
                    )
            )
        }
        .padding(.horizontal, 1)
    }
}

private struct SavedAddressRowBackground: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(red: 0.14, green: 0.17, blue: 0.21))
            .overlay {
                if isSelected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(MenuTheme.softGlowGradient.opacity(0.14))

                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(
                color: isSelected ? MenuTheme.green.opacity(0.14) : Color.black.opacity(0.12),
                radius: isSelected ? 8 : 8,
                x: 0,
                y: 5
            )
            .shadow(
                color: isSelected ? Color.white.opacity(0.05) : .clear,
                radius: isSelected ? 6 : 0,
                x: 0,
                y: 0
            )
    }
}
