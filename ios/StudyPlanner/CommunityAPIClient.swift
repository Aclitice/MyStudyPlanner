import Foundation

// MARK: - API Models

struct CommunityGoal: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let authorName: String
    let authorId: String
    let category: String
    let likes: Int
    let shares: Int
    let createdAt: Date
    let tags: [String]
}

struct SharedPlan: Codable {
    let goalTitle: String
    let tasks: [SharedTask]
    let estimatedDays: Int
    let category: String
}

struct SharedTask: Codable {
    let title: String
    let estimatedMinutes: Int
    let type: String
    let difficulty: Int
    let order: Int
}

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
}

// MARK: - API Client

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case unauthorized
    case notImplemented
}

final class CommunityAPIClient {
    static let shared = CommunityAPIClient()
    
    private let baseURL: String
    private let session: URLSession
    
    private init() {
        self.baseURL = AppConfig.communityAPIBaseURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Browse Community Goals
    
    func fetchCommunityGoals(category: String? = nil, page: Int = 1, limit: Int = 20) async throws -> [CommunityGoal] {
        // Placeholder: return mock data since API is not implemented
        return generateMockCommunityGoals()
    }
    
    func searchGoals(query: String, page: Int = 1) async throws -> [CommunityGoal] {
        // Placeholder
        return generateMockCommunityGoals().filter { 
            $0.title.localizedCaseInsensitiveContains(query) 
        }
    }
    
    // MARK: - Share Plans
    
    func sharePlan(_ plan: SharedPlan, userId: String) async throws -> String {
        // Placeholder: simulate API call
        guard baseURL != "https://api.example.com" else {
            throw APIError.notImplemented
        }
        
        guard let url = URL(string: "\(baseURL)/v1/plans/share") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(userId)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(plan)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse<[String: String]>.self, from: data)
        
        guard apiResponse.success, let shareId = apiResponse.data?["shareId"] else {
            throw APIError.serverError(apiResponse.message ?? "Unknown error")
        }
        
        return shareId
    }
    
    // MARK: - Import Shared Plans
    
    func importSharedPlan(shareId: String) async throws -> SharedPlan {
        // Placeholder: simulate API call
        guard baseURL != "https://api.example.com" else {
            throw APIError.notImplemented
        }
        
        guard let url = URL(string: "\(baseURL)/v1/plans/\(shareId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse<SharedPlan>.self, from: data)
        
        guard apiResponse.success, let plan = apiResponse.data else {
            throw APIError.serverError(apiResponse.message ?? "Plan not found")
        }
        
        return plan
    }
    
    // MARK: - Like/Unlike
    
    func likeGoal(goalId: UUID, userId: String) async throws {
        // Placeholder
        try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
    }
    
    func unlikeGoal(goalId: UUID, userId: String) async throws {
        // Placeholder
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    // MARK: - Mock Data
    
    private func generateMockCommunityGoals() -> [CommunityGoal] {
        [
            CommunityGoal(
                id: UUID(),
                title: "Master iOS Development with SwiftUI",
                description: "Complete guide to building iOS apps from scratch",
                authorName: "John Developer",
                authorId: "user123",
                category: "Programming",
                likes: 245,
                shares: 89,
                createdAt: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                tags: ["iOS", "SwiftUI", "Mobile"]
            ),
            CommunityGoal(
                id: UUID(),
                title: "Prepare for IELTS 7.5+",
                description: "3-month intensive IELTS preparation plan",
                authorName: "Sarah Teacher",
                authorId: "user456",
                category: "Language",
                likes: 312,
                shares: 156,
                createdAt: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                tags: ["IELTS", "English", "Exam"]
            ),
            CommunityGoal(
                id: UUID(),
                title: "Complete Machine Learning Specialization",
                description: "Andrew Ng's ML course + practical projects",
                authorName: "AI Enthusiast",
                authorId: "user789",
                category: "AI/ML",
                likes: 523,
                shares: 234,
                createdAt: Date().addingTimeInterval(-21 * 24 * 60 * 60),
                tags: ["ML", "AI", "Python"]
            ),
            CommunityGoal(
                id: UUID(),
                title: "Project Management Professional (PMP) Certification",
                description: "6-week PMP exam preparation roadmap",
                authorName: "PM Pro",
                authorId: "user101",
                category: "Professional",
                likes: 187,
                shares: 92,
                createdAt: Date().addingTimeInterval(-3 * 24 * 60 * 60),
                tags: ["PMP", "Management", "Certification"]
            )
        ]
    }
}
