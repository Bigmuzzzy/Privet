//
//  APIClient.swift
//  Privet
//

import Foundation

class APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = "http://localhost:3000"
    private let wsURL = "ws://localhost:3000/ws"
    #else
    private let baseURL = "https://your-server.com"
    private let wsURL = "wss://your-server.com/ws"
    #endif

    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }

    private init() {}

    // MARK: - Token Management

    func setToken(_ token: String) {
        authToken = token
    }

    func clearToken() {
        authToken = nil
    }

    func getToken() -> String? {
        return authToken
    }

    func getWebSocketURL() -> URL? {
        guard let token = authToken else { return nil }
        return URL(string: "\(wsURL)?token=\(token)")
    }

    // MARK: - HTTP Methods

    func get<T: Decodable>(_ endpoint: String) async throws -> T {
        return try await request(endpoint, method: "GET")
    }

    func post<T: Decodable>(_ endpoint: String, body: [String: Any]? = nil) async throws -> T {
        return try await request(endpoint, method: "POST", body: body)
    }

    func patch<T: Decodable>(_ endpoint: String, body: [String: Any]? = nil) async throws -> T {
        return try await request(endpoint, method: "PATCH", body: body)
    }

    func delete(_ endpoint: String) async throws {
        let _: EmptyResponse = try await request(endpoint, method: "DELETE")
    }

    // MARK: - Private Methods

    private func request<T: Decodable>(_ endpoint: String, method: String, body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        if httpResponse.statusCode == 403 {
            throw APIError.forbidden
        }

        if httpResponse.statusCode == 404 {
            throw APIError.notFound
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Unknown error")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Models

struct EmptyResponse: Decodable {}

struct ErrorResponse: Decodable {
    let error: String
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case serverError(String)
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Session expired. Please login again."
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .serverError(let message):
            return message
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}
