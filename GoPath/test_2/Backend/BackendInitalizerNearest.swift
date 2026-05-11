import Foundation
import CoreLocation
import MapKit

extension BackendInitalizer {
    func requestNearestPoint(_ request: URLRequest) async throws -> NearestPointResponse {
        let data = try await perform(request)
        return try JSONDecoder().decode(NearestPointResponse.self, from: data)
    }

    func requestNearestPoint(
        _ lat: Double,
        _ lon: Double
    ) async throws -> NearestPointResponse {
        guard let url = URL(string: "\(baseURL)/nearest") else {
            throw URLError(.badURL)
        }

        let bodyRequest = CoordinateResolveRequest(lat: lat, lon: lon)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(bodyRequest)
        request.timeoutInterval = 6

        return try await requestNearestPoint(request)
    }

    func cachedNearbyAddress(
        lat: Double,
        lon: Double,
        maxDistanceMeters: Double = 22
    ) -> AddressResolveResponse? {
        Self.coordinateAliasLock.lock()
        let values = Array(Self.addressByCoordinate.values)
        Self.coordinateAliasLock.unlock()

        var nearest: (response: AddressResolveResponse, distance: Double)?

        for response in values {
            let distance = Self.distanceMeters(
                lat1: lat,
                lon1: lon,
                lat2: response.lat,
                lon2: response.lon
            )

            guard distance <= maxDistanceMeters else {
                continue
            }

            if let nearest, nearest.distance <= distance {
                continue
            }

            nearest = (response, distance)
        }

        return nearest?.response
    }

    func cachedNearbyNearestPoint(
        lat: Double,
        lon: Double,
        maxDistanceMeters: Double = 10
    ) -> NearestPointResponse? {
        Self.coordinateAliasLock.lock()
        let values = Array(Self.nearestByCoordinate.values)
        Self.coordinateAliasLock.unlock()

        var nearest: (response: NearestPointResponse, distance: Double)?

        for response in values {
            let distance = Self.distanceMeters(
                lat1: lat,
                lon1: lon,
                lat2: response.point.lat,
                lon2: response.point.lon
            )

            guard distance <= maxDistanceMeters else {
                continue
            }

            if let nearest, nearest.distance <= distance {
                continue
            }

            nearest = (response, distance)
        }

        return nearest?.response
    }

    static func distanceMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let latMeters = (lat2 - lat1) * 111_320
        let avgLatRadians = ((lat1 + lat2) * 0.5) * .pi / 180
        let lonMeters = (lon2 - lon1) * 111_320 * cos(avgLatRadians)
        return hypot(latMeters, lonMeters)
    }

    static func nearestProbeCoordinates(
        lat: Double,
        lon: Double
    ) -> [(lat: Double, lon: Double)] {
        var coordinates: [(lat: Double, lon: Double)] = []
        let radii: [Double] = [3, 6, 10, 16, 24, 36, 52]
        let directions: [(Double, Double)] = [
            (1, 0), (-1, 0), (0, 1), (0, -1),
            (1, 1), (1, -1), (-1, 1), (-1, -1)
        ]

        for radius in radii {
            for direction in directions {
                coordinates.append(
                    offsetCoordinate(
                        lat: lat,
                        lon: lon,
                        metersX: radius * direction.0,
                        metersY: radius * direction.1
                    )
                )
            }
        }

        return coordinates
    }

    static func offsetCoordinate(
        lat: Double,
        lon: Double,
        metersX: Double,
        metersY: Double
    ) -> (lat: Double, lon: Double) {
        let latOffset = metersY / 111_320
        let lonScale = max(cos(lat * .pi / 180), 0.000001)
        let lonOffset = metersX / (111_320 * lonScale)

        return (
            lat: lat + latOffset,
            lon: lon + lonOffset
        )
    }
}
