//
//  CreateProjectView.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/29/25.
//
import SwiftUI

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var foreman = ""

    let onCreate: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Project Name", text: $name)
                TextField("Foreman", text: $foreman)
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        onCreate(name, foreman)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
