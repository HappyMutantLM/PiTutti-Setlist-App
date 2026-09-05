//
//  AddScoreToSetlistView.swift
//  PiTutti Setlist App
//
//  Search the library, pick a score, optionally set an excerpt page
//  range and notes, then add it to the setlist — matching
//  setlist_tool.py's interactive `build` flow.
//

import SwiftUI

struct AddScoreToSetlistView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var libraryViewModel = LibraryViewModel()
    @State private var selectedScore: Score?
    @State private var pageStartText = ""
    @State private var pageEndText = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    /// (scoreId, pageStart, pageEnd, notes)
    let onAdd: (Int, Int?, Int?, String?) async -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let selectedScore {
                    detailsForm(for: selectedScore)
                } else {
                    scorePicker
                }
            }
            .navigationTitle(selectedScore == nil ? "Add a Piece" : "Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if selectedScore != nil {
                    ToolbarItem(placement: .navigation) {
                        Button("Back") {
                            selectedScore = nil
                            errorMessage = nil
                        }
                    }
                }
            }
        }
        .task { await libraryViewModel.load() }
    }

    private var scorePicker: some View {
        List(libraryViewModel.filteredScores) { score in
            Button {
                selectedScore = score
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(score.displayTitle)
                        .foregroundStyle(.primary)
                    Text(score.displayComposers)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $libraryViewModel.searchText, prompt: "Title, composer, filename…")
        .overlay {
            if libraryViewModel.isLoading && libraryViewModel.allScores.isEmpty {
                ProgressView()
            } else if libraryViewModel.filteredScores.isEmpty && !libraryViewModel.isLoading {
                if libraryViewModel.searchText.isEmpty {
                    ContentUnavailableView(
                        "No Scores Yet",
                        systemImage: "music.note",
                        description: Text("Nothing in the library on the NAS yet.")
                    )
                } else {
                    ContentUnavailableView.search(text: libraryViewModel.searchText)
                }
            }
        }
    }

    private func detailsForm(for score: Score) -> some View {
        Form {
            Section("Piece") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(score.displayTitle)
                    Text(score.displayComposers)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Excerpt (optional — leave blank for the whole score)") {
                TextField("Start page", text: $pageStartText)
                    .numericKeyboard()
                TextField("End page", text: $pageEndText)
                    .numericKeyboard()
            }
            Section("Notes") {
                TextField("Optional", text: $notes, axis: .vertical)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            Section {
                Button {
                    Task { await add(score: score) }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Add to Setlist")
                    }
                }
                .disabled(isSaving || !pageRangeIsValid)
            }
        }
    }

    /// Mirrors the backend's `_validate_page_range`: both blank (whole
    /// score) or both present with end >= start.
    private var pageRangeIsValid: Bool {
        if pageStartText.isEmpty && pageEndText.isEmpty { return true }
        guard let start = Int(pageStartText), let end = Int(pageEndText) else { return false }
        return end >= start
    }

    private func add(score: Score) async {
        isSaving = true
        errorMessage = nil
        let start = Int(pageStartText)
        let end = Int(pageEndText)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        await onAdd(score.id, start, end, trimmedNotes.isEmpty ? nil : trimmedNotes)
        isSaving = false
        dismiss()
    }
}

#Preview {
    AddScoreToSetlistView { _, _, _, _ in }
}


private extension View {
    /// `.keyboardType(.numberPad)` is UIKit-only. This project's target
    /// also builds for macOS/visionOS (Xcode's default multiplatform
    /// template), where TextField has no keyboard type to set — a no-op
    /// there instead of a compile error.
    @ViewBuilder
    func numericKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
}
