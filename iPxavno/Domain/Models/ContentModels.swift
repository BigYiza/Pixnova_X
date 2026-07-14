import Foundation

enum CreativeKind: Int, Codable {
    case unknown = -1
    case filter = 1
    case hair = 2
    case cutout = 3
    case photo = 4
    case avatar = 5
    case video = 6
    case outfit = 7
    case baby = 8
    case collection = 9
    case textToVideo = 10
    case imageToVideo = 11
    case makeup = 12
    case multiImageToVideo = 13
    case videoEnhance = 14
    case textToImage = 15
    case imageToImage = 16

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue: Int

        if let intValue = try? container.decode(Int.self) {
            rawValue = intValue
        } else if let stringValue = try? container.decode(String.self), let intValue = Int(stringValue) {
            rawValue = intValue
        } else {
            rawValue = CreativeKind.unknown.rawValue
        }

        self = CreativeKind(rawValue: rawValue) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct DiscoverySnapshot: Codable {
    let sections: [ContentSection]

    enum CodingKeys: String, CodingKey {
        case sections = "cards"
    }

    init(sections: [ContentSection]) {
        self.sections = sections.map { $0.permeatingCardID() }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSections = try container.decodeIfPresent([ContentSection].self, forKey: .sections) ?? []
        sections = decodedSections.map { $0.permeatingCardID() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sections.map { $0.permeatingCardID() }, forKey: .sections)
    }
}

struct ContentSection: Codable {
    let id: Int
    let title: String
    let homeStyle: Int
    let category: CreativeKind
    let templates: [CreativeTemplate]
    let relationCardID: Int?
    let relationCardMedia: String?
    let showPositions: [Int]

    enum CodingKeys: String, CodingKey {
        case id = "card_id"
        case title = "name"
        case homeStyle = "home_style"
        case category = "category_id"
        case templates = "filters"
        case relationCardID = "relation_card_id"
        case relationCardMedia = "relation_card_media_desc"
        case showPosition = "show_position"
    }

    init(
        id: Int,
        title: String,
        style: String?,
        category: CreativeKind,
        templates: [CreativeTemplate]
    ) {
        self.id = id
        self.title = title
        homeStyle = Int(style ?? "") ?? 1
        self.category = category
        self.templates = templates
        relationCardID = nil
        relationCardMedia = nil
        showPositions = []
    }

    init(
        id: Int,
        title: String,
        homeStyle: Int,
        category: CreativeKind,
        templates: [CreativeTemplate],
        relationCardID: Int?,
        relationCardMedia: String?,
        showPositions: [Int]
    ) {
        self.id = id
        self.title = title
        self.homeStyle = homeStyle
        self.category = category
        self.templates = templates
        self.relationCardID = relationCardID
        self.relationCardMedia = relationCardMedia
        self.showPositions = showPositions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id) ?? UUID().hashValue
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Collection"
        homeStyle = try container.decodeFlexibleInt(forKey: .homeStyle) ?? 1
        category = try container.decodeIfPresent(CreativeKind.self, forKey: .category) ?? .unknown
        templates = try container.decodeIfPresent([CreativeTemplate].self, forKey: .templates) ?? []
        relationCardID = try container.decodeFlexibleInt(forKey: .relationCardID)
        relationCardMedia = try container.decodeIfPresent(String.self, forKey: .relationCardMedia)
        showPositions = try container.decodeFlexibleIntArray(forKey: .showPosition)
    }

    func permeatingCardID() -> ContentSection {
        ContentSection(
            id: id,
            title: title,
            homeStyle: homeStyle,
            category: category,
            templates: templates.map { $0.withCardID(id) },
            relationCardID: relationCardID,
            relationCardMedia: relationCardMedia,
            showPositions: showPositions
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(homeStyle, forKey: .homeStyle)
        try container.encode(category, forKey: .category)
        try container.encode(templates, forKey: .templates)
        try container.encodeIfPresent(relationCardID, forKey: .relationCardID)
        try container.encodeIfPresent(relationCardMedia, forKey: .relationCardMedia)
        try container.encode(showPositions, forKey: .showPosition)
    }
}

struct CreativeTemplate: Codable {
    let id: Int
    let kind: CreativeKind
    let title: String
    let summary: String?
    let coverURL: URL?
    let alternateCoverURL: URL?
    let operationCoverURLs: [URL]
    let requiresMembership: Bool
    let storageChannel: String?
    let inputRequirement: TemplateInputRequirement?
    let waitSeconds: Int
    let processingMessages: [String]
    let prompt: String?
    let usageCount: Int
    let diamondCost: Int
    let customParameter: GenerationParameterConfiguration?
    let combineConfigs: JSONValue?
    let tint: String?
    let cardID: Int?
    let maxInputImageCount: Int?

