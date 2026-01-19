import SwiftUI
import UniformTypeIdentifiers

enum ProjectTab: Hashable {
    case drawings
    case capture
    case reports
}

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: ProjectTab = .capture
    @State private var showDrawingImporter = false
    @State private var drawingToDelete: Drawing?
    @State private var showDeleteConfirmation = false
    
    private var activeDrawing: Drawing? {
        guard let id = appState.activeDrawingId else { return nil }
        return appState.drawings.first { $0.id == id }
    }
    
    var body: some View {
        // We removed the outer NavigationStack because Dashboard (ProjectListView) already has one.
        TabView(selection: $selectedTab) {
            
            // MARK: - Drawings
            NavigationStack {
                ProjectDrawingsView(
                    project: project,
                    drawingToDelete: $drawingToDelete,
                    showDeleteConfirmation: $showDeleteConfirmation
                )
                .environmentObject(appState)
            }
            .tabItem {
                Label("Drawings", systemImage: "doc")
            }
            .tag(ProjectTab.drawings)
            
            // MARK: - Capture
            NavigationStack {
                Group {
                    if let drawing = activeDrawing {
                        ProjectCaptureView(drawing: drawing)
                            .id(drawing.id)
                            .navigationTitle("Capture")
                            .safeAreaInset(edge: .top) {
                                Divider()
                            }
                    } else {
                        ContentUnavailableView(
                            "No Active Drawing",
                            systemImage: "doc",
                            description: Text("Select a drawing in the Drawings tab to begin capturing.")
                        )
                        .navigationTitle("Capture")
                    }
                }
            }
            .tabItem {
                Label("Capture", systemImage: "camera.viewfinder")
            }
            .tag(ProjectTab.capture)
            
            // MARK: - Reports
            NavigationStack {
                ProjectReportView()
                    .navigationTitle("Reports")
                    .safeAreaInset(edge: .top) {
                        Divider()
                    }
            }
            .tabItem {
                Label("Reports", systemImage: "doc.text")
            }
            .tag(ProjectTab.reports)
        }
        // MODIFIERS START HERE
        // Setting the title here connects it to the Dashboard's NavigationStack
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if appState.drawings.isEmpty {
                Task {
                    await appState.loadDrawings(for: project)
                    appState.loadRooms(for: project)
                }
            }
        }
        // Placing the toolbar on the TabView (which is the root of this file)
        // allows the "Add" button to appear correctly without ghosting.
        .toolbar {
            if selectedTab == .drawings {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDrawingImporter = true
                    } label: {
                        Label("Add Drawing", systemImage: "plus")
                    }
                }
            }
        }
        // Sheet-like modifiers (dialogs and importers) work best at the very bottom
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
        .fileImporter(
            isPresented: $showDrawingImporter,
            allowedContentTypes: [.pdf]
        ) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                
                Task {
                    do {
                        let drawing = try await appState.addDrawing(from: url, to: project)
                        appState.activeDrawingId = drawing.id
                    } catch {
                        print("❌ Failed to import drawing: \(error.localizedDescription)")
                    }
                }
            case .failure(let error):
                print("❌ Picker error: \(error.localizedDescription)")
            }
        }
    }
}
