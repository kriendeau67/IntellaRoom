import SwiftUI
import UniformTypeIdentifiers

struct ProjectDrawingsView: View {
    let project: Project

    @EnvironmentObject var appState: AppState

    @State private var showImporter = false
    @State private var drawingToDelete: Drawing?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Add Drawing", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.pdf]
            ) { result in
                if case let .success(url) = result {
                    do {
                        let drawing = try appState.addDrawing(
                            from: url,
                            to: project
                        )
                        appState.activeDrawingId = drawing.id
                    } catch {
                        print("❌ Failed to import drawing:", error.localizedDescription)
                    }
                }
            }
            .confirmationDialog(
                "Delete Drawing?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Drawing", role: .destructive) {
                    if let drawing = drawingToDelete {
                        appState.deleteDrawing(drawing)
                        drawingToDelete = nil
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    drawingToDelete = nil
                }
            } message: {
                Text("This will permanently delete the drawing, all rooms, and all scans.")
            }
        }
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

                            Menu {
                                Button("Set Active") {
                                    appState.activeDrawingId = drawing.id
                                }

                                Button("Delete", role: .destructive) {
                                    drawingToDelete = drawing
                                    showDeleteConfirmation = true
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}
