//
//  APIClient.swift
//  PiTutti Setlist App
//
//  Thin HTTP client for the FastAPI backend on the NAS — same contract
//  as backend/setlist_tool.py's `_request()` helper and
//  pi_client/api_client.py. Plain HTTP, not HTTPS: see the
//  NSAppTransportSecurity exception for "memoryalpha" in Info.plist.
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(status: Int, message: String)
    case decoding(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server address."
        case .invalidResponse:
            return "The server sent back something unexpected."
        case .httpError(let status, let message):
            return message.isEmpty ? "Server returned \(status)." : "Server returned \(status): \(message)"
        case .decoding(let error):
            return "Couldn't understand the server's response (\(error.localizedDescription))."
        case .network(let error):
            return "Couldn't reach the server (\(error.localizedDescription))."
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    /// The backend on the NAS. Matches MUSIC_SERVER_URL's default in
    /// pi_client/config.py and backend/setlist_tool.py.
    private let baseURLString = "http://memoryalpha:8000"

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let session: URLSession = .shared

    // MARK: - Library

    func listScores() async throws -> [Score] {
        try await get("/scores/")
    }

    // MARK: - Setlists

    func listSetlists() async throws -> [SetlistSummary] {
        try await get("/setlists/")
    }

    func getSetlist(_ id: Int) async throws -> SetlistDetail {
        try await get("/setlists/\(id)")
    }

    func createSetlist(title: String, description: String?) async throws -> SetlistSummary {
        try await post("/setlists/", body: SetlistCreateRequest(title: title, description: description))
    }

    func deleteSetlist(_ id: Int) async throws {
        let _: StatusResponse = try await delete("/setlists/\(id)")
    }

    func addItem(
        setlistId: Int,
        scoreId: Int,
        position: Int? = nil,
        pageStart: Int? = nil,
        pageEnd: Int? = nil,
        notes: String? = nil
    ) async throws -> SetlistItem {
        let body = SetlistItemCreateRequest(
            scoreId: scoreId, position: position, pageStart: pageStart, pageEnd: pageEnd, notes: notes
        )
        return try await post("/setlists/\(setlistId)/items", body: body)
    }

    func removeItem(setlistId: Int, itemId: Int) async throws {
        let _: StatusResponse = try await delete("/setlists/\(setlistId)/items/\(itemId)")
    }

    func reorderSetlist(setlistId: Int, itemIds: [Int]) async throws -> [SetlistItem] {
        try await put("/setlists/\(setlistId)/reorder", body: ReorderRequest(itemIds: itemIds))
    }

    // MARK: - Request plumbing

    private func url(for path: String) throws -> URL {
        guard let url = URL(string: baseURLString + path) else {
            throw APIError.invalidURL
        }
        return url
    }

    private func get<Response: Decodable>(_ path: String) async throws -> Response {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = "GET"
        return try await execute(request)
    }

    private func delete<Response: Decodable>(_ path: String) async throws -> Response {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = "DELETE"
        return try await execute(request)
    }

    private func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        try await send(method: "POST", path: path, body: body)
    }

    private func put<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        try await send(method: "PUT", path: path, body: body)
    }

    private func send<Body: Encodable, Response: Decodable>(
        method: String, path: String, body: Body
    ) async throws -> Response {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw APIError.decoding(error)
        }
        return try await execute(request)
    }

    private func execute<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(status: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
