// свифт подгототавливает запрос, отправляет на бекенд и потом принимает его

import Foundation
import CoreLocation
import MapKit

final class BackendInitalizer {
    let baseURL = "http://localhost:8080"
    let acceptableNearestPointDistanceMeters: Double = 18
    static let coordinateAliasLock = NSLock()
    static var coordinateAliases: [String: AddressResolveResponse] = [:]
    static var addressByCoordinate: [String: AddressResolveResponse] = [:]
    static var nearestByCoordinate: [String: NearestPointResponse] = [:]
    static var addressTasks: [String: Task<AddressResolveResponse, Error>] = [:]
    static var nearestTasks: [String: Task<NearestPointResponse, Error>] = [:]

    func buildRoute(
        startLat: Double,
        startLon: Double,
        endLat: Double,
        endLon: Double
    ) async throws -> RouteResponse {
        guard let url = URL(string: "\(baseURL)/route") else { // аналог хендлера в бекенде
            throw URLError(.badURL)
        }

        let body_req = RouteRequest(
            latSt: startLat,
            lonSt: startLon,
            latEnd: endLat,
            lonEnd: endLon
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body_req)

        let data = try await perform(request)

        // то что пришло с бекенда
        let result = try JSONDecoder().decode(RouteResponse.self, from: data)
        return result
    }

    func buildRouteByAddress(
        startQuery: String,
        endQuery: String
    ) async throws -> RouteByAddressResponse {
        let trimmedStart = startQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnd = endQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedStart.isEmpty == false, trimmedEnd.isEmpty == false {
            let startAlias = rememberedCoordinateAlias(for: trimmedStart)
            let endAlias = rememberedCoordinateAlias(for: trimmedEnd)

            if startAlias != nil || endAlias != nil {
                let startResolved = try await resolvedAddressForRoute(
                    query: trimmedStart,
                    alias: startAlias
                )
                let endResolved = try await resolvedAddressForRoute(
                    query: trimmedEnd,
                    alias: endAlias
                )

                return try await buildRouteByResolvedAddresses(
                    start: startResolved,
                    end: endResolved
                )
            }
        }

        do {
            return try await buildRouteByGeocode(
                startQuery: startQuery,
                endQuery: endQuery
            )
        } catch let primaryError {
            do {
                return try await buildRouteByLegacyAddress(
                    startQuery: startQuery,
                    endQuery: endQuery
                )
            } catch let fallbackError {
                if case BackendError.message = fallbackError {
                    throw fallbackError
                }

                throw primaryError
            }
        }
    }

    func resolveAddress(
        query: String
    ) async throws -> AddressResolveResponse {
        guard let url = URL(string: "\(baseURL)/geocode") else {
            throw URLError(.badURL)
        }

        let bodyRequest = AddressResolveRequest(query: query)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(bodyRequest)

        let data = try await perform(request)
        let response = try JSONDecoder().decode(AddressResolveResponse.self, from: data)
        rememberCoordinateAlias(response)
        return response
    }

