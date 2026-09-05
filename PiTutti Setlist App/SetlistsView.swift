//
//  SetlistsView.swift
//  PiTutti Setlist App
//

import SwiftUI

struct SetlistsView: View {
    @State private var viewModel = SetlistsViewModel()
    @State private var showingCreateSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.setlists.isEmpty {
                ProgressView("Loading setlists…")
            } else if let errorMessage = viewModel.errorMessage, viewModel.setlists.isEmpty {
                ContentUnavailableView(
                    "Couldn't Load Setlists",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if viewModel.setlists.isEmpty {
                ContentUnavailableView(
                    "No Setlists Yet",
                    systemImage: "music.note.list",
                    description: Text("Tap + to create one.")
                )
            } else {
                List {
                    ForEach(viewModel.setlists) { setlist in
                        NavigationLink(value: setlist) {
                            SetlistRow(setlist: setlist)
                        }
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { viewModel.setlists[$0] }
                        Task {
                            for setlist in toDelete {
                                await viewModel.delete(setlist)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Setlists")
        .navigationDestination(for: SetlistSummary.self) { setlist in
            SetlistDetailView(setlistId: setlist.id, title: setlist.title)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("New Setlist", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateSetlistView { title, description in
                await viewModel.create(title: title, description: description)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

struct SetlistRow: View {
    let setlist: SetlistSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(setlist.title)
            if let description = setlist.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("\(setlist.itemCount) item\(setlist.itemCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { SetlistsView() }
}
