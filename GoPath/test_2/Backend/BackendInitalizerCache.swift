import Foundation
import CoreLocation
import MapKit

extension BackendInitalizer {
    func rememberCoordinateAlias(_ response: AddressResolveResponse) {
        let keys = Self.coordinateAliasKeys(for: response.fullName)

        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }

        for key in keys {
            Self.coordinateAliases[key] = response
        }

        Self.addressByCoordinate[Self.coordinateCacheKey(
            lat: response.lat,
            lon: response.lon,
            decimals: 4
        )] = response
    }

    func rememberedCoordinateAlias(for query: String) -> AddressResolveResponse? {
        let key = Self.normalizedCoordinateAliasKey(query)

        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }

        return Self.coordinateAliases[key]
    }

    func cachedAddressByCoordinate(for key: String) -> AddressResolveResponse? {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        return Self.addressByCoordinate[key]
    }

    func storeAddressByCoordinate(_ response: AddressResolveResponse, for key: String) {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        Self.addressByCoordinate[key] = response
    }

    func cachedNearestPoint(for key: String) -> NearestPointResponse? {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        return Self.nearestByCoordinate[key]
    }

    func storeNearestPoint(_ response: NearestPointResponse, for key: String) {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        Self.nearestByCoordinate[key] = response
    }

    func inflightAddressTask(for key: String) -> Task<AddressResolveResponse, Error>? {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        return Self.addressTasks[key]
    }

    func storeInflightAddressTask(_ task: Task<AddressResolveResponse, Error>, for key: String) {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        Self.addressTasks[key] = task
    }

    func clearInflightAddressTask(for key: String) {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        Self.addressTasks[key] = nil
    }

    func cancelOtherAddressTasks(except key: String) {
        var tasksToCancel: [Task<AddressResolveResponse, Error>] = []

        Self.coordinateAliasLock.lock()
        for (taskKey, task) in Self.addressTasks where taskKey != key {
            tasksToCancel.append(task)
            Self.addressTasks[taskKey] = nil
        }
        Self.coordinateAliasLock.unlock()

        for task in tasksToCancel {
            task.cancel()
        }
    }

    func inflightNearestTask(for key: String) -> Task<NearestPointResponse, Error>? {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        return Self.nearestTasks[key]
    }

    func storeInflightNearestTask(_ task: Task<NearestPointResponse, Error>, for key: String) {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        Self.nearestTasks[key] = task
    }

    func clearInflightNearestTask(for key: String) {
        Self.coordinateAliasLock.lock()
        defer { Self.coordinateAliasLock.unlock() }
        Self.nearestTasks[key] = nil
    }

    static func coordinateAliasKeys(for text: String) -> [String] {
        let normalized = normalizedCoordinateAliasKey(text)
        return normalized.isEmpty ? [] : [normalized]
    }

    static func normalizedCoordinateAliasKey(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    static func coordinateCacheKey(
        lat: Double,
        lon: Double,
        decimals: Int
    ) -> String {
        let format = "%.\(decimals)f"
        let roundedLat = String(format: format, lat)
        let roundedLon = String(format: format, lon)
        return "\(roundedLat)|\(roundedLon)"
    }
}
