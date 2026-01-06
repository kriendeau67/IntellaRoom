//
//  LoginView.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/24/25.
//


    
    import SwiftUI
    import GoogleSignInSwift
    import AuthenticationServices
    import Combine

    struct LoginView: View {
        @EnvironmentObject var appState: AppState
        @State private var username: String = ""

        @EnvironmentObject var auth: AuthService
        @State private var appleRequest: ASAuthorizationAppleIDRequest?

        var body: some View {
            ZStack {
                backgroundBolt
                centeredContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .padding()
        }

        // MARK: - Background Anchor

        private var backgroundBolt: some View {
            Image(systemName: "bolt.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 280)
                .foregroundColor(Color.primary.opacity(0.06))
                .rotationEffect(.degrees(-12))
                .accessibilityHidden(true)
        }

        // MARK: - Centered Content

        private var centeredContent: some View {
            VStack(spacing: 18) {

                Text("IntellaRoom")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                (
                    Text("Built for electricians. ")
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                )
                .font(.subheadline)

                Text("Scan panel schedules and instantly generate structured Excel files.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                GoogleSignInButton {
                    signInWithGoogle()
                }
                .frame(width: 260, height: 50)

                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        self.appleRequest = auth.startSignInWithAppleFlow()
                        if let appleRequest = self.appleRequest {
                            request.requestedScopes = appleRequest.requestedScopes
                            request.nonce = appleRequest.nonce
                        }
                    },
                    onCompletion: { result in
                        Task {
                            try? await auth.handleAppleCompletion(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(width: 260, height: 50)

                Spacer().frame(height: 28)

                Text("Sign in to access your projects across devices.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 420)
        }

        // MARK: - Google Sign In Helper

        private func signInWithGoogle() {
            guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.keyWindow?.rootViewController else { return }

            Task {
                try? await auth.signInWithGoogle(presenting: rootVC)
            }
        }
    }




