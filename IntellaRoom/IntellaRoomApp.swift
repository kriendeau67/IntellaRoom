//
//  IntellaRoomApp.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/24/25.
//

import SwiftUI

@main
struct RoughInInspectorApp: App {
    // 1. Initialize the "Brain" exactly once here.
    // @StateObject ensures it stays alive for the entire life of the app.
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            // 2. The Logic Switch
            // If logged in -> Show Map. If not -> Show Login.
            Group {
                if appState.isLoggedIn {
                    ProjectListView()
                        // Add a transition so it doesn't just snap harshly
                        .transition(.move(edge: .trailing))
                } else {
                    LoginView()
                        .transition(.move(edge: .leading))
                }
            }
            // 3. Inject the Brain into the environment
            // Now EVERY view inside this group can access 'appState'
            .environmentObject(appState)
            .animation(.default, value: appState.isLoggedIn)
        }
    }
}
