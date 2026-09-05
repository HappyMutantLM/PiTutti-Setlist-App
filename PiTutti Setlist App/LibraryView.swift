//
//  LibraryView.swift
//  PiTutti Setlist App
//
//  Free-text library search — feature-parity with `setlist_tool.py
//  search`, no category/instrument filter UI (explicitly out of scope
//  for v1).
//

import SwiftUI

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.allScores.isEmpty {
                ProgressView("Loading library…")
            } else if let errorMessage = viewModel.errorMessage, viewModel.allScores.isEmpty {
                ContentUnavailableView(
                    "Couldn't Load the Library",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if viewModel.filteredScores.isEmpty {
                if viewModel.searchText.isEmpty {
                    ContentUnavailableView(
                        "No Scores Yet",
                        systemImage: "music.note",
                        description: Text("Nothing in the library on the NAS yet.")
                    )
                } else {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            } else {
                List(viewModel.filteredScores) { score in
                    ScoreRow(score: score)
                }
            }
        }
        .navigationTitle("Library")
        .searchable(text: $viewModel.searchText, prompt: "Title, composer, filename…")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

struct ScoreRow: View {
    let score: Score

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(score.displayTitle)
            Text(score.displayComposers)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(score.category)
                if let instrument = score.instrument {
                    Text("· \(instrument)")
                }
                Text("· \(score.pageCountLabel)")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { LibraryView() }
}
