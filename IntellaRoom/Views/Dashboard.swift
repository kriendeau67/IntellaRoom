import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject var appState: AppState

    // Hardcoded list for now
    let projects = [
        "General Hospital",
        "Downtown High Rise",
        "Amazon Warehouse"
    ]

    // Navigation state
    @State private var selectedProject: String?

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
                        ForEach(projects, id: \.self) { project in
                            Button {
                                selectedProject = project
                            } label: {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.blue)

                                    Text(project)
                                        .font(.headline)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain) // 🔑 prevents List gesture hijacking
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // MARK: - Add Project Button
                Button {
                    print("Create Project")
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
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        appState.logout()
                    }
                }
            }

            // MARK: - Navigation Destination (SAFE)
            .navigationDestination(item: $selectedProject) { project in
                ProjectMapView()
            }
        }
    }
}
