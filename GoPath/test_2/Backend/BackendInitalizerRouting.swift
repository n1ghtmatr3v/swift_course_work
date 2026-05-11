import Foundation
import CoreLocation
import MapKit

extension BackendInitalizer {
    func buildRouteByGeocode(
        startQuery: String,
        endQuery: String
    ) async throws -> RouteByAddressResponse {
        guard let url = URL(string: "\(baseURL)/geocode") else {
            throw URLError(.badURL)
        }

        let bodyRequest = GeocodeRouteRequest(
            startAddress: startQuery,
            endAddress: endQuery
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(bodyRequest)

        let data = try await perform(request)
        let response = try JSONDecoder().decode(RouteByAddressResponse.self, from: data)
        rememberCoordinateAlias(
            AddressResolveResponse(
                fullName: response.startFullName,
                lat: response.startLat,
                lon: response.startLon
            )
        )
        rememberCoordinateAlias(
            AddressResolveResponse(
                fullName: response.endFullName,
                lat: response.endLat,
                lon: response.endLon
            )
        )
        return response
    }

    func requestAddressByCoordinate(
        url: URL,
        lat: Double,
        lon: Double
    ) async throws -> AddressResolveResponse {
        let bodyRequest = CoordinateResolveRequest(lat: lat, lon: lon)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(bodyRequest)
        request.timeoutInterval = 9

        let data = try await perform(request)
        return try JSONDecoder().decode(AddressResolveResponse.self, from: data)
    }

    func buildRouteByLegacyAddress(
        startQuery: String,
        endQuery: String
    ) async throws -> RouteByAddressResponse {
        guard let url = URL(string: "\(baseURL)/route-by-address") else {
            throw URLError(.badURL)
        }

        let bodyRequest = LegacyRouteByAddressRequest(
            startQuery: startQuery,
            endQuery: endQuery
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(bodyRequest)

        let data = try await perform(request)
        let response = try JSONDecoder().decode(RouteByAddressResponse.self, from: data)
        rememberCoordinateAlias(
            AddressResolveResponse(
                fullName: response.startFullName,
                lat: response.startLat,
                lon: response.startLon
            )
        )
        rememberCoordinateAlias(
            AddressResolveResponse(
                fullName: response.endFullName,
                lat: response.endLat,
                lon: response.endLon
            )
        )
        return response
    }

    func buildRouteByResolvedAddresses(
        start: AddressResolveResponse,
        end: AddressResolveResponse
    ) async throws -> RouteByAddressResponse {
        let routeResponse = try await buildRoute(
            startLat: start.lat,
            startLon: start.lon,
            endLat: end.lat,
            endLon: end.lon
        )

        return RouteByAddressResponse(
            startFullName: start.fullName,
            endFullName: end.fullName,
            startLat: start.lat,
            startLon: start.lon,
            endLat: end.lat,
            endLon: end.lon,
            route: routeResponse.route,
            routeLengthMeters: routeResponse.routeLengthMeters,
            routeDurationSeconds: routeResponse.routeDurationSeconds
        )
    }

    func resolvedAddressForRoute(
        query: String,
        alias: AddressResolveResponse?
    ) async throws -> AddressResolveResponse {
        if let alias {
            rememberCoordinateAlias(alias)
            return alias
        }

        return try await resolveAddress(query: query)
    }

    func perform(_ request: URLRequest) async throws -> Data {
        var timedRequest = request
        if timedRequest.timeoutInterval <= 0 {
            timedRequest.timeoutInterval = 8
        }

        let (data, response) = try await URLSession.shared.data(for: timedRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let backendMessage = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let backendMessage, backendMessage.isEmpty == false {
                throw BackendError.message(backendMessage)
            }

            throw URLError(.badServerResponse)
        }

        return data
    }
}
