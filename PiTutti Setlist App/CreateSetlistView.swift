//
//  CreateSetlistView.swift
//  PiTutti Setlist App
//

import SwiftUI

struct CreateSetlistView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var isSaving = false

    let onCreate: (String, String?) async -> Void

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Setlist title", text: $title)
                }
                Section("Description") {
                    TextField("Optional", text: $description, axis: .vertical)
                }
            }
            .navigationTitle("New Setlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            isSaving = true
                            await onCreate(trimmedTitle, description.isEmpty ? nil : description)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(trimmedTitle.isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
        }
    }
}

#Preview {
    CreateSetlistView { _, _ in }
}
