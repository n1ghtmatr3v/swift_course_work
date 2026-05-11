import Foundation
import CoreLocation

struct RouteRequest: Codable {
    let latSt: Double
    let lonSt: Double
    let latEnd: Double
    let lonEnd: Double
}

struct RoutePoint: Codable, Identifiable {
    let lat: Double
    let lon: Double
    
    var id: String {
        "\(lat)_\(lon)"
    }
}

struct RouteResponse: Decodable {
    let route: [RoutePoint]
    let routeLengthMeters: Double
    let routeDurationSeconds: Double

    enum CodingKeys: String, CodingKey {
        case route
        case routeLengthMeters = "route_length_meters"
        case legacyRouteLengthMeters = "length_Meters"
        case snakeRouteLengthMeters = "length_meters"
        case routeDurationSeconds = "route_duration_seconds"
        case durationSeconds = "duration_seconds"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        route = try container.decode([RoutePoint].self, forKey: .route)
        routeLengthMeters = try container.decodeIfPresent(Double.self, forKey: .routeLengthMeters)
            ?? container.decodeIfPresent(Double.self, forKey: .legacyRouteLengthMeters)
            ?? container.decodeIfPresent(Double.self, forKey: .snakeRouteLengthMeters)
            ?? 0
        routeDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .routeDurationSeconds)
            ?? container.decodeIfPresent(Double.self, forKey: .durationSeconds)
            ?? Self.estimateWalkingDurationSeconds(for: routeLengthMeters)
    }

    private static func estimateWalkingDurationSeconds(for routeLengthMeters: Double) -> Double
    {
        guard routeLengthMeters > 0 else {
            return 0
        }

        return (routeLengthMeters / 1.4).rounded(.up)
    }
}

struct GeocodeRouteRequest: Encodable {
    let startAddress: String
    let endAddress: String

    enum CodingKeys: String, CodingKey {
        case startAddress = "start_address"
        case endAddress = "end_address"
        case legacyStartAdress = "start_adress"
        case legacyEndAdress = "end_adress"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startAddress, forKey: .startAddress)
        try container.encode(endAddress, forKey: .endAddress)
        try container.encode(startAddress, forKey: .legacyStartAdress)
        try container.encode(endAddress, forKey: .legacyEndAdress)
    }
}

struct AddressResolveRequest: Encodable {
    let query: String

    enum CodingKeys: String, CodingKey {
        case query
        case adress
        case address
        case startAddress = "start_address"
        case endAddress = "end_address"
        case legacyStartAdress = "start_adress"
        case legacyEndAdress = "end_adress"
    }

    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(query, forKey: .adress)
        try container.encode(query, forKey: .address)
        try container.encode(query, forKey: .startAddress)
        try container.encode(query, forKey: .endAddress)
        try container.encode(query, forKey: .legacyStartAdress)
        try container.encode(query, forKey: .legacyEndAdress)
    }
}

struct CoordinateResolveRequest: Encodable {
    let lat: Double
    let lon: Double
}

struct AddressResolveResponse: Decodable {
    let fullName: String
    let lat: Double
    let lon: Double

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case legacyFullAddress = "full_address"
        case legacyFullAdress = "full_adress"
        case startFullName = "start_full_name"
        case startFullAddress = "start_full_address"
        case startFullAdress = "start_full_adress"
        case lat
        case lon
        case latSt
        case lonSt
        case startLat = "start_lat"
        case startLon = "start_lon"
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
            ?? container.decodeIfPresent(String.self, forKey: .legacyFullAddress)
            ?? container.decodeIfPresent(String.self, forKey: .legacyFullAdress)
            ?? container.decodeIfPresent(String.self, forKey: .startFullName)
            ?? container.decodeIfPresent(String.self, forKey: .startFullAddress)
            ?? container.decode(String.self, forKey: .startFullAdress)

        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
            ?? container.decodeIfPresent(Double.self, forKey: .latSt)
            ?? container.decode(Double.self, forKey: .startLat)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
            ?? container.decodeIfPresent(Double.self, forKey: .lonSt)
            ?? container.decode(Double.self, forKey: .startLon)
    }

    init(
        fullName: String,
        lat: Double,
        lon: Double
    )
    {
        self.fullName = fullName
        self.lat = lat
        self.lon = lon
    }
}

struct NearestPointResponse: Decodable {
    let vertex: UInt32
    let point: RoutePoint
}

struct LegacyRouteByAddressRequest: Encodable {
    let startQuery: String
    let endQuery: String

