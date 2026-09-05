//
//  Models.swift
//  PiTutti Setlist App
//
//  Wire types for the FastAPI backend on the NAS. Property names are
//  camelCase; APIClient's JSONDecoder/JSONEncoder use snake_case key
//  conversion, so these line up with the backend's JSON without manual
//  CodingKeys (see backend/app/routers/scores.py and routers/setlists.py).
//

import Foundation

// MARK: - Library

struct Score: Codable, Identifiable, Hashable {
    let id: Int
    let filename: String
    let category: String
    let instrument: String?
    let pageCount: Int?
    let ingestedAt: String?
    let updatedAt: String?
    let repertoireTitle: String?
    let catalogueNumber: String?
    let composers: String?

    /// The repertoire title when this score is linked to one, otherwise
    /// the bare filename — same fallback `setlist_tool.py`'s `_score_line`
    /// uses.
    var displayTitle: String { repertoireTitle ?? filename }

    var displayComposers: String {
        guard let composers, !composers.isEmpty else { return "—" }
        return composers
    }

    var pageCountLabel: String {
        guard let pageCount else { return "?p" }
        return "\(pageCount)p"
    }
}

// MARK: - Setlists

struct SetlistSummary: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String?
    let createdAt: String?
    let itemCount: Int
}

struct SetlistDetail: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String?
    let createdAt: String?
    var items: [SetlistItem]
}

/// A `setlist_score` row. The joined fields (filename, category,
/// repertoireTitle, ...) are present on the setlist-detail and reorder
/// responses, but absent on the raw row `POST /setlists/{id}/items`
/// returns — they simply decode to nil there since every one of them is
/// Optional.
struct SetlistItem: Codable, Identifiable, Hashable {
    let id: Int
    let setlistId: Int
    let scoreId: Int
    let position: Int
    let pageStart: Int?
    let pageEnd: Int?
    let notes: String?

    let filename: String?
    let category: String?
    let instrument: String?
    let pageCount: Int?
    let repertoireTitle: String?
    let catalogueNumber: String?
    let composers: String?

    var displayTitle: String { repertoireTitle ?? filename ?? "Untitled" }
    var displayComposers: String {
        guard let composers, !composers.isEmpty else { return "—" }
        return composers
    }

    var pageRangeLabel: String? {
        guard let pageStart, let pageEnd else { return nil }
        return "pp. \(pageStart)–\(pageEnd)"
    }
}

// MARK: - Requests

struct SetlistCreateRequest: Encodable {
    let title: String
    let description: String?
}

struct SetlistItemCreateRequest: Encodable {
    let scoreId: Int
    let position: Int?
    let pageStart: Int?
    let pageEnd: Int?
    let notes: String?
}

struct ReorderRequest: Encodable {
    let itemIds: [Int]
}

struct StatusResponse: Codable {
    let status: String
}