    enum CodingKeys: String, CodingKey {
        case id = "filter_id"
        case kind = "category_id"
        case title = "name"
        case summary = "description"
        case coverURL = "cover"
        case alternateCoverURL = "cover1"
        case operationCoverURLs = "operations_cover"
        case requiresMembership = "vip_need"
        case storageChannel = "oss_type"
        case inputRequirement = "input_require"
        case waitSeconds = "wait_seconds"
        case processingMessages = "processing_copywritings"
        case prompt
        case usageCount = "use_times"
        case diamondCost = "diamonds"
        case customParameter = "custom_parameter"
        case combineConfigs = "combine_configs"
        case maxInputImageCount = "max_input_count"
        case tint
        case cardID = "card_id"
    }

    init(
        id: Int,
        kind: CreativeKind,
        title: String,
        summary: String?,
        coverURL: URL?,
        alternateCoverURL: URL?,
        operationCoverURLs: [URL],
        requiresMembership: Bool,
        storageChannel: String?,
        inputRequirement: TemplateInputRequirement?,
        waitSeconds: Int,
        processingMessages: [String],
        prompt: String?,
        usageCount: Int,
        diamondCost: Int,
        customParameter: GenerationParameterConfiguration? = nil,
        combineConfigs: JSONValue? = nil,
        tint: String?,
        cardID: Int?,
        maxInputImageCount: Int?
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.coverURL = coverURL
        self.alternateCoverURL = alternateCoverURL
        self.operationCoverURLs = operationCoverURLs
        self.requiresMembership = requiresMembership
        self.storageChannel = storageChannel
        self.inputRequirement = inputRequirement
        self.waitSeconds = waitSeconds
        self.processingMessages = processingMessages
        self.prompt = prompt
        self.usageCount = usageCount
        self.diamondCost = diamondCost
        self.customParameter = customParameter
        self.combineConfigs = combineConfigs
        self.tint = tint
        self.cardID = cardID
        self.maxInputImageCount = maxInputImageCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        kind = try container.decodeIfPresent(CreativeKind.self, forKey: .kind) ?? .unknown
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        coverURL = try container.decodeFlexibleURL(forKey: .coverURL)
        alternateCoverURL = try container.decodeFlexibleURL(forKey: .alternateCoverURL)
        operationCoverURLs = try container.decodeFlexibleURLs(forKey: .operationCoverURLs)
        requiresMembership = try container.decodeFlexibleBool(forKey: .requiresMembership) ?? false
        storageChannel = try container.decodeIfPresent(String.self, forKey: .storageChannel)
        inputRequirement = try container.decodeIfPresent(TemplateInputRequirement.self, forKey: .inputRequirement)
        waitSeconds = try container.decodeFlexibleInt(forKey: .waitSeconds) ?? 20
        processingMessages = try container.decodeIfPresent([String].self, forKey: .processingMessages) ?? []
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        usageCount = try container.decodeFlexibleInt(forKey: .usageCount) ?? 0
        diamondCost = try container.decodeFlexibleInt(forKey: .diamondCost) ?? 0
        customParameter = try container.decodeIfPresent(GenerationParameterConfiguration.self, forKey: .customParameter)
        combineConfigs = try container.decodeIfPresent(JSONValue.self, forKey: .combineConfigs)
        tint = try container.decodeIfPresent(String.self, forKey: .tint)
        cardID = try container.decodeFlexibleInt(forKey: .cardID)
        maxInputImageCount = try container.decodeFlexibleInt(forKey: .maxInputImageCount)
    }

    var preferredImageURL: URL? {
        operationCoverURLs.first ?? coverURL ?? alternateCoverURL
    }
    
    var preferredVideoURL: URL? {
        operationCoverURLs.first(where: { url in
            return url.absoluteString.hasSuffix(".mp4")
        }) ?? coverURL ?? alternateCoverURL
    }


    func withCardID(_ cardID: Int) -> CreativeTemplate {
        CreativeTemplate(
            id: id,
            kind: kind,
            title: title,
            summary: summary,
            coverURL: coverURL,
            alternateCoverURL: alternateCoverURL,
            operationCoverURLs: operationCoverURLs,
            requiresMembership: requiresMembership,
            storageChannel: storageChannel,
            inputRequirement: inputRequirement,
            waitSeconds: waitSeconds,
            processingMessages: processingMessages,
            prompt: prompt,
            usageCount: usageCount,
            diamondCost: diamondCost,
            customParameter: customParameter,
            combineConfigs: combineConfigs,
            tint: tint,
            cardID: cardID,
            maxInputImageCount: maxInputImageCount
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(coverURL, forKey: .coverURL)
        try container.encodeIfPresent(alternateCoverURL, forKey: .alternateCoverURL)
        try container.encode(operationCoverURLs, forKey: .operationCoverURLs)
        try container.encode(requiresMembership, forKey: .requiresMembership)
        try container.encodeIfPresent(storageChannel, forKey: .storageChannel)
        try container.encodeIfPresent(inputRequirement, forKey: .inputRequirement)
        try container.encode(waitSeconds, forKey: .waitSeconds)
        try container.encode(processingMessages, forKey: .processingMessages)
        try container.encodeIfPresent(prompt, forKey: .prompt)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encode(diamondCost, forKey: .diamondCost)
        try container.encodeIfPresent(customParameter, forKey: .customParameter)
        try container.encodeIfPresent(combineConfigs, forKey: .combineConfigs)
        try container.encodeIfPresent(maxInputImageCount, forKey: .maxInputImageCount)
        try container.encodeIfPresent(tint, forKey: .tint)
        try container.encodeIfPresent(cardID, forKey: .cardID)
    }
}

struct TemplateInputRequirement: Codable {
    let imageCount: Int?
    let peopleCount: Int?

