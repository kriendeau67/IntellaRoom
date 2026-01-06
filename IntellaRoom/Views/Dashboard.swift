import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var selectedProject: Project?
    @State private var isShowingCreateProject = false
    // Navigation state
   // @State private var selectedProject: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                // MARK: - Header
                VStack(alignment: .leading) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text(appState.currentUser ?? "Foreman")
                        .font(.largeTitle)
                        .bold()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                // MARK: - Project List
                List {
                    Section(header: Text("Your Projects")) {
                        ForEach(appState.projects) { project in
                            Button {
                                selectedProject = project
                            } label: {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.blue)

                                    Text(project.name)
                                        .font(.headline)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // MARK: - Add Project Button
                Button {
                    isShowingCreateProject = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Project")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                }
            }
            .sheet(isPresented: $isShowingCreateProject) {
                CreateProjectView { name, foreman in
                    let project = appState.createProject(
                        name: name,
                        foreman: foreman
                    )
                    selectedProject = project
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        try? authService.signOut()
                    }
                }
            }

            .navigationDestination(item: $selectedProject) { project in
                ProjectDetailView(project: project)
            }   
        }
    }
}
