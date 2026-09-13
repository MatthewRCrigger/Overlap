import Foundation

/// The app asks the shared recipe service for every new local pair. The service
/// checks D1 before using OpenAI; the credential stays in the Cloudflare Worker.
struct ComboFallbackClient: Sendable {
    struct GeneratedCombo: Decodable, Sendable {
        let name: String
        let emoji: String
        let source: String?
        let promptVersion: String?
        let generatedAt: String?
        let contextKey: String?
    }

    enum Failure: Error, Equatable {
        case notConfigured, offline, timeout, rateLimited, unavailable, invalidResponse, blocked
        var message: String {
            switch self {
            case .notConfigured: "The combination service has not been configured."
            case .offline: "Connect to the internet to combine these items."
            case .timeout: "This combination took too long. Try again."
            case .rateLimited: "Too many combinations right now. Try again shortly."
            case .unavailable: "The combination service is temporarily unavailable."
            case .invalidResponse: "The service returned an unreadable result. Try again."
            case .blocked: "This combination is unavailable. Try different ingredients."
            }
        }
    }

    private struct RequestBody: Encodable {
        let left: String
        let right: String
        let context: String
    }

    private let endpoint: URL?
    private let session: URLSession

    init(
        endpoint: URL? = Self.configuredEndpoint,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func combine(left: String, right: String, context: CraftContext = .none) async throws -> GeneratedCombo {
        guard let endpoint else { throw Failure.notConfigured }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12
        request.httpBody = try JSONEncoder().encode(RequestBody(left: left, right: right, context: context.text))

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw Failure.invalidResponse }
            if http.statusCode == 429 { throw Failure.rateLimited }
            if http.statusCode == 422 { throw Failure.blocked }
            guard http.statusCode == 200 else { throw Failure.unavailable }
            let combo = try JSONDecoder().decode(GeneratedCombo.self, from: data)
            guard !combo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !combo.emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  combo.name.utf16.count <= 64,
                  combo.contextKey == context.key || (combo.contextKey == nil && context == .none)
            else { throw Failure.invalidResponse }
            return combo
        } catch let error as Failure {
            throw error
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            if error.code == .timedOut { throw Failure.timeout }
            throw Failure.offline
        } catch {
            throw Failure.invalidResponse
        }
    }

    private static var configuredEndpoint: URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "ComboFallbackEndpoint") as? String,
              let endpoint = URL(string: rawValue),
              endpoint.scheme == "https",
              endpoint.host != nil
        else {
            return nil
        }
        return endpoint
    }
}
