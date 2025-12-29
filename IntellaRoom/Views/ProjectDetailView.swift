import SwiftUI

enum ProjectTab: Hashable {
    case info
    case capture
    case reports
}

struct ProjectDetailView: View {
    let project: Project

    @State private var selectedTab: ProjectTab = .capture
    @State private var drawings: [Drawing] = [
        Drawing(
            id: UUID(),
            name: "Sample Drawing",
            url: Bundle.main.url(forResource: "sample", withExtension: "pdf")!
        )
    ]

    @State private var activeDrawingId: UUID?
    private var activeDrawing: Drawing? {
        drawings.first { $0.id == activeDrawingId }
    }
    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: - Info
            NavigationStack {
                VStack(spacing: 16) {
                    Text(project.name)
                        .font(.largeTitle)
                        .bold()

                    Text("Foreman: \(project.foreman)")
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding()
                .navigationTitle("Info")
                
                .safeAreaInset(edge: .top) {
                            Divider()
                        }
            }
            .tabItem {
                Label("Info", systemImage: "info.circle")
            }
            .tag(ProjectTab.info)

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
        .onAppear {
            if activeDrawingId == nil {
                activeDrawingId = drawings.first?.id
            }
        }
        
    }
}
