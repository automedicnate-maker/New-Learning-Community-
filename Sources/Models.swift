import Foundation

enum UserRole: String, Codable {
    case admin
    case learner
}

enum SkillLevel: Int, Codable, CaseIterable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3

    var label: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

struct User: Codable {
    let id: UUID
    var username: String
    var email: String
    var name: String
    var role: UserRole
    var level: SkillLevel
    var token: String
    var password: String
}

struct ToolResource: Codable {
    let id: UUID
    var name: String
    var description: String
    var link: String
}

struct Chapter: Codable {
    let id: UUID
    var title: String
    var contentMarkdown: String
    var toolIDs: [UUID]
}

struct Section: Codable {
    let id: UUID
    var title: String
    var chapters: [Chapter]
}

struct Course: Codable {
    let id: UUID
    var title: String
    var category: String
    var description: String
    var requiredStartingLevel: SkillLevel
    var requiredPassedTestIDs: [UUID]
    var sections: [Section]
    var isPublished: Bool
}

struct TestQuestion: Codable {
    let id: UUID
    var prompt: String
    var options: [String]
    var correctOptionIndex: Int
}

struct Test: Codable {
    let id: UUID
    var courseID: UUID
    var title: String
    var passingScore: Double
    var questions: [TestQuestion]
}

struct Announcement: Codable {
    let id: UUID
    var title: String
    var message: String
    var createdAt: Date
}

struct InviteCode: Codable {
    let id: UUID
    var code: String
    var usesRemaining: Int
    var createdByAdminID: UUID
    var createdAt: Date
}

struct TestAttempt: Codable {
    let id: UUID
    let userID: UUID
    let testID: UUID
    let score: Double
    let passed: Bool
    let submittedAt: Date
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct SignupRequest: Codable {
    let username: String
    let password: String
    let email: String
    let name: String
    let level: SkillLevel
    let role: UserRole
    let adminInviteCode: String?
}

struct LoginResponse: Codable {
    let token: String
    let role: UserRole
    let name: String
    let username: String
    let level: SkillLevel
}

struct PublicBootstrapResponse: Codable {
    let platformName: String
    let hasDefaultAdmin: Bool
}

struct UserProfile: Codable {
    let id: UUID
    let username: String
    let email: String
    let name: String
    let role: UserRole
    let level: SkillLevel
}

struct CourseAccess: Codable {
    let course: Course
    let unlocked: Bool
    let reason: String
}

struct DashboardResponse: Codable {
    let user: UserProfile
    let courses: [CourseAccess]
    let attempts: [TestAttempt]
    let announcements: [Announcement]
}

struct CreateInviteCodeRequest: Codable {
    let uses: Int
}

struct CreateToolRequest: Codable {
    let name: String
    let description: String
    let link: String
}

struct CreateCourseRequest: Codable {
    let title: String
    let category: String
    let description: String
    let requiredStartingLevel: SkillLevel
    let requiredPassedTestIDs: [UUID]
    let sections: [Section]
    let isPublished: Bool
}

struct CreateTestRequest: Codable {
    let courseID: UUID
    let title: String
    let passingScore: Double
    let questions: [TestQuestion]
}

struct CreateAnnouncementRequest: Codable {
    let title: String
    let message: String
}

struct SubmitTestRequest: Codable {
    let testID: UUID
    let selectedOptionIndexes: [Int]
}

struct AdminOverview: Codable {
    let users: [UserProfile]
    let courses: [Course]
    let tests: [Test]
    let tools: [ToolResource]
    let inviteCodes: [InviteCode]
}
