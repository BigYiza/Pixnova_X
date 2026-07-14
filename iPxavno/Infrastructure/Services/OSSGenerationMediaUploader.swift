import Foundation

final class OSSGenerationMediaUploader: GenerationMediaUploading {
    private let apiClient: APIClient
    private let session: URLSession

    init(apiClient: APIClient, session: URLSession = .shared) {
        self.apiClient = apiClient
        self.session = session
    }

    func resolveMediaInputs(for draft: GenerationDraft) async throws -> GenerationDraft {
        var resolvedInputs: [GenerationMediaInput] = []

        for input in draft.mediaInputs {
            switch input {
            case .empty:
                throw GenerationWorkflowPreflightError.missingMedia(kind: .image, expected: 1, actual: 0, firstMissingIndex: 0)
            case .remote:
                resolvedInputs.append(input)
            case let .localImage(url):
                let remoteURL = try await uploadLocalImage(url)
                resolvedInputs.append(.remote(remoteURL))
            }
        }

        return GenerationDraft(
            templateID: draft.templateID,
            mediaInputs: resolvedInputs,
            prompt: draft.prompt,
            negativePrompt: draft.negativePrompt,
            externalArguments: draft.externalArguments,
            combineConfigs: draft.combineConfigs
        )
    }

    private func uploadLocalImage(_ url: URL) async throws -> URL {
        let data: Data

        do {
            data = try Data(contentsOf: url)
        } catch {
            throw AppError.underlying(error)
        }

        let contentType = Self.contentType(for: data, fallbackURL: url)
        let fileExtension = Self.fileExtension(for: contentType)
        let signedURL = try await requestSignedURL(contentType: contentType, fileExtension: fileExtension)
        try await put(data: data, to: signedURL.signURL, contentType: contentType)
        return signedURL.fileURL
    }

    private func requestSignedURL(contentType: String, fileExtension: String) async throws -> OSSUploadSignResponse {
        let payload = OSSUploadSignRequest(
            contentType: contentType,
            filename: "\(UUID().uuidString).\(fileExtension)"
        )
        let body = try JSONEncoder().encode(payload)
        let endpoint = APIEndpoint<ServiceEnvelope<OSSUploadSignResponse>>(
            method: .post,
            path: "/api/ali_oss/upload_sign_url",
            body: body
        )
        return try await apiClient.sendService(endpoint)
    }

    private func put(data: Data, to url: URL, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.put.rawValue
        request.httpBody = data
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let response: URLResponse

        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw AppError.underlying(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppError.invalidResponse
        }
    }

    private static func contentType(for data: Data, fallbackURL: URL) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }

        switch fallbackURL.pathExtension.lowercased() {
        case "png":
            return "image/png"
        default:
            return "image/jpeg"
        }
    }

    private static func fileExtension(for contentType: String) -> String {
        switch contentType {
        case "image/png":
            return "png"
        default:
            return "jpg"
        }
    }
}

private struct OSSUploadSignRequest: Encodable {
    let contentType: String
    let filename: String

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case filename
    }
}

private struct OSSUploadSignResponse: Decodable {
    let signURL: URL
    let fileURL: URL

    enum CodingKeys: String, CodingKey {
        case signURL = "sign_url"
        case fileURL = "file_url"
    }
}
