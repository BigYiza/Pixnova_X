import Foundation

enum AccountUserGroupPosition {
    static let membershipCloseButton = "MemberShipCloseBtn"
    static let membershipPaywall = "MemberShip_Paywall"
}

enum InvitationRedeemState: String, Codable {
    case redeemed
    case expired
    case available
}

struct AuthCredential: Codable {
    let userID: String
    let accessToken: String
    let expiresAt: Date

    var isValid: Bool {
        !userID.isEmpty && !accessToken.isEmpty && expiresAt.timeIntervalSinceNow > 0
    }

    var needsRefresh: Bool {
        !isValid || expiresAt.timeIntervalSinceNow <= 30 * 60
    }
}

struct AccountSnapshot: Codable {
    var accessToken: String
    var tokenExpireTime: TimeInterval
    var userID: String
    var isVIP: Bool
    var vipExpirationTime: TimeInterval?
    var videoTimes: Int
    var giveAIVideosTimes: Int
    var freeVIPTimes: Int
    var diamonds: Int
    var invitationInfo: InvitationInfo?
    var displayInvitationInfo: InvitationInfoDelta?
    var vipRewardInfo: VIPRewardInfo?
    var userGroupMap: [String: JSONValue]
    var user: RegisteredUserInfo?

    enum CodingKeys: String, CodingKey {
        case accessToken
        case tokenExpireTime
        case userID = "userId"
        case isVIP = "isVip"
        case vipExpirationTime
        case videoTimes
        case giveAIVideosTimes
        case freeVIPTimes
        case diamonds
        case invitationInfo
        case displayInvitationInfo
        case vipRewardInfo
        case userGroupMap
        case user
    }

    static let empty = AccountSnapshot(
        accessToken: "",
        tokenExpireTime: 0,
        userID: "",
        isVIP: false,
        vipExpirationTime: nil,
        videoTimes: 0,
        giveAIVideosTimes: 0,
        freeVIPTimes: 0,
        diamonds: 0,
        invitationInfo: nil,
        displayInvitationInfo: nil,
        vipRewardInfo: nil,
        userGroupMap: [:],
        user: nil
    )

    var credential: AuthCredential? {
        guard !userID.isEmpty, !accessToken.isEmpty else { return nil }
        return AuthCredential(
            userID: userID,
            accessToken: accessToken,
            expiresAt: Date(timeIntervalSince1970: tokenExpireTime)
        )
    }

    var invitationRedeemState: InvitationRedeemState {
        if invitationInfo?.invitedCode?.isEmpty == false {
            return .redeemed
        }

        guard let registrationDate = user?.registrationDate else {
            return .available
        }

        return Date().timeIntervalSince(registrationDate) > 3 * 24 * 60 * 60 ? .expired : .available
    }

    mutating func applyLogin(_ payload: LoginPayload) {
        if !payload.userID.isEmpty {
            userID = payload.userID
        }
        if !payload.credential.token.isEmpty {
            accessToken = payload.credential.token
        }
        if payload.credential.expiresAt > 0 {
            tokenExpireTime = payload.credential.expiresAt
        }
    }

    mutating func applyEntitlement(_ entitlement: EntitlementSnapshot) {
        isVIP = entitlement.isMember
        vipExpirationTime = entitlement.expiresAt
        videoTimes = entitlement.videoCredits
        giveAIVideosTimes = entitlement.giveAIVideosTimes
        freeVIPTimes = entitlement.freeVIPTimes
        diamonds = entitlement.diamonds
    }

    mutating func applyUserInfo(_ payload: UserInfoPayload) {
        displayInvitationInfo = invitationInfo?.delta(to: payload.invitationInfo)
        invitationInfo = payload.invitationInfo
        vipRewardInfo = payload.vipRewardInfo
        user = payload.user
    }
}

struct AccountProfile: Codable {
    let userID: String
    let displayName: String?
    let inviteCode: String?
    let entitlement: EntitlementSnapshot?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "name"
        case inviteCode = "invite_code"
        case entitlement = "vip_reward"
    }
}

struct EntitlementSnapshot: Codable {
    let isMember: Bool
    let expiresAt: TimeInterval?
    let videoCredits: Int
    let giveAIVideosTimes: Int
    let freeVIPTimes: Int
    let diamonds: Int

