//
//  RoomNamePromptView.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/28/25.
//

import SwiftUI

struct RoomNamePromptView: View {
    @Binding var roomName: String
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter Room Name")
                    .font(.title2)
                    .bold()

                TextField("e.g. Room 102, Deli Counter", text: $roomName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button {
                    guard !roomName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onConfirm()
                } label: {
                    Text("Start Scan")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Room")
        }
    }
}
