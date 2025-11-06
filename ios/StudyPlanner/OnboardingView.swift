import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Text("你是学生还是职场人？").font(.headline)
            Picker("Persona", selection: $appState.persona) {
                Text("学生").tag("student")
                Text("职场人").tag("professional")
            }
            .pickerStyle(.segmented)
            Button("开始使用") { appState.hasCompletedOnboarding = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}


