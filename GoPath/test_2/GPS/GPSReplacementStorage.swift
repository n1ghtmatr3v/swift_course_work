import Foundation
import Combine
import MapKit

private struct SavedAddressesSnapshot: Codable {
    let items: [SavedAddressEntry]
    let selectedID: UUID?
}

@MainActor
final class SavedAddressesStore: ObservableObject {
    @Published private(set) var items: [SavedAddressEntry] = []
    @Published private(set) var selectedID: UUID?

    private let storageKey = "saved_addresses_v1"
    let limit = 20

    init() {
        load()
    }

    var canAddMore: Bool {
        items.count < limit
    }

    var preferredEntry: SavedAddressEntry? {
        guard let selectedID else {
            return nil
        }

        guard let entry = items.first(where: { $0.id == selectedID }) else {
            return nil
        }

        guard hasDuplicateAddress(id: entry.id, address: entry.address) == false else {
            return nil
        }

        return entry.trimmedAddress.isEmpty ? nil : entry
    }

    var preferredSyncKey: String {
        guard let preferredEntry else {
            return "none"
        }

        return "\(preferredEntry.id.uuidString)|\(preferredEntry.routeQuery.lowercased())"
    }

    func hasResolvedAddress(
        id: UUID,
        matchingAddress: String
    ) -> Bool {
        guard let entry = items.first(where: { $0.id == id }) else {
            return false
        }

        let currentAddress = normalizedAddress(entry.address)
        let expectedAddress = normalizedAddress(matchingAddress)

        return expectedAddress.isEmpty == false &&
        currentAddress == expectedAddress &&
        entry.hasResolvedPayload
    }

    func hasDuplicateAddress(
        id: UUID,
        address: String
    ) -> Bool {
        let expectedAddress = normalizedAddress(address)

        guard expectedAddress.isEmpty == false else {
            return false
        }

        return items.contains {
            $0.id != id &&
            normalizedAddress($0.address) == expectedAddress
        }
    }

    func hasAddress(_ address: String) -> Bool {
        let expectedAddress = normalizedAddress(address)

        guard expectedAddress.isEmpty == false else {
            return false
        }

        return items.contains {
            normalizedAddress($0.address) == expectedAddress
        }
    }

    func duplicateEntryID(for address: String) -> UUID? {
        let expectedAddress = normalizedAddress(address)

        guard expectedAddress.isEmpty == false else {
            return nil
        }

        return items.first {
            normalizedAddress($0.address) == expectedAddress
        }?.id
    }

    @discardableResult
    func reuseCachedResolvedAddress(
        for id: UUID,
        matchingAddress: String
    ) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return false
        }

        let expectedAddress = normalizedAddress(matchingAddress)
        guard expectedAddress.isEmpty == false,
              normalizedAddress(items[index].address) == expectedAddress else {
            return false
        }

        guard hasDuplicateAddress(id: id, address: matchingAddress) == false,
              items[index].hasResolvedPayload else {
            return false
        }

        return true
    }

    @discardableResult
    func addEntry() -> UUID? {
        guard canAddMore else {
            return nil
        }

        let entry = SavedAddressEntry(address: "")
        items.append(entry)
        save()
        return entry.id
    }

    @discardableResult
    func addResolvedEntry(
        address: String,
        resolvedAddress: String?,
        coordinate: CLLocationCoordinate2D?
    ) -> UUID? {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard canAddMore,
              trimmedAddress.isEmpty == false,
              hasAddress(trimmedAddress) == false else {
            return nil
        }

        let entry = SavedAddressEntry(
            address: trimmedAddress,
            resolvedAddress: resolvedAddress,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude
        )

        items.append(entry)
        save()
        return entry.id
    }

    func updateAddress(id: UUID, address: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        let oldNormalized = normalizedAddress(items[index].address)
        items[index].address = address

        let newNormalized = normalizedAddress(items[index].address)
        if oldNormalized != newNormalized {
            items[index].resolvedAddress = nil
            items[index].latitude = nil
            items[index].longitude = nil
        }

        if selectedID == id,
           (items[index].trimmedAddress.isEmpty ||
            hasDuplicateAddress(id: id, address: items[index].address)) {
            selectedID = nil
        }

        save()
    }

    func removeEntry(id: UUID) {
        items.removeAll { $0.id == id }

        if selectedID == id {
            selectedID = nil
        }

        save()
    }

    func toggleSelection(id: UUID) {
        guard let entry = items.first(where: { $0.id == id }) else {
            return
        }

        guard entry.trimmedAddress.isEmpty == false else {
            return
        }

        guard hasDuplicateAddress(id: id, address: entry.address) == false else {
            return
        }

        if selectedID == id {
            selectedID = nil
        } else {
            selectedID = id
            moveEntryToFront(id: id)
        }

        save()
    }

    func updateResolvedCoordinate(
        _ coordinate: CLLocationCoordinate2D?,
        for id: UUID
    ) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        let newLatitude = coordinate?.latitude
        let newLongitude = coordinate?.longitude

        if items[index].latitude == newLatitude,
           items[index].longitude == newLongitude {
            return
        }

        items[index].latitude = newLatitude
        items[index].longitude = newLongitude
        save()
    }

    func updateResolvedAddress(
        fullName: String?,
        coordinate: CLLocationCoordinate2D?,
        for id: UUID,
        matchingAddress: String? = nil
    ) -> Void {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        if let matchingAddress {
            let currentAddress = items[index].trimmedAddress.lowercased()
            let expectedAddress = matchingAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            guard currentAddress == expectedAddress else {
                return
            }
        }

        let trimmedFullName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newResolvedAddress = trimmedFullName?.isEmpty == false ? trimmedFullName : nil
        let newLatitude = coordinate?.latitude
        let newLongitude = coordinate?.longitude

        if items[index].resolvedAddress == newResolvedAddress,
           items[index].latitude == newLatitude,
           items[index].longitude == newLongitude {
            return
        }

        items[index].resolvedAddress = newResolvedAddress
        items[index].latitude = newLatitude
        items[index].longitude = newLongitude
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            items = []
            selectedID = nil
            return
        }

        do {
            let snapshot = try JSONDecoder().decode(SavedAddressesSnapshot.self, from: data)
            let nonEmptyItems = snapshot.items.filter {
                $0.trimmedAddress.isEmpty == false
            }
            items = Array(nonEmptyItems.prefix(limit))
            selectedID = snapshot.selectedID

            if let selectedID,
               items.contains(where: { $0.id == selectedID }) == false {
                self.selectedID = nil
            }

            if let selectedID,
               let selectedEntry = items.first(where: { $0.id == selectedID }),
               hasDuplicateAddress(id: selectedID, address: selectedEntry.address) {
                self.selectedID = nil
            }
        } catch {
            items = []
            selectedID = nil
        }
    }

    private func save() {
        do {
            let snapshot = SavedAddressesSnapshot(
                items: Array(items.prefix(limit)),
                selectedID: selectedID
            )

            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
        }
    }

    private func moveEntryToFront(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              index != 0 else {
            return
        }

        let entry = items.remove(at: index)
        items.insert(entry, at: 0)
    }

    private static func normalizedAddress(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private func normalizedAddress(_ text: String) -> String {
        Self.normalizedAddress(text)
    }
}