    enum CodingKeys: String, CodingKey {
        case imageCount = "image_count"
        case peopleCount = "people_numbers_one_image"
    }
}

struct GenerationParameterConfiguration: Codable, Equatable {
    var parameters: [GenerationParameter]
    var restricts: [GenerationParameterRestriction]

    enum CodingKeys: String, CodingKey {
        case parameters
        case restricts
    }

    init(parameters: [GenerationParameter], restricts: [GenerationParameterRestriction]) {
        self.parameters = parameters
        self.restricts = restricts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parameters = try container.decodeIfPresent([GenerationParameter].self, forKey: .parameters) ?? []
        restricts = try container.decodeIfPresent([GenerationParameterRestriction].self, forKey: .restricts) ?? []
    }
}

struct GenerationParameter: Codable, Equatable, Identifiable {
    var id: String { key }
    let icon: String?
    let key: String
    let title: String
    let selected: JSONValue?
    let values: [GenerationParameterValue]

    enum CodingKeys: String, CodingKey {
        case icon
        case key
        case title
        case selected
        case values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        key = try container.decodeIfPresent(String.self, forKey: .key) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? key
        selected = try container.decodeIfPresent(JSONValue.self, forKey: .selected)
        values = try container.decodeIfPresent([GenerationParameterValue].self, forKey: .values) ?? []
    }
}

struct GenerationParameterValue: Codable, Equatable, Identifiable {
    static let videoBoostCalculationMethod = "current and ugc duration multiplier"

    var id: String { "\(label)|\(value.normalizedComparableString)|\(times)" }
    let label: String
    let times: String
    let value: JSONValue
    let calculationMethod: String?
    let durationTimes: String?

    enum CodingKeys: String, CodingKey {
        case label
        case times
        case value
        case calculationMethod = "calculate_method"
        case durationTimes = "duration_times"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        if let stringValue = try? container.decode(String.self, forKey: .times) {
            times = stringValue
        } else if let intValue = try? container.decode(Int.self, forKey: .times) {
            times = "\(intValue)"
        } else if let doubleValue = try? container.decode(Double.self, forKey: .times) {
            times = "\(doubleValue)"
        } else {
            times = "1"
        }
        value = try container.decodeIfPresent(JSONValue.self, forKey: .value) ?? .string(label)
        calculationMethod = try container.decodeIfPresent(String.self, forKey: .calculationMethod)
        durationTimes = try container.decodeIfPresent(String.self, forKey: .durationTimes)
    }
}

struct GenerationParameterRestriction: Codable, Equatable {
    let key: String
    let value: JSONValue
    let restricts: [[String: [JSONValue]]]

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case restricts = "restrict"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decodeIfPresent(String.self, forKey: .key) ?? ""
        value = try container.decodeIfPresent(JSONValue.self, forKey: .value) ?? .null
        restricts = try container.decodeIfPresent([[String: [JSONValue]]].self, forKey: .restricts) ?? []
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    func decodeFlexibleIntArray(forKey key: Key) throws -> [Int] {
        if let values = try decodeIfPresent([Int].self, forKey: key) {
            return values
        }
        if let values = try decodeIfPresent([String].self, forKey: key) {
            return values.compactMap(Int.init)
        }
        if let value = try decodeFlexibleInt(forKey: key) {
            return [value]
        }
        return []
    }

    func decodeFlexibleURL(forKey key: Key) throws -> URL? {
        guard let string = try decodeIfPresent(String.self, forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else {
            return nil
        }
        return URL(string: string)
    }

    func decodeFlexibleURLs(forKey key: Key) throws -> [URL] {
        if let strings = try decodeIfPresent([String].self, forKey: key) {
            return strings.compactMap { string in
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return URL(string: trimmed)
            }
        }
        if let string = try decodeIfPresent(String.self, forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !string.isEmpty,
           let url = URL(string: string) {
            return [url]
        }
        return []
    }

}
