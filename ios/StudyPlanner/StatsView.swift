import SwiftUI
import CoreData
import Charts

struct StatsView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var analytics: StudyAnalytics?
    @State private var selectedPeriod: AnalyticsPeriod = .week
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                Picker("Period", selection: $selectedPeriod) {
                    Text("Week").tag(AnalyticsPeriod.week)
                    Text("Month").tag(AnalyticsPeriod.month)
                    Text("Year").tag(AnalyticsPeriod.year)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedPeriod) { _ in
                    loadAnalytics()
                }
                
                if let analytics = analytics {
                    // Summary cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Study Time",
                            value: formatMinutes(analytics.totalStudyMinutes),
                            icon: "clock.fill",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Tasks Done",
                            value: "\(analytics.tasksCompleted)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Streak",
                            value: "\(analytics.studyStreak) days",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Focus Score",
                            value: String(format: "%.0f%%", analytics.averageFocusScore * 100),
                            icon: "brain.head.profile",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    // Weekly progress chart
                    if !analytics.weeklyProgress.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Daily Progress")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(analytics.weeklyProgress, id: \.date) { progress in
                                BarMark(
                                    x: .value("Day", progress.date, unit: .day),
                                    y: .value("Minutes", progress.minutes)
                                )
                                .foregroundStyle(.blue.gradient)
                            }
                            .frame(height: 200)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Goal progress
                    if !analytics.goalProgress.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Goal Progress")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(analytics.goalProgress, id: \.goalId) { goal in
                                GoalProgressRow(progress: goal)
                            }
                        }
                    }
                } else if isLoading {
                    ProgressView("Loading analytics...")
                        .padding()
                } else {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Statistics")
        .onAppear {
            loadAnalytics()
        }
    }
    
    private func loadAnalytics() {
        isLoading = true
        Task {
            do {
                let result = try await AnalyticsService.shared.getAnalytics(for: selectedPeriod, context: context)
                await MainActor.run {
                    self.analytics = result
                    self.isLoading = false
                }
            } catch {
                print("Failed to load analytics: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct GoalProgressRow: View {
    let progress: GoalProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.goalTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(progress.completedTasks)/\(progress.totalTasks)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress.completionPercentage, total: 100.0)
                .tint(.blue)
            
            HStack {
                Text(String(format: "%.0f%% complete", progress.completionPercentage))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(progress.totalMinutes) min total")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
