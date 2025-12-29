//
//  AppState.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/24/25.
//
import SwiftUI
import Combine

// This is the "Brain" of the app.
// It is an ObservableObject, meaning when it changes, the UI updates automatically.
class AppState: ObservableObject {
    
    // @Published means "Announce this change to the whole app"
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: String? = nil
    @Published var savedScans: [Scan] = []
    // A simple function to simulate logging in (we will connect Firebase later)
    func login(username: String) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.currentUser = username
            self.isLoggedIn = true
        }
    }
    
    func logout() {
        self.currentUser = nil
        self.isLoggedIn = false
    }
    // Updated Helper
    func addScan(
        id: UUID,
        roomName: String,
        x: Int,
        y: Int,
        imageFileNames: [String]
    ) {
        let newScan = Scan(
            id: id,
            roomName: roomName,
            x: x,
            y: y,
            date: Date(),
            imageFileNames: imageFileNames
        )

        savedScans.append(newScan)

        print("💾 Scan saved! Room: \(roomName), Images: \(imageFileNames.count)")
    }
}
