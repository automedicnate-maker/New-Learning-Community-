import Foundation

enum StoreError: Error {
    case message(String)

    var text: String {
        switch self { case .message(let msg): return msg }
    }
}

final class LearningDataStore {
    private var users: [User]
    private var courses: [Course]
    private var tests: [Test]
    private var tools: [ToolResource]
    private var announcements: [Announcement]
    private var inviteCodes: [InviteCode]
    private var attempts: [TestAttempt]

    init(users: [User], courses: [Course], tests: [Test], tools: [ToolResource], announcements: [Announcement], inviteCodes: [InviteCode], attempts: [TestAttempt]) {
        self.users = users
        self.courses = courses
        self.tests = tests
        self.tools = tools
        self.announcements = announcements
        self.inviteCodes = inviteCodes
        self.attempts = attempts
    }

    static func bootstrap() -> LearningDataStore {
        let defaultAdmin = User(
            id: UUID(),
            username: "wrenchadmin",
            email: "owner@wrench-platform.local",
            name: "WRENCH Owner",
            role: .admin,
            level: .advanced,
            token: "default-admin-token",
            password: "ChangeMeNow!123"
        )

        return LearningDataStore(
            users: [defaultAdmin],
            courses: [],
            tests: [],
            tools: [],
            announcements: [],
            inviteCodes: [],
            attempts: []
        )
    }

    func hasDefaultAdmin() -> Bool { users.contains { $0.role == .admin } }

    func login(username: String, password: String) -> User? {
        guard let idx = users.firstIndex(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame && $0.password == password }) else {
            return nil
        }
        let newToken = UUID().uuidString
        users[idx].token = newToken
        return users[idx]
    }

    func signup(_ request: SignupRequest) -> Result<User, StoreError> {
        if users.contains(where: { $0.username.caseInsensitiveCompare(request.username) == .orderedSame }) {
            return .failure(.message("Username already exists."))
        }
        if users.contains(where: { $0.email.caseInsensitiveCompare(request.email) == .orderedSame }) {
            return .failure(.message("Email already exists."))
        }

        if request.role == .admin {
            guard let providedCode = request.adminInviteCode?.trimmingCharacters(in: .whitespacesAndNewlines), !providedCode.isEmpty else {
                return .failure(.message("Admin signup requires an invite code."))
            }
            guard let idx = inviteCodes.firstIndex(where: { $0.code == providedCode && $0.usesRemaining > 0 }) else {
                return .failure(.message("Invalid or expired admin invite code."))
            }
            inviteCodes[idx].usesRemaining -= 1
        }

        let user = User(
            id: UUID(),
            username: request.username,
            email: request.email,
            name: request.name,
            role: request.role,
            level: request.level,
            token: UUID().uuidString,
            password: request.password
        )
        users.append(user)
        return .success(user)
    }

    func user(token: String?) -> User? {
        guard let token else { return nil }
        return users.first { $0.token == token }
    }

    func allCourses() -> [Course] { courses }
    func allTests() -> [Test] { tests }
    func allTools() -> [ToolResource] { tools }
    func allAnnouncements() -> [Announcement] { announcements.sorted { $0.createdAt > $1.createdAt } }

    private func passedTestIDs(for user: User) -> Set<UUID> {
        Set(attempts.filter { $0.userID == user.id && $0.passed }.map(\.testID))
    }

    private func canAccess(course: Course, user: User) -> (Bool, String) {
        if user.role == .admin { return (true, "Admin access") }
        if user.level.rawValue < course.requiredStartingLevel.rawValue {
            return (false, "Requires \(course.requiredStartingLevel.label) level")
        }
        let passed = passedTestIDs(for: user)
        let missing = course.requiredPassedTestIDs.filter { !passed.contains($0) }
        if !missing.isEmpty {
            return (false, "Requires passing prerequisite tests")
        }
        return (true, "Unlocked")
    }

    func courseAccessList(for user: User) -> [CourseAccess] {
        courses.filter { $0.isPublished || user.role == .admin }.map {
            let access = canAccess(course: $0, user: user)
            return CourseAccess(course: $0, unlocked: access.0, reason: access.1)
        }
    }

    func dashboard(for user: User) -> DashboardResponse {
        DashboardResponse(
            user: UserProfile(id: user.id, username: user.username, email: user.email, name: user.name, role: user.role, level: user.level),
            courses: courseAccessList(for: user),
            attempts: attempts.filter { $0.userID == user.id }.sorted { $0.submittedAt > $1.submittedAt },
            announcements: allAnnouncements()
        )
    }

    func addTool(_ req: CreateToolRequest) -> ToolResource {
        let tool = ToolResource(id: UUID(), name: req.name, description: req.description, link: req.link)
        tools.append(tool)
        return tool
    }

    func addCourse(_ req: CreateCourseRequest) -> Course {
        let course = Course(
            id: UUID(),
            title: req.title,
            category: req.category,
            description: req.description,
            requiredStartingLevel: req.requiredStartingLevel,
            requiredPassedTestIDs: req.requiredPassedTestIDs,
            sections: req.sections,
            isPublished: req.isPublished
        )
        courses.append(course)
        return course
    }

    func addTest(_ req: CreateTestRequest) -> Result<Test, StoreError> {
        guard courses.contains(where: { $0.id == req.courseID }) else {
            return .failure(.message("courseID not found"))
        }
        let test = Test(id: UUID(), courseID: req.courseID, title: req.title, passingScore: req.passingScore, questions: req.questions)
        tests.append(test)
        return .success(test)
    }

    func addAnnouncement(_ req: CreateAnnouncementRequest) -> Announcement {
        let item = Announcement(id: UUID(), title: req.title, message: req.message, createdAt: Date())
        announcements.append(item)
        return item
    }

    func createInviteCode(uses: Int, adminID: UUID) -> InviteCode {
        let cleanUses = max(1, uses)
        let code = "WRENCH-\(UUID().uuidString.prefix(8).uppercased())"
        let invite = InviteCode(id: UUID(), code: code, usesRemaining: cleanUses, createdByAdminID: adminID, createdAt: Date())
        inviteCodes.append(invite)
        return invite
    }

    func submitTest(user: User, payload: SubmitTestRequest) -> Result<TestAttempt, StoreError> {
        guard let test = tests.first(where: { $0.id == payload.testID }) else {
            return .failure(.message("Test not found"))
        }
        guard payload.selectedOptionIndexes.count == test.questions.count else {
            return .failure(.message("Answer count does not match question count"))
        }

        var correct = 0
        for (idx, q) in test.questions.enumerated() {
            if payload.selectedOptionIndexes[idx] == q.correctOptionIndex { correct += 1 }
        }

        let score = (Double(correct) / Double(max(test.questions.count, 1))) * 100
        let passed = score >= test.passingScore
        let attempt = TestAttempt(id: UUID(), userID: user.id, testID: test.id, score: score, passed: passed, submittedAt: Date())
        attempts.append(attempt)
        return .success(attempt)
    }

    func adminOverview() -> AdminOverview {
        AdminOverview(
            users: users.map { UserProfile(id: $0.id, username: $0.username, email: $0.email, name: $0.name, role: $0.role, level: $0.level) },
            courses: courses,
            tests: tests,
            tools: tools,
            inviteCodes: inviteCodes
        )
    }
}
