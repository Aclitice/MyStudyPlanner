import Foundation
import LocalAuthentication

final class LockManager: ObservableObject {
    @Published var isLocked: Bool
    private let faceIdEnabledKey = "StudyPlanner.FaceIDEnabled"

    init() {
        // 默认开启生物识别锁，但首次进入不强制
        if UserDefaults.standard.object(forKey: faceIdEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: faceIdEnabledKey)
        }
        self.isLocked = false
    }

    var isFaceIdEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: faceIdEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: faceIdEnabledKey) }
    }

    func lock() {
        guard isFaceIdEnabled else { return }
        isLocked = true
    }

    @discardableResult
    func unlockWithBiometrics(reason: String = "解锁以继续") async -> Bool {
        guard isFaceIdEnabled else {
            isLocked = false
            return true
        }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // 无生物识别，直接放行
            isLocked = false
            return true
        }

        do {
            let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { ok, evalError in
                    if let evalError = evalError {
                        continuation.resume(throwing: evalError)
                    } else {
                        continuation.resume(returning: ok)
                    }
                }
            }
            isLocked = !success ? true : false
            return success
        } catch {
            isLocked = true
            return false
        }
    }
}


