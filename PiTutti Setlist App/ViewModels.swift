//
//  ViewModels.swift
//  PiTutti Setlist App
//

import Foundation
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    private(set) var allScores: [Score] = []
    var searchText: String = ""
    private(set) var isLoading = false
    var errorMessage: String?

    /// Client-side substring search across filename/title/composers/
    /// instrument — the backend has no free-text search endpoint, so
    /// this mirrors `search_scores()` in backend/setlist_tool.py: every
    /// whitespace-separated term must appear somewhere in the haystack,
    /// case-insensitive.
    var filteredScores: [Score] {
        let terms = searchText
            .split(separator: " ")
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return allScores }
        return allScores.filter { score in
            let haystack = [score.filename, score.repertoireTitle, score.composers, score.instrument]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            allScores = try await APIClient.shared.listScores()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
@Observable
final class SetlistsViewModel {
    private(set) var setlists: [SetlistSummary] = []
    private(set) var isLoading = false
    var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            setlists = try await APIClient.shared.listSetlists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func create(title: String, description: String?) async -> SetlistSummary? {
        do {
            let created = try await APIClient.shared.createSetlist(title: title, description: description)
            await load()
            return created
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func delete(_ setlist: SetlistSummary) async {
        do {
            try await APIClient.shared.deleteSetlist(setlist.id)
            setlists.removeAll { $0.id == setlist.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
@Observable
final class SetlistDetailViewModel {
    let setlistId: Int
    private(set) var setlist: SetlistDetail?
    private(set) var isLoading = false
    var errorMessage: String?

    init(setlistId: Int) {
        self.setlistId = setlistId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            setlist = try await APIClient.shared.getSetlist(setlistId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItem(scoreId: Int, pageStart: Int?, pageEnd: Int?, notes: String?) async {
        errorMessage = nil
        do {
            _ = try await APIClient.shared.addItem(
                setlistId: setlistId, scoreId: scoreId, pageStart: pageStart, pageEnd: pageEnd, notes: notes
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeItem(_ item: SetlistItem) async {
        errorMessage = nil
        do {
            try await APIClient.shared.removeItem(setlistId: setlistId, itemId: item.id)
            setlist?.items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes the whole setlist. Returns whether it succeeded, so the
    /// view can pop back only on success and leave errorMessage on
    /// screen otherwise.
    @discardableResult
    func delete() async -> Bool {
        errorMessage = nil
        do {
            try await APIClient.shared.deleteSetlist(setlistId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Reorders optimistically (so the List reflects the drag
    /// immediately) then persists via PUT .../reorder; on failure,
    /// reloads from the server to undo the local guess.
    func move(from source: IndexSet, to destination: Int) {
        guard var items = setlist?.items else { return }
        items.reordered(fromOffsets: source, toOffset: destination)
        setlist?.items = items

        let itemIds = items.map(\.id)
        Task {
            do {
                let updated = try await APIClient.shared.reorderSetlist(setlistId: setlistId, itemIds: itemIds)
                setlist?.items = updated
            } catch {
                errorMessage = error.localizedDescription
                await load()
            }
        }
    }
}

private extension Array where Element == SetlistItem {
    /// Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`: moves
    /// the elements at `source` to just before `destination` (indexed
    /// against the array *before* the move), preserving their relative
    /// order among themselves.
    mutating func reordered(fromOffsets source: IndexSet, toOffset destination: Int) {
        let itemsToMove = source.map { self[$0] }
        for offset in source.sorted(by: >) {
            remove(at: offset)
        }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        insert(contentsOf: itemsToMove, at: adjustedDestination)
    }
}
