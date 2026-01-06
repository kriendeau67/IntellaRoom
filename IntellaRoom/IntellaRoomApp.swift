//
//  IntellaRoomApp.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/24/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth


@main
struct IntellaRoomApp: App {
    
   
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            // 2. The Logic Switch
            // If logged in -> Show Map. If not -> Show Login.
            Group {
                if appState.isLoggedIn {
                    ProjectListView()
                        .onAppear {
                                            appState.loadProjectsForCurrentUser()
                                        }
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
            .environmentObject(authService)
            .onReceive(authService.$user) { user in
                appState.isLoggedIn = (user != nil)
                appState.currentUser = user?.displayName ?? user?.email ?? "User"
            }
            .animation(.default, value: appState.isLoggedIn)
        }
    }
}