    enum CodingKeys: String, CodingKey {
        case startQuery = "start_query"
        case endQuery = "end_query"
    }
}

struct RouteByAddressResponse: Decodable {
    let startFullName: String
    let endFullName: String
    let startLat: Double
    let startLon: Double
    let endLat: Double
    let endLon: Double
    let route: [RoutePoint]
    let routeLengthMeters: Double
    let routeDurationSeconds: Double

    enum CodingKeys: String, CodingKey {
        case startFullAddress = "start_full_address"
        case endFullAddress = "end_full_address"
        case startFullAdress = "start_full_adress"
        case endFullAdress = "end_full_adress"
        case startFullName = "start_full_name"
        case endFullName = "end_full_name"
        case legacyStartAddress = "start_address"
        case legacyEndAddress = "end_address"
        case latSt
        case lonSt
        case latEnd
        case lonEnd
        case startLat = "start_lat"
        case startLon = "start_lon"
        case endLat = "end_lat"
        case endLon = "end_lon"
        case route
        case routeLengthMeters = "route_length_meters"
        case legacyRouteLengthMeters = "length_Meters"
        case legacyLengthMeters = "length_meters"
        case routeDurationSeconds = "route_duration_seconds"
        case durationSeconds = "duration_seconds"
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        startFullName = try container.decodeIfPresent(String.self, forKey: .startFullAddress)
            ?? container.decodeIfPresent(String.self, forKey: .startFullAdress)
            ?? container.decodeIfPresent(String.self, forKey: .startFullName)
            ?? container.decode(String.self, forKey: .legacyStartAddress)
        endFullName = try container.decodeIfPresent(String.self, forKey: .endFullAddress)
            ?? container.decodeIfPresent(String.self, forKey: .endFullAdress)
            ?? container.decodeIfPresent(String.self, forKey: .endFullName)
            ?? container.decode(String.self, forKey: .legacyEndAddress)
        startLat = try container.decodeIfPresent(Double.self, forKey: .latSt)
            ?? container.decode(Double.self, forKey: .startLat)
        startLon = try container.decodeIfPresent(Double.self, forKey: .lonSt)
            ?? container.decode(Double.self, forKey: .startLon)
        endLat = try container.decodeIfPresent(Double.self, forKey: .latEnd)
            ?? container.decode(Double.self, forKey: .endLat)
        endLon = try container.decodeIfPresent(Double.self, forKey: .lonEnd)
            ?? container.decode(Double.self, forKey: .endLon)
        route = try container.decode([RoutePoint].self, forKey: .route)
        routeLengthMeters = try container.decodeIfPresent(Double.self, forKey: .routeLengthMeters)
            ?? container.decodeIfPresent(Double.self, forKey: .legacyRouteLengthMeters)
            ?? container.decodeIfPresent(Double.self, forKey: .legacyLengthMeters)
            ?? Self.computeRouteLength(for: route)
        routeDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .routeDurationSeconds)
            ?? container.decodeIfPresent(Double.self, forKey: .durationSeconds)
            ?? Self.estimateWalkingDurationSeconds(for: routeLengthMeters)
    }

    init(
        startFullName: String,
        endFullName: String,
        startLat: Double,
        startLon: Double,
        endLat: Double,
        endLon: Double,
        route: [RoutePoint],
        routeLengthMeters: Double,
        routeDurationSeconds: Double? = nil
    )
    {
        self.startFullName = startFullName
        self.endFullName = endFullName
        self.startLat = startLat
        self.startLon = startLon
        self.endLat = endLat
        self.endLon = endLon
        self.route = route
        self.routeLengthMeters = routeLengthMeters
        self.routeDurationSeconds = routeDurationSeconds
            ?? Self.estimateWalkingDurationSeconds(for: routeLengthMeters)
    }

    private static func computeRouteLength(for route: [RoutePoint]) -> Double
    {
        guard route.count > 1 else {
            return 0
        }

        var distance: CLLocationDistance = 0

        for index in 1..<route.count {
            let previous = CLLocation(
                latitude: route[index - 1].lat,
                longitude: route[index - 1].lon
            )
            let current = CLLocation(
                latitude: route[index].lat,
                longitude: route[index].lon
            )

            distance += previous.distance(from: current)
        }

        return distance
    }

    private static func estimateWalkingDurationSeconds(for routeLengthMeters: Double) -> Double
    {
        guard routeLengthMeters > 0 else {
            return 0
        }

        return (routeLengthMeters / 1.4).rounded(.up)
    }
}
