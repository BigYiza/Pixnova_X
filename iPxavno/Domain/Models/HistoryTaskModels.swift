import Foundation

enum HistoryTaskState: Equatable {
    case pending
    case processing
    case completed
    case failed
    case unknown

    init(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .pending
        case 1, 4:
            self = .processing
        case 2:
            self = .completed
        case 3:
            self = .failed
        default:
            self = .unknown
        }
    }
}

struct HistoryTaskPage: Decodable {
    let items: [HistoryTask]
    let total: Int

    enum CodingKeys: String, CodingKey {
        case items
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([HistoryTask].self, forKey: .items) ?? []
        total = try container.decodeFlexibleInt(forKey: .total) ?? items.count
    }
}

struct HistoryTask: Decodable {
    let id: String
    let createdAt: TimeInterval?
    let template: CreativeTemplate?
    let message: String?
    let state: HistoryTaskState
    let result: HistoryTaskResult?

    enum CodingKeys: String, CodingKey {
        case id = "task_id"
        case createdAt = "create_time"
        case template = "filter"
        case message = "msg"
        case state
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id) ?? UUID().uuidString
        createdAt = try container.decodeFlexibleTimeInterval(forKey: .createdAt)
        template = try container.decodeIfPresent(CreativeTemplate.self, forKey: .template)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        state = HistoryTaskState(rawValue: try container.decodeFlexibleInt(forKey: .state) ?? -1)
        result = try container.decodeIfPresent(HistoryTaskResult.self, forKey: .result)
    }

    var resultURL: URL? {
        result?.resultURL ?? result?.resultURLs.first
    }

    var previewURL: URL? {
        resultURL ?? template?.preferredImageURL
    }

    var isVideoResult: Bool {
        result?.contentType.lowercased().hasPrefix("video/") == true
    }
}

struct HistoryTaskResult: Decodable {
    let actionType: String?
    let contentType: String
    let resultURL: URL?
    let resultURLs: [URL]

    enum CodingKeys: String, CodingKey {
        case actionType = "aigc_action_type"
        case contentType = "aigc_content_type"
        case resultURL = "aigc_url"
        case resultURLs = "aigc_urls"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        actionType = try container.decodeIfPresent(String.self, forKey: .actionType)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType) ?? ""
        resultURL = try container.decodeFlexibleURL(forKey: .resultURL)
        resultURLs = try container.decodeFlexibleURLs(forKey: .resultURLs)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
            return value
        }
        if let value = try decodeFlexibleInt(forKey: key) {
            return String(value)
        }
        return nil
    }

    func decodeFlexibleTimeInterval(forKey key: Key) throws -> TimeInterval? {
        if let value = try? decodeIfPresent(TimeInterval.self, forKey: key) {
            return value > 1_000_000_000_000 ? value / 1_000 : value
        }
        guard let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty else {
            return nil
        }
        if let interval = TimeInterval(value) {
            return interval > 1_000_000_000_000 ? interval / 1_000 : interval
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)?.timeIntervalSince1970
    }

    func decodeFlexibleURL(forKey key: Key) throws -> URL? {
        guard let value = try decodeIfPresent(String.self, forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return URL(string: value)
    }

    func decodeFlexibleURLs(forKey key: Key) throws -> [URL] {
        if let values = try decodeIfPresent([String].self, forKey: key) {
            return values.compactMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        if let value = try decodeFlexibleURL(forKey: key) {
            return [value]
        }
        return []
    }
}
