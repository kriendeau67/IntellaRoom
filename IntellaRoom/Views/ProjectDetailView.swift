import SwiftUI

enum ProjectTab: Hashable {
    case drawings
    case capture
    case reports
}

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: ProjectTab = .capture
   // @State private var drawings: [Drawing] = []
    
  
    private var activeDrawing: Drawing? {
        guard let id = appState.activeDrawingId else { return nil }
        return appState.drawings.first { $0.id == id }
    }
    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: - Drawings
            NavigationStack {
                ProjectDrawingsView(project: project)
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
        
       /* .onAppear {
            if activeDrawingId == nil {
                activeDrawingId = drawings.first?.id
            }
        
        } */
        
    }
}
