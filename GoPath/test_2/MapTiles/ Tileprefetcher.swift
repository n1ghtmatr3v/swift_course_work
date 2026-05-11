import Foundation
import MapKit
import UIKit

final class TilePrefetcher {
    private let tileCache: Tilecache
    private let urlTemplate: String
    private let maxTileZoom: Int
    private let downloadSession: URLSession
    private var loadingTileKeys = Set<String>()
    private let loadingQueue = DispatchQueue(label: "TilePrefetcher.sync.queue")
    
    // у OSM макс зум 19, поэтому инициализируем baseMax 19
    // дальше сделаем растягивание родительского тайла для более глубокого зума
    init(tileCache: Tilecache, urlTemplate: String, baseMaxZ: Int = 19) {
        self.tileCache = tileCache
        self.urlTemplate = urlTemplate
        self.maxTileZoom = baseMaxZ
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 12
        self.downloadSession = URLSession(configuration: configuration)
    }

    // подргружаем тайлы которые сейчас в видимой области и их соседей
    func prefetchVisibleAndNeighbors(for mapView: MKMapView, bufferTiles: Int = 1) {
        let zoomLevel = currentZoomLevel(for: mapView)
        let tileZoom = min(zoomLevel, maxTileZoom)
        let screenScale = mapView.contentScaleFactor

        let visibleRect = mapView.visibleMapRect

        let topLeftMapPoint = MKMapPoint(x: visibleRect.minX, y: visibleRect.minY)
        let topRightMapPoint = MKMapPoint(x: visibleRect.maxX, y: visibleRect.minY)
        let bottomLeftMapPoint = MKMapPoint(x: visibleRect.minX, y: visibleRect.maxY)
        let bottomRightMapPoint = MKMapPoint(x: visibleRect.maxX, y: visibleRect.maxY)

        let topLeft = topLeftMapPoint.coordinate
        let topRight = topRightMapPoint.coordinate
        let bottomLeft = bottomLeftMapPoint.coordinate
        let bottomRight = bottomRightMapPoint.coordinate

        let topLeftTile = tileXY(for: topLeft, zoom: tileZoom)
        let topRightTile = tileXY(for: topRight, zoom: tileZoom)
        let bottomLeftTile = tileXY(for: bottomLeft, zoom: tileZoom)
        let bottomRightTile = tileXY(for: bottomRight, zoom: tileZoom)

        var minX = min(topLeftTile.x, topRightTile.x, bottomLeftTile.x, bottomRightTile.x)
        var maxX = max(topLeftTile.x, topRightTile.x, bottomLeftTile.x, bottomRightTile.x)
        var minY = min(topLeftTile.y, topRightTile.y, bottomLeftTile.y, bottomRightTile.y)
        var maxY = max(topLeftTile.y, topRightTile.y, bottomLeftTile.y, bottomRightTile.y)

        minX -= bufferTiles
        maxX += bufferTiles
        minY -= bufferTiles
        maxY += bufferTiles
        
        let maxIndex = (1 << tileZoom) - 1

        minX = max(0, minX)
        maxX = min(maxIndex, maxX)
        minY = max(0, minY)
        maxY = min(maxIndex, maxY)

        guard minX <= maxX, minY <= maxY else {
            return
        }

        for x in minX...maxX {
            for y in minY...maxY {
                prefetchTile(z: tileZoom, x: x, y: y, scale: screenScale)
            }
        }
    }
    
    
    // предзагрузка тайлов (для оптимизации карты)
    private func prefetchTile(z: Int, x: Int, y: Int, scale: CGFloat) {
        if tileCache.cacheData(z: z, x: x, y: y, scale: scale) != nil {
            return
        }

        let roundedScale = max(1, Int(scale.rounded()))
        let loadingKey = "\(z)/\(x)/\(y)@\(roundedScale)x"

        let shouldStart: Bool = loadingQueue.sync {
            if loadingTileKeys.contains(loadingKey) {
                return false
            }

            loadingTileKeys.insert(loadingKey)
            return true
        }

        guard shouldStart else {
            return
        }

        guard let requestURL = makeURL(z: z, x: x, y: y) else {
            loadingQueue.async {
                self.loadingTileKeys.remove(loadingKey)
            }
            return
        }

        let dataTask = downloadSession.dataTask(with: requestURL) { [weak self] data, response, error in
            guard let self else {
                return
            }

            defer {
                self.loadingQueue.async {
                    self.loadingTileKeys.remove(loadingKey)
                }
            }

            guard
                let data,
                error == nil,
                let httpResponse = response as? HTTPURLResponse,
                200..<300 ~= httpResponse.statusCode
            else {
                return
            }

            self.tileCache.saveTile(data: data, z: z, x: x, y: y, scale: scale)
        }


        dataTask.resume()
    }

    private func makeURL(z: Int, x: Int, y: Int) -> URL? {
        let urlString = urlTemplate
            .replacingOccurrences(of: "{z}", with: String(z))
            .replacingOccurrences(of: "{x}", with: String(x))
            .replacingOccurrences(of: "{y}", with: String(y))

        return URL(string: urlString)
    }

    // считаем текущий уровень зума
    private func currentZoomLevel(for mapView: MKMapView) -> Int {
        let longitudeDelta = mapView.region.span.longitudeDelta
        let mapWidth = Double(mapView.bounds.size.width)

        guard longitudeDelta > 0, mapWidth > 0 else {
            return 0
        }

        let zoomScale = longitudeDelta * 256.0 / mapWidth
        let computedZoom = Int(log2(360.0 / zoomScale))

        return max(0, computedZoom)
    }

    private func tileXY(for coordinate: CLLocationCoordinate2D, zoom: Int) -> (x: Int, y: Int) {
        let latitude = min(max(coordinate.latitude, -85.05112878), 85.05112878)
        let longitude = coordinate.longitude

        let tileCount = Double(1 << zoom)
        let maxIndex = Int(tileCount) - 1

        let rawX = Int(floor((longitude + 180.0) / 360.0 * tileCount))

        let latitudeRadians = latitude * .pi / 180.0
        let rawY = Int(
            floor(
                (1.0 - log(tan(latitudeRadians) + 1.0 / cos(latitudeRadians)) / .pi) / 2.0 * tileCount
            )
        )

        let x = min(max(0, rawX), maxIndex)
        let y = min(max(0, rawY), maxIndex)

        return (x, y)
    }

}
