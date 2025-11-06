import Foundation

final class AppState: ObservableObject {
    @Published var persona: String {
        didSet { UserDefaults.standard.set(persona, forKey: "StudyPlanner.persona") }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "StudyPlanner.onboardingCompleted") }
    }

    init() {
        let storedPersona = UserDefaults.standard.string(forKey: "StudyPlanner.persona") ?? "student"
        let storedOnboarding = UserDefaults.standard.object(forKey: "StudyPlanner.onboardingCompleted") as? Bool ?? false
        self.persona = storedPersona
        self.hasCompletedOnboarding = storedOnboarding
    }
}


