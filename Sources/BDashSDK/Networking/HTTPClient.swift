import Foundation

/// SDK内の共通HTTPクライアント
/// Tracking / Push通知 / アプリ接客の各処理から共通で利用する
public final class HTTPClient: Sendable {

    public static let shared = HTTPClient()

    private init() {}

    /// POST リクエストを送信する
    public func post(
        url: URL,
        body: [String: Any],
        additionalHeaders: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("bdash-sdk / ver=\(Tracker.SDK_VERSION)", forHTTPHeaderField: "User-Agent")
        for (key, value) in additionalHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        return (data, httpResponse)
    }

    public enum HTTPClientError: Error {
        case invalidResponse
    }
}
