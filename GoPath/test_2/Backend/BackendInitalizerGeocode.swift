import Foundation
import CoreLocation
import MapKit

extension BackendInitalizer {
    func resolveAddressWithSystemGeocoder(
        lat: Double,
        lon: Double
    ) async throws -> AddressResolveResponse {
        let location = CLLocation(latitude: lat, longitude: lon)

        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                throw BackendError.message("Не удалось найти адрес")
            }

            request.preferredLocale = Locale(identifier: "ru_RU")

            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else {
                throw BackendError.message("Не удалось найти адрес")
            }

            let fullName = formattedAddress(from: mapItem)
            guard fullName.isEmpty == false else {
                throw BackendError.message("Не удалось найти адрес")
            }

            return AddressResolveResponse(
                fullName: fullName,
                lat: lat,
                lon: lon
            )
        }

        return try await resolveAddressWithLegacySystemGeocoder(
            location: location,
            lat: lat,
            lon: lon
        )
    }

    func formattedAddress(from mapItem: MKMapItem) -> String {
        var parts: [String] = []

        func appendPart(_ value: String?) {
            let trimmed = (value ?? "").trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard trimmed.isEmpty == false else {
                return
            }

            if parts.contains(trimmed) == false {
                parts.append(trimmed)
            }
        }

        if #available(iOS 26.0, *) {
            appendPart(
                mapItem.addressRepresentations?.fullAddress(
                    includingRegion: false,
                    singleLine: true
                )
            )
            appendPart(mapItem.address?.shortAddress)
            appendPart(mapItem.address?.fullAddress)
            appendPart(mapItem.name)
            appendPart(mapItem.addressRepresentations?.cityWithContext)
        } else {
            appendPart(mapItem.name)
        }

        return parts.joined(separator: ", ")
    }

    @available(iOS, introduced: 13.0, deprecated: 26.0)
    func resolveAddressWithLegacySystemGeocoder(
        location: CLLocation,
        lat: Double,
        lon: Double
    ) async throws -> AddressResolveResponse {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: "ru_RU")
        )

        guard let placemark = placemarks.first else {
            throw BackendError.message("Не удалось найти адрес")
        }

        let fullName = formattedLegacyAddress(from: placemark)
        guard fullName.isEmpty == false else {
            throw BackendError.message("Не удалось найти адрес")
        }

        return AddressResolveResponse(
            fullName: fullName,
            lat: lat,
            lon: lon
        )
    }

    @available(iOS, introduced: 13.0, deprecated: 26.0)
    func formattedLegacyAddress(from placemark: CLPlacemark) -> String {
        var parts: [String] = []

        func appendPart(_ value: String?) {
            let trimmed = (value ?? "").trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard trimmed.isEmpty == false else {
                return
            }

            if parts.contains(trimmed) == false {
                parts.append(trimmed)
            }
        }

        appendPart(placemark.name)

        let streetPart = [placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: ", ")
        appendPart(streetPart)
        appendPart(placemark.locality)

        return parts.joined(separator: ", ")
    }
}