    func resolveAddressByCoordinate(
        lat: Double,
        lon: Double
    ) async throws -> AddressResolveResponse {
        let cacheKey = Self.coordinateCacheKey(
            lat: lat,
            lon: lon,
            decimals: 4
        )

        if let cached = cachedAddressByCoordinate(for: cacheKey) {
            rememberCoordinateAlias(cached)
            return cached
        }

        if let nearbyCached = cachedNearbyAddress(lat: lat, lon: lon) {
            rememberCoordinateAlias(nearbyCached)
            return nearbyCached
        }

        if let task = inflightAddressTask(for: cacheKey) {
            let response = try await task.value
            rememberCoordinateAlias(response)
            return response
        }

        cancelOtherAddressTasks(except: cacheKey)

        guard let url = URL(string: "\(baseURL)/reverse-geocode") else {
            throw URLError(.badURL)
        }

        let task = Task<AddressResolveResponse, Error> {
            if let response = try? await self.resolveAddressWithSystemGeocoder(
                lat: lat,
                lon: lon
            ) {
                return response
            }

            if let nearest = try? await self.findNearestPoint(lat: lat, lon: lon),
               let response = try? await self.resolveAddressWithSystemGeocoder(
                   lat: nearest.point.lat,
                   lon: nearest.point.lon
               ) {
                return response
            }

            return try await self.requestAddressByCoordinate(
                url: url,
                lat: lat,
                lon: lon
            )
        }

        storeInflightAddressTask(task, for: cacheKey)

        do {
            let response = try await task.value
            storeAddressByCoordinate(response, for: cacheKey)
            rememberCoordinateAlias(response)
            clearInflightAddressTask(for: cacheKey)
            return response
        } catch {
            clearInflightAddressTask(for: cacheKey)

            if error is CancellationError {
                throw error
            }

            do {
                let nearest = try await findNearestPoint(lat: lat, lon: lon)
                let snappedCoordinate = nearest.point
                let snappedCacheKey = Self.coordinateCacheKey(
                    lat: snappedCoordinate.lat,
                    lon: snappedCoordinate.lon,
                    decimals: 4
                )

                if let cached = cachedAddressByCoordinate(for: snappedCacheKey) {
                    rememberCoordinateAlias(cached)
                    return cached
                }

                let snappedResponse = try await requestAddressByCoordinate(
                    url: url,
                    lat: snappedCoordinate.lat,
                    lon: snappedCoordinate.lon
                )

                storeAddressByCoordinate(snappedResponse, for: snappedCacheKey)
                rememberCoordinateAlias(snappedResponse)
                return snappedResponse
            } catch {
                throw error
            }
        }
    }

    func findNearestPoint(
        lat: Double,
        lon: Double
    ) async throws -> NearestPointResponse {
        let cacheKey = Self.coordinateCacheKey(
            lat: lat,
            lon: lon,
            decimals: 5
        )

        if let cached = cachedNearestPoint(for: cacheKey) {
            return cached
        }

        if let task = inflightNearestTask(for: cacheKey) {
            return try await task.value
        }

        guard let url = URL(string: "\(baseURL)/nearest") else {
            throw URLError(.badURL)
        }

        let bodyRequest = CoordinateResolveRequest(lat: lat, lon: lon)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(bodyRequest)
        request.timeoutInterval = 6

        let task = Task<NearestPointResponse, Error> {
            var directError: Error?
            var bestCandidate: (response: NearestPointResponse, distance: Double)?

            do {
                let directResponse = try await self.requestNearestPoint(request)
                let directDistance = Self.distanceMeters(
                    lat1: lat,
                    lon1: lon,
                    lat2: directResponse.point.lat,
                    lon2: directResponse.point.lon
                )

                bestCandidate = (directResponse, directDistance)

                if directDistance <= self.acceptableNearestPointDistanceMeters {
                    return directResponse
                }
            } catch {
                if error is CancellationError {
                    throw error
                }

                directError = error
            }

            for coordinate in Self.nearestProbeCoordinates(
                lat: lat,
                lon: lon
            ) {
                if let response = try? await self.requestNearestPoint(
                    coordinate.lat,
                    coordinate.lon
                ) {
                    let distance = Self.distanceMeters(
                        lat1: lat,
                        lon1: lon,
                        lat2: response.point.lat,
                        lon2: response.point.lon
                    )

                    if let currentBest = bestCandidate,
                       currentBest.distance <= distance {
                        continue
                    }

                    bestCandidate = (response, distance)
                }
            }

            if let bestCandidate {
                return bestCandidate.response
            }

            if let directError {
                throw directError
            }

            throw BackendError.message("Пешеходная точка не найдена рядом")
        }

        storeInflightNearestTask(task, for: cacheKey)

        do {
            let response = try await task.value
            storeNearestPoint(response, for: cacheKey)
            clearInflightNearestTask(for: cacheKey)
            return response
        } catch {
            clearInflightNearestTask(for: cacheKey)
            throw error
        }
    }
}

enum BackendError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text):
            return text
        }
    }
}