    enum CodingKeys: String, CodingKey {
        case isMember = "is_vip"
        case expiresAt = "expires_time"
        case videoCredits = "video_times"
        case giveAIVideosTimes = "give_ai_videos_times"
        case freeVIPTimes = "free_vip_times"
        case diamonds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isMember = try container.decodeFlexibleBool(forKey: .isMember) ?? false
        expiresAt = try container.decodeIfPresent(TimeInterval.self, forKey: .expiresAt)
        videoCredits = try container.decodeIfPresent(Int.self, forKey: .videoCredits) ?? 0
        giveAIVideosTimes = try container.decodeIfPresent(Int.self, forKey: .giveAIVideosTimes) ?? 0
        freeVIPTimes = try container.decodeIfPresent(Int.self, forKey: .freeVIPTimes) ?? 0
        diamonds = try container.decodeIfPresent(Int.self, forKey: .diamonds) ?? 0
    }
}

struct UserInfoPayload: Codable {
    let invitationInfo: InvitationInfo?
    let vipRewardInfo: VIPRewardInfo?
    let user: RegisteredUserInfo?

    enum CodingKeys: String, CodingKey {
        case invitationInfo = "invite_info"
        case vipRewardInfo = "vip_reward"
        case user
    }
}

struct InvitationInfo: Codable {
    let memberDays: Int
    let diamonds: Int
    let inviteCount: Int
    let inviteCode: String?
    let shouldShowDialog: Bool
    let inviteLogs: [JSONValue]?
    let invitedCode: String?

    enum CodingKeys: String, CodingKey {
        case memberDays = "already_get_member_days"
        case diamonds = "already_get_diamonds"
        case inviteCount = "already_invite_person_count"
        case inviteCode = "invite_code"
        case shouldShowDialog = "show_invite_info_dialog"
        case inviteLogs = "invite_logs"
        case invitedCode = "invited_code"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberDays = try container.decodeIfPresent(Int.self, forKey: .memberDays) ?? 0
        diamonds = try container.decodeIfPresent(Int.self, forKey: .diamonds) ?? 0
        inviteCount = try container.decodeIfPresent(Int.self, forKey: .inviteCount) ?? 0
        inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)
        shouldShowDialog = try container.decodeFlexibleBool(forKey: .shouldShowDialog) ?? false
        inviteLogs = try container.decodeIfPresent([JSONValue].self, forKey: .inviteLogs)
        invitedCode = try container.decodeIfPresent(String.self, forKey: .invitedCode)
    }

    func delta(to next: InvitationInfo?) -> InvitationInfoDelta? {
        guard let next else { return nil }
        let memberDaysDelta = max(0, next.memberDays - memberDays)
        let diamondsDelta = max(0, next.diamonds - diamonds)
        let inviteCountDelta = max(0, next.inviteCount - inviteCount)

        guard memberDaysDelta > 0 || diamondsDelta > 0 || inviteCountDelta > 0 else {
            return nil
        }

        return InvitationInfoDelta(
            memberDays: memberDaysDelta,
            diamonds: diamondsDelta,
            inviteCount: inviteCountDelta
        )
    }
}

struct InvitationInfoDelta: Codable {
    let memberDays: Int
    let diamonds: Int
    let inviteCount: Int
}

struct VIPRewardInfo: Codable {
    let rawValue: JSONValue

    init(from decoder: Decoder) throws {
        rawValue = try JSONValue(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try rawValue.encode(to: encoder)
    }
}

struct RegisteredUserInfo: Codable {
    let userID: String?
    let registrationTime: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case registrationTime = "reg_time"
    }

    var registrationDate: Date? {
        guard let registrationTime else { return nil }
        return Date(timeIntervalSince1970: registrationTime)
    }
}

struct LoginPayload: Codable {
    let userID: String
    let credential: TokenPayload

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case credential = "token_info"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeIfPresent(String.self, forKey: .userID) ?? ""
        credential = try container.decode(TokenPayload.self, forKey: .credential)
    }
}

struct TokenPayload: Codable {
    let token: String
    let expiresAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expire_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        token = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("token")) ?? ""
        expiresAt = try container.decodeIfPresent(TimeInterval.self, forKey: DynamicCodingKey("expire_time"))
            ?? container.decodeIfPresent(TimeInterval.self, forKey: DynamicCodingKey("expires_time"))
            ?? 0
    }
}

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            let rounded = value.rounded()
            if abs(value - rounded) < .ulpOfOne {
                return "\(Int(rounded))"
            }
            return String(value)
        case let .bool(value):
            return value ? "true" : "false"
        default:
            return nil
        }
    }

    var normalizedComparableString: String {
        (stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var isEmptyObject: Bool {
        if case let .object(value) = self {
            return value.isEmpty
        }
        return false
    }
}

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleBool(forKey key: Key) throws -> Bool? {
        if let value = try decodeIfPresent(Bool.self, forKey: key) {
            return value
        }

        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return value > 0
        }

        if let value = try decodeIfPresent(String.self, forKey: key) {
            return ["1", "true", "yes"].contains(value.lowercased())
        }

        return nil
    }
}
