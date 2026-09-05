//
//  ContentView.swift
//  PiTutti Setlist App
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                LibraryView()
            }
            .tabItem { Label("Library", systemImage: "magnifyingglass") }

            NavigationStack {
                SetlistsView()
            }
            .tabItem { Label("Setlists", systemImage: "music.note.list") }
        }
    }
}

#Preview {
    ContentView()
}
