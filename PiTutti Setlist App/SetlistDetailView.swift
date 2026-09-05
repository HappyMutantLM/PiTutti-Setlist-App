//
//  SetlistDetailView.swift
//  PiTutti Setlist App
//
//  Items in performance order, with page-range/notes shown per item —
//  add, remove, reorder, matching setlist_tool.py's show/add/remove/
//  reorder commands.
//

import SwiftUI

struct SetlistDetailView: View {
    let setlistId: Int
    let title: String

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: SetlistDetailViewModel
    @State private var showingAddSheet = false
    @State private var showingDeleteConfirmation = false

    init(setlistId: Int, title: String) {
        self.setlistId = setlistId
        self.title = title
        _viewModel = State(initialValue: SetlistDetailViewModel(setlistId: setlistId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.setlist == nil {
                ProgressView("Loading…")
            } else if let errorMessage = viewModel.errorMessage, viewModel.setlist == nil {
                ContentUnavailableView(
                    "Couldn't Load Setlist",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if let setlist = viewModel.setlist {
                List {
                    Section {
                        if let description = setlist.description, !description.isEmpty {
                            Text(description).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Setlist ID")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(setlistId)")
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .font(.caption)
                    } footer: {
                        Text("Use this with reader.py --setlist-id on the Pi to load this setlist on the panel.")
                    }
                    Section {
                        if setlist.items.isEmpty {
                            Text("No pieces yet — tap + to add one.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(setlist.items) { item in
                                SetlistItemRow(item: item)
                            }
                            .onDelete { offsets in
                                let toRemove = offsets.map { setlist.items[$0] }
                                Task {
                                    for item in toRemove {
                                        await viewModel.removeItem(item)
                                    }
                                }
                            }
                            .onMove { source, destination in
                                viewModel.move(from: source, to: destination)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Piece", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                if let setlist = viewModel.setlist, !setlist.items.isEmpty {
                    EditButton()
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Setlist", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddScoreToSetlistView { scoreId, pageStart, pageEnd, notes in
                await viewModel.addItem(scoreId: scoreId, pageStart: pageStart, pageEnd: pageEnd, notes: notes)
            }
        }
        .confirmationDialog(
            "Delete this setlist?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Setlist", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This removes \"\(title)\" and all its items. The scores themselves aren't affected.")
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

struct SetlistItemRow: View {
    let item: SetlistItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.displayTitle)
            Text(item.displayComposers)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if item.pageRangeLabel != nil || (item.notes?.isEmpty == false) {
                HStack(spacing: 6) {
                    if let pageRangeLabel = item.pageRangeLabel {
                        Text(pageRangeLabel)
                    }
                    if let notes = item.notes, !notes.isEmpty {
                        Text("· \(notes)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { SetlistDetailView(setlistId: 1, title: "Fall Recital 2026") }
}
