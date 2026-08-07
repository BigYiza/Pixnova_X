import CryptoKit
import Foundation

final class VideoCache {
    static let shared = VideoCache()

    typealias Completion = (URL?) -> Void

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private let maintenanceQueue = DispatchQueue(label: "com.ipxavno.home-video-cache.maintenance")
    private let maximumCacheSize: Int64 = 300 * 1_024 * 1_024
    private let cacheDirectory: URL
    private let session: URLSession
    private var callbacks: [URL: [UUID: Completion]] = [:]
    private var tasks: [URL: URLSessionDownloadTask] = [:]

    private init() {
        let root = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = root.appendingPathComponent("HomeVideos", isDirectory: true)
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 3
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func cachedURL(for remoteURL: URL) -> URL? {
        let localURL = destinationURL(for: remoteURL)
        guard
            fileManager.fileExists(atPath: localURL.path),
            let values = try? localURL.resourceValues(forKeys: [.fileSizeKey]),
            (values.fileSize ?? 0) > 0
        else {
            return nil
        }

        var accessValues = URLResourceValues()
        accessValues.contentAccessDate = Date()
        var mutableURL = localURL
        try? mutableURL.setResourceValues(accessValues)
        return localURL
    }

    func fetch(_ remoteURL: URL, completion: @escaping Completion) {
        if remoteURL.isFileURL {
            DispatchQueue.main.async {
                completion(remoteURL)
            }
            return
        }

        guard isCacheable(remoteURL) else {
            DispatchQueue.main.async {
                completion(remoteURL.pathExtension.lowercased() == "m3u8" ? remoteURL : nil)
            }
            return
        }

        if let localURL = cachedURL(for: remoteURL) {
            DispatchQueue.main.async {
                completion(localURL)
            }
            return
        }

        let callbackID = UUID()
        lock.lock()
        if callbacks[remoteURL] != nil {
            callbacks[remoteURL]?[callbackID] = completion
            lock.unlock()
            return
        }
        if let localURL = cachedURL(for: remoteURL) {
            lock.unlock()
            DispatchQueue.main.async {
                completion(localURL)
            }
            return
        }
        callbacks[remoteURL] = [callbackID: completion]
        lock.unlock()

        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 60

        let task = session.downloadTask(with: request) { [weak self] temporaryURL, response, error in
            guard let self else { return }
            let localURL = self.persistDownload(
                temporaryURL: temporaryURL,
                response: response,
                error: error,
                remoteURL: remoteURL
            )
            self.finish(remoteURL: remoteURL, localURL: localURL)
        }

        lock.lock()
        tasks[remoteURL] = task
        lock.unlock()
        task.resume()
    }

    func playbackURL(for remoteURL: URL, cacheIfMissing: Bool = true) -> URL {
        guard !remoteURL.isFileURL else { return remoteURL }
        if let localURL = cachedURL(for: remoteURL) {
            return localURL
        }
        if cacheIfMissing, isCacheable(remoteURL) {
            fetch(remoteURL) { _ in }
        }
        return remoteURL
    }

    func removeCachedVideo(for remoteURL: URL) {
        try? fileManager.removeItem(at: destinationURL(for: remoteURL))
    }

    private func persistDownload(
        temporaryURL: URL?,
        response: URLResponse?,
        error: Error?,
        remoteURL: URL
    ) -> URL? {
        guard
            error == nil,
            let temporaryURL,
            let response = response as? HTTPURLResponse,
            (200..<300).contains(response.statusCode),
            let values = try? temporaryURL.resourceValues(forKeys: [.fileSizeKey]),
            (values.fileSize ?? 0) > 0
        else {
            return nil
        }

        let destinationURL = destinationURL(for: remoteURL)
        if fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        let stagingURL = cacheDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("download")
        do {
            try fileManager.moveItem(at: temporaryURL, to: stagingURL)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: stagingURL)
            } else {
                try fileManager.moveItem(at: stagingURL, to: destinationURL)
            }
            schedulePruning()
            return destinationURL
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            return nil
        }
    }

    private func finish(remoteURL: URL, localURL: URL?) {
        lock.lock()
        let completions = callbacks.removeValue(forKey: remoteURL)?.values.map { $0 } ?? []
        tasks.removeValue(forKey: remoteURL)
        lock.unlock()

        DispatchQueue.main.async {
            completions.forEach { $0(localURL) }
        }
    }

    private func destinationURL(for remoteURL: URL) -> URL {
        let data = Data(remoteURL.absoluteString.utf8)
        let digest = Insecure.MD5.hash(data: data)
        let key = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(key).appendingPathExtension("mp4")
    }

    private func isCacheable(_ remoteURL: URL) -> Bool {
        guard let scheme = remoteURL.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }
        return remoteURL.pathExtension.lowercased() != "m3u8"
    }

    private func schedulePruning() {
        maintenanceQueue.async { [weak self] in
            self?.pruneIfNeeded()
        }
    }

    private func pruneIfNeeded() {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentAccessDateKey, .contentModificationDateKey]
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let cachedFiles = files.compactMap { url -> (url: URL, size: Int64, date: Date)? in
            guard
                url.pathExtension == "mp4",
                let values = try? url.resourceValues(forKeys: keys),
                values.isRegularFile == true
            else {
                return nil
            }
            return (
                url,
                Int64(values.fileSize ?? 0),
                values.contentAccessDate ?? values.contentModificationDate ?? .distantPast
            )
        }

        var totalSize = cachedFiles.reduce(Int64(0)) { $0 + $1.size }
        guard totalSize > maximumCacheSize else { return }

        for file in cachedFiles.sorted(by: { $0.date < $1.date }) where totalSize > maximumCacheSize {
            do {
                try fileManager.removeItem(at: file.url)
                totalSize -= file.size
            } catch {
                continue
            }
        }
    }
}
