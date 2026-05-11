import Foundation
import MapKit

struct SavedAddressEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var address: String
    var resolvedAddress: String?
    var latitude: Double?
    var longitude: Double?

    init(
        id: UUID = UUID(),
        address: String,
        resolvedAddress: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.address = address
        self.resolvedAddress = resolvedAddress
        self.latitude = latitude
        self.longitude = longitude
    }

    var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedResolvedAddress: String {
        resolvedAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var routeQuery: String {
        trimmedResolvedAddress.isEmpty ? trimmedAddress : trimmedResolvedAddress
    }

    var hasResolvedPayload: Bool {
        trimmedResolvedAddress.isEmpty == false &&
        latitude != nil &&
        longitude != nil
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else {
            return nil
        }

        return CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
    }
}
