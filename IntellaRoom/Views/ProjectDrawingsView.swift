import SwiftUI
import UniformTypeIdentifiers

struct ProjectDrawingsView: View {
    let project: Project

    @EnvironmentObject var appState: AppState

    @Binding var drawingToDelete: Drawing?
       @Binding var showDeleteConfirmation: Bool

       @State private var showImporter = false
    
    var body: some View {
    
            VStack(spacing: 12) {
                
                // Project Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.title2)
                        .bold()
                    
                    Text("Foreman: \(project.foreman)")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Divider()
                
                drawingsContent
            }
            .navigationTitle("Drawings")
            .navigationBarTitleDisplayMode(.inline)
           
            
                
           
        
    }

    // MARK: - Content

    private var drawingsContent: some View {
        let drawings = appState.drawings(for: project)

        return Group {
            if drawings.isEmpty {
                ContentUnavailableView(
                    "No Drawings",
                    systemImage: "doc",
                    description: Text("Add a drawing to begin capturing rooms.")
                )
            } else {
                List {
                    ForEach(drawings) { drawing in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(drawing.name)
                                    .font(.headline)

                                if drawing.id == appState.activeDrawingId {
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }

                            Spacer()

                            
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                appState.activeDrawingId = drawing.id
                            } label: {
                                Text("Set Active")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                drawingToDelete = drawing
                                showDeleteConfirmation = true
                            } label: {
                                Text("Delete")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}
