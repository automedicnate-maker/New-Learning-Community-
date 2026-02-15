import Foundation

enum UserRole: String, Codable {
    case admin
    case learner
}

struct User: Codable {
    let id: UUID
    let email: String
    let name: String
    let role: UserRole
    let token: String
}

struct Course: Codable {
    let id: UUID
    var title: String
    var category: String
    var description: String
    var modules: [String]
    var isPublished: Bool
}

struct TestQuestion: Codable {
    let prompt: String
    let options: [String]
    let correctOptionIndex: Int
}

struct Test: Codable {
    let id: UUID
    let courseID: UUID
    var title: String
    var questions: [TestQuestion]
}

struct Announcement: Codable {
    let id: UUID
    var title: String
    var message: String
    let createdAt: Date
}

struct Page: Codable {
    let id: UUID
    var title: String
    var slug: String
    var contentMarkdown: String
}

struct ToolbarLink: Codable {
    let id: UUID
    var label: String
    var path: String
}

struct Score: Codable {
    let id: UUID
    let userID: UUID
    let testID: UUID
    var value: Double
    let completedAt: Date
}

struct Achievement: Codable {
    let id: UUID
    let userID: UUID
    var title: String
    var summary: String
}

struct LoginRequest: Codable {
    let email: String
}

struct LoginResponse: Codable {
    let token: String
    let role: UserRole
    let name: String
}

struct PlatformSnapshot: Codable {
    let courses: [Course]
    let tests: [Test]
    let announcements: [Announcement]
    let pages: [Page]
    let toolbar: [ToolbarLink]
}

struct AdminBootstrapResponse: Codable {
    let message: String
    let defaults: PlatformSnapshot
}

struct LearnerDashboard: Codable {
    let user: User
    let scores: [Score]
    let achievements: [Achievement]
    let availableCourses: [Course]
}
