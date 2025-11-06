import SwiftUI
import CoreData

struct CommunityView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var sharingService = SharingService.shared
    @State private var communityGoals: [CommunityGoal] = []
    @State private var isLoading = false
    @State private var showImportSheet = false
    @State private var selectedGoal: CommunityGoal?
    @State private var shareIdInput = ""
    @State private var message = ""
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            List {
                // Import by Share ID
                Section(header: Text("Import Shared Plan")) {
                    HStack {
                        TextField("Enter share ID", text: $shareIdInput)
                            .textInputAutocapitalization(.never)
                        
                        Button("Import") {
                            importByShareId()
                        }
                        .disabled(shareIdInput.isEmpty || sharingService.isSharing)
                    }
                }
                
                if !message.isEmpty {
                    Section {
                        Text(message)
                            .foregroundColor(message.contains("Success") ? .green : .red)
                    }
                }
                
                // Community Goals
                Section(header: Text("Popular Study Plans")) {
                    if isLoading {
                        ProgressView()
                    } else if communityGoals.isEmpty {
                        Text("No community goals available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(communityGoals) { goal in
                            CommunityGoalRow(goal: goal) {
                                selectedGoal = goal
                                showImportSheet = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Community")
            .refreshable {
                await loadCommunityGoals()
            }
            .onAppear {
                if communityGoals.isEmpty {
                    Task { await loadCommunityGoals() }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                if let goal = selectedGoal {
                    ImportGoalSheet(goal: goal, onImport: {
                        importCommunityGoal(goal)
                    })
                }
            }
        }
    }
    
    private func loadCommunityGoals() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let goals = try await CommunityAPIClient.shared.fetchCommunityGoals()
            await MainActor.run {
                self.communityGoals = goals
            }
        } catch {
            await MainActor.run {
                message = "Failed to load: \(error.localizedDescription)"
            }
        }
    }
    
    private func importByShareId() {
        message = ""
        Task {
            do {
                try await sharingService.importSharedPlan(
                    shareId: shareIdInput,
                    persona: appState.persona,
                    context: context
                )
                await MainActor.run {
                    message = "Success! Plan imported to your goals."
                    shareIdInput = ""
                }
            } catch {
                await MainActor.run {
                    message = error.localizedDescription
                }
            }
        }
    }
    
    private func importCommunityGoal(_ goal: CommunityGoal) {
        message = ""
        do {
            try sharingService.importCommunityGoal(goal, persona: appState.persona, context: context)
            message = "Success! '\(goal.title)' added to your goals."
            showImportSheet = false
        } catch {
            message = "Failed to import: \(error.localizedDescription)"
        }
    }
}

struct CommunityGoalRow: View {
    let goal: CommunityGoal
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goal.title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                }
                
                if let description = goal.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Label("\(goal.likes)", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Label("\(goal.shares)", systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(goal.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(goal.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct ImportGoalSheet: View {
    let goal: CommunityGoal
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(goal.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = goal.description {
                        Text(description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Author")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(goal.authorName)
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Category")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(goal.category)
                                .font(.subheadline)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Label("\(goal.likes) likes", systemImage: "heart.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Label("\(goal.shares) shares", systemImage: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                    
                    HStack {
                        ForEach(goal.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        onImport()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Import This Plan")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Import Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
