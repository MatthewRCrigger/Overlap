import Foundation

/// The app only calls this after a bundled and previously generated recipe
/// both miss. The OpenAI credential stays exclusively in the Cloudflare Worker.
struct ComboFallbackClient: Sendable {
    struct GeneratedCombo: Decodable, Sendable {
        let name: String
        let emoji: String
    }

    private struct RequestBody: Encodable {
        let left: String
        let right: String
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

    func combine(left: String, right: String) async -> GeneratedCombo? {
        guard let endpoint else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12
        request.httpBody = try? JSONEncoder().encode(RequestBody(left: left, right: right))

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let combo = try JSONDecoder().decode(GeneratedCombo.self, from: data)
            guard !combo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !combo.emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return combo
        } catch {
            return nil
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
