import SwiftUI
import CoreData

struct GoalsListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        entity: NSEntityDescription.entity(forEntityName: "Goal", in: PersistenceController.shared.container.viewContext)!,
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]
    ) private var goals: FetchedResults<NSManagedObject>
    
    @StateObject private var sharingService = SharingService.shared
    @State private var selectedGoal: NSManagedObject?
    @State private var showShareSheet = false
    @State private var shareMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                if goals.isEmpty {
                    Text("No goals yet. Create one from the Home tab!")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(goals, id: \.self) { goal in
                        GoalRow(goal: goal, onShare: {
                            selectedGoal = goal
                            showShareSheet = true
                        })
                    }
                }
                
                if !shareMessage.isEmpty {
                    Section {
                        Text(shareMessage)
                            .foregroundColor(shareMessage.contains("Success") ? .green : .orange)
                    }
                }
            }
            .navigationTitle("My Goals")
            .sheet(isPresented: $showShareSheet) {
                if let goal = selectedGoal {
                    ShareGoalSheet(
                        goal: goal,
                        sharingService: sharingService,
                        onShareComplete: { shareId in
                            shareMessage = "Success! Share ID: \(shareId)"
                        }
                    )
                }
            }
        }
    }
}

struct GoalRow: View {
    let goal: NSManagedObject
    let onShare: () -> Void
    @Environment(\.managedObjectContext) private var context
    @State private var taskCount = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.value(forKey: "title") as? String ?? "Goal")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
            }
            
            if let deadline = goal.value(forKey: "deadline") as? Date {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("Due: \(deadline, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let targetLevel = goal.value(forKey: "targetLevel") as? String, !targetLevel.isEmpty {
                Text("Target: \(targetLevel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "checklist")
                    .font(.caption)
                Text("\(taskCount) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadTaskCount()
        }
    }
    
    private func loadTaskCount() {
        guard let goalId = goal.value(forKey: "id") as? UUID else { return }
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.predicate = NSPredicate(format: "goalId == %@", goalId as CVarArg)
        taskCount = (try? context.count(for: request)) ?? 0
    }
}

struct ShareGoalSheet: View {
    let goal: NSManagedObject
    @ObservedObject var sharingService: SharingService
    let onShareComplete: (String) -> Void
    
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false
    @State private var shareId: String?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Share Your Study Plan")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let title = goal.value(forKey: "title") as? String {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("This will create a shareable link that others can use to import your study plan.")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Your personal progress and notes will NOT be shared.")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                if let shareId = shareId {
                    VStack(spacing: 8) {
                        Text("Share ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(shareId)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Button(action: {
                            UIPasteboard.general.string = shareId
                        }) {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                    }
                    .padding()
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.orange)
                        .font(.caption)
                        .padding()
                }
                
                Spacer()
                
                if shareId == nil {
                    Button(action: shareGoal) {
                        HStack {
                            if isSharing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Share Plan")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSharing ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSharing)
                    .padding()
                } else {
                    Button("Done") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding()
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func shareGoal() {
        isSharing = true
        errorMessage = nil
        
        Task {
            do {
                let userId = "demo-user" // In production, get from authentication
                let id = try await sharingService.shareGoal(
                    goal: goal,
                    userId: userId,
                    context: context
                )
                
                await MainActor.run {
                    self.shareId = id
                    self.isSharing = false
                    onShareComplete(id)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSharing = false
                }
            }
        }
    }
}
