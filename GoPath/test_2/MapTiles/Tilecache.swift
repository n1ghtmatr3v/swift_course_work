import Foundation
import UIKit

final class Tilecache
{
    private let memoryCache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let baseDirectoryURL: URL

    init(folderName: String = "osm_tiles", memoryCountLimit: Int = 500)
    {
        memoryCache.countLimit = memoryCountLimit

        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        baseDirectoryURL = cachesDirectory.appendingPathComponent(folderName, isDirectory: true)

        if !fileManager.fileExists(atPath: baseDirectoryURL.path)
        {
            try? fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func makeScale(_ scale: CGFloat) -> Int
    {
        return max(1, Int(scale.rounded()))
    }

    private func makeKey(z: Int, x: Int, y: Int, scale: CGFloat) -> NSString
    {
        let safeScale = makeScale(scale)
        return "\(z)/\(x)/\(y)@\(safeScale)x" as NSString
    }

    private func makeFileURL(z: Int, x: Int, y: Int, scale: CGFloat) -> URL
    {
        let safeScale = makeScale(scale)

        return baseDirectoryURL
            .appendingPathComponent(String(z), isDirectory: true)
            .appendingPathComponent(String(x), isDirectory: true)
            .appendingPathComponent("\(y)@\(safeScale)x.png", isDirectory: false)
    }

    func cacheData(z: Int, x: Int, y: Int, scale: CGFloat) -> Data?
    {
        let key = makeKey(z: z, x: x, y: y, scale: scale)

        if let data = memoryCache.object(forKey: key)
        {
            //print("MEMORY HIT z=\(z) x=\(x) y=\(y) scale=\(scale)")
            return data as Data
        }

        let fileURL = makeFileURL(z: z, x: x, y: y, scale: scale)

        guard fileManager.fileExists(atPath: fileURL.path) else
        {
            //print("CACHE MISS z=\(z) x=\(x) y=\(y) scale=\(scale)")
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL) else
        {
            //print("DISK READ FAIL z=\(z) x=\(x) y=\(y) scale=\(scale)")
            return nil
        }

        //print("DISK HIT z=\(z) x=\(x) y=\(y) scale=\(scale)")
        memoryCache.setObject(data as NSData, forKey: key)
        return data
    }

    func saveTile(data: Data, z: Int, x: Int, y: Int, scale: CGFloat)
    {
        let key = makeKey(z: z, x: x, y: y, scale: scale)
        memoryCache.setObject(data as NSData, forKey: key)

        let fileURL = makeFileURL(z: z, x: x, y: y, scale: scale)
        let folderURL = fileURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: folderURL.path)
        {
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        try? data.write(to: fileURL, options: .atomic)
        //print("SAVE TILE z=\(z) x=\(x) y=\(y) scale=\(scale)")
    }

    func removeAll()
    {
        memoryCache.removeAllObjects()

        if fileManager.fileExists(atPath: baseDirectoryURL.path)
        {
            try? fileManager.removeItem(at: baseDirectoryURL)
            try? fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        }

        //print("CACHE CLEARED")
    }
}
