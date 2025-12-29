//
//  LoginView.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/24/25.
//

import SwiftUI

struct LoginView: View {
    // Access the "Brain" injected from the parent
    @EnvironmentObject var appState: AppState
    
    @State private var username: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
            
            Text("IntellaRoom")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Enter Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .frame(width: 300)
            
            Button(action: {
                // Call the function in the Brain
                appState.login(username: username)
            }) {
                Text("Log In")
                    .bold()
                    .frame(width: 200, height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}


