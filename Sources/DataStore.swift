import Foundation

enum StoreError: Error {
    case message(String)

    var text: String {
        switch self { case .message(let msg): return msg }
    }
}

final class LearningDataStore {
    private var users: [User]
    private var communities: [Community]
    private var communityMembers: [CommunityMember]
    private var courses: [Course]
    private var tests: [Test]
    private var tools: [ToolResource]
    private var announcements: [Announcement]
    private var inviteCodes: [InviteCode]
    private var attempts: [TestAttempt]

    init(users: [User], communities: [Community], communityMembers: [CommunityMember], courses: [Course], tests: [Test], tools: [ToolResource], announcements: [Announcement], inviteCodes: [InviteCode], attempts: [TestAttempt]) {
        self.users = users
        self.communities = communities
        self.communityMembers = communityMembers
        self.courses = courses
        self.tests = tests
        self.tools = tools
        self.announcements = announcements
        self.inviteCodes = inviteCodes
        self.attempts = attempts
    }

    static func bootstrap() -> LearningDataStore {
        let automotiveCommunity = Community(
            id: UUID(),
            slug: "automotive",
            name: "Automotive",
            description: "Automotive diagnostics and technician training campus.",
            brandingConfig: ["primaryColor": "#2563eb", "logo": "wrench"],
            status: .active
        )

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

        let defaultAdminMembership = CommunityMember(
            id: UUID(),
            communityID: automotiveCommunity.id,
            userID: defaultAdmin.id,
            role: .admin,
            joinedAt: Date()
        )

        return LearningDataStore(
            users: [defaultAdmin],
            communities: [automotiveCommunity],
            communityMembers: [defaultAdminMembership],
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

        let desiredSlug = request.communitySlug?.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultSlug = (desiredSlug?.isEmpty == false) ? desiredSlug! : "automotive"
        guard let community = community(for: defaultSlug) else {
            users.removeAll { $0.id == user.id }
            return .failure(.message("Selected community not found."))
        }
        let role: CommunityRole = request.role == .admin ? .admin : .learner
        communityMembers.append(CommunityMember(id: UUID(), communityID: community.id, userID: user.id, role: role, joinedAt: Date()))

        return .success(user)
    }

    func user(token: String?) -> User? {
        guard let token else { return nil }
        return users.first { $0.token == token }
    }

    func allCommunities(for user: User) -> [Community] {
        let allowedIDs = Set(communityMembers.filter { $0.userID == user.id }.map(\.communityID))
        return communities.filter { allowedIDs.contains($0.id) }
    }

    func allCourses(in communityID: UUID) -> [Course] { courses.filter { $0.communityID == communityID } }
    func allTests(in communityID: UUID) -> [Test] { tests.filter { $0.communityID == communityID } }
    func allTools(in communityID: UUID) -> [ToolResource] { tools.filter { $0.communityID == communityID } }
    func allAnnouncements(in communityID: UUID) -> [Announcement] { announcements.filter { $0.communityID == communityID }.sorted { $0.createdAt > $1.createdAt } }

    func community(for slug: String) -> Community? {
        communities.first { $0.slug.caseInsensitiveCompare(slug) == .orderedSame }
    }

    func accessibleCommunity(for user: User, slug: String?) -> Community? {
        let memberships = communityMembers.filter { $0.userID == user.id }
        guard !memberships.isEmpty else { return nil }
        if let slug {
            guard let requested = community(for: slug) else { return nil }
            return memberships.contains(where: { $0.communityID == requested.id }) ? requested : nil
        }
        return communities.first { community in memberships.contains(where: { $0.communityID == community.id }) }
    }

    private func passedTestIDs(for user: User, communityID: UUID) -> Set<UUID> {
        let testIDsInCommunity = Set(allTests(in: communityID).map(\.id))
        return Set(
            attempts
                .filter { $0.userID == user.id && $0.passed && testIDsInCommunity.contains($0.testID) }
                .map(\.testID)
        )
    }

    private func canAccess(course: Course, user: User, communityID: UUID) -> (Bool, String) {
        if user.role == .admin { return (true, "Admin access") }
        if user.level.rawValue < course.requiredStartingLevel.rawValue {
            return (false, "Requires \(course.requiredStartingLevel.label) level")
        }
        let passed = passedTestIDs(for: user, communityID: communityID)
        let missing = course.requiredPassedTestIDs.filter { !passed.contains($0) }
        if !missing.isEmpty {
            return (false, "Requires passing prerequisite tests")
        }
        return (true, "Unlocked")
    }

    func courseAccessList(for user: User, communityID: UUID) -> [CourseAccess] {
        allCourses(in: communityID).filter { $0.isPublished || user.role == .admin }.map {
            let access = canAccess(course: $0, user: user, communityID: communityID)
            return CourseAccess(course: $0, unlocked: access.0, reason: access.1)
        }
    }

    func dashboard(for user: User, community: Community) -> DashboardResponse {
        let testIDsInCommunity = Set(allTests(in: community.id).map(\.id))
        return DashboardResponse(
            user: UserProfile(id: user.id, username: user.username, email: user.email, name: user.name, role: user.role, level: user.level),
            activeCommunity: community,
            courses: courseAccessList(for: user, communityID: community.id),
            attempts: attempts.filter { $0.userID == user.id && testIDsInCommunity.contains($0.testID) }.sorted { $0.submittedAt > $1.submittedAt },
            announcements: allAnnouncements(in: community.id)
        )
    }

    func addTool(_ req: CreateToolRequest) -> Result<ToolResource, StoreError> {
        guard let community = community(for: req.communitySlug) else {
            return .failure(.message("community not found"))
        }
        let tool = ToolResource(id: UUID(), communityID: community.id, name: req.name, description: req.description, link: req.link)
        tools.append(tool)
        return .success(tool)
    }

    func addCourse(_ req: CreateCourseRequest) -> Result<Course, StoreError> {
        guard let community = community(for: req.communitySlug) else {
            return .failure(.message("community not found"))
        }
        let course = Course(
            id: UUID(),
            communityID: community.id,
            title: req.title,
            category: req.category,
            description: req.description,
            requiredStartingLevel: req.requiredStartingLevel,
            requiredPassedTestIDs: req.requiredPassedTestIDs,
            sections: req.sections,
            isPublished: req.isPublished
        )
        courses.append(course)
        return .success(course)
    }

    func addTest(_ req: CreateTestRequest) -> Result<Test, StoreError> {
        guard let community = community(for: req.communitySlug) else {
            return .failure(.message("community not found"))
        }
        guard courses.contains(where: { $0.id == req.courseID && $0.communityID == community.id }) else {
            return .failure(.message("courseID not found"))
        }
        let test = Test(id: UUID(), communityID: community.id, courseID: req.courseID, title: req.title, passingScore: req.passingScore, questions: req.questions)
        tests.append(test)
        return .success(test)
    }

    func addAnnouncement(_ req: CreateAnnouncementRequest) -> Result<Announcement, StoreError> {
        guard let community = community(for: req.communitySlug) else {
            return .failure(.message("community not found"))
        }
        let item = Announcement(id: UUID(), communityID: community.id, title: req.title, message: req.message, createdAt: Date())
        announcements.append(item)
        return .success(item)
    }

    func createCommunity(_ req: CreateCommunityRequest) -> Result<Community, StoreError> {
        let normalizedSlug = req.slug.lowercased()
        guard !normalizedSlug.isEmpty else { return .failure(.message("slug cannot be empty")) }
        guard communities.allSatisfy({ $0.slug != normalizedSlug }) else {
            return .failure(.message("community slug already exists"))
        }
        let community = Community(id: UUID(), slug: normalizedSlug, name: req.name, description: req.description, brandingConfig: req.brandingConfig, status: req.status)
        communities.append(community)
        return .success(community)
    }

    func addCommunityMember(_ req: CreateCommunityMemberRequest) -> Result<CommunityMember, StoreError> {
        guard let community = community(for: req.communitySlug) else {
            return .failure(.message("community not found"))
        }
        guard let user = users.first(where: { $0.username.caseInsensitiveCompare(req.username) == .orderedSame }) else {
            return .failure(.message("user not found"))
        }
        if communityMembers.contains(where: { $0.communityID == community.id && $0.userID == user.id }) {
            return .failure(.message("user already belongs to this community"))
        }
        let membership = CommunityMember(id: UUID(), communityID: community.id, userID: user.id, role: req.role, joinedAt: Date())
        communityMembers.append(membership)
        return .success(membership)
    }

    func createInviteCode(uses: Int, adminID: UUID) -> InviteCode {
        let cleanUses = max(1, uses)
        let code = "WRENCH-\(UUID().uuidString.prefix(8).uppercased())"
        let invite = InviteCode(id: UUID(), code: code, usesRemaining: cleanUses, createdByAdminID: adminID, createdAt: Date())
        inviteCodes.append(invite)
        return invite
    }

    func submitTest(user: User, payload: SubmitTestRequest, communityID: UUID) -> Result<TestAttempt, StoreError> {
        guard let test = tests.first(where: { $0.id == payload.testID }) else {
            return .failure(.message("Test not found"))
        }
        guard test.communityID == communityID else {
            return .failure(.message("Test is not in the active community"))
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
            communities: communities,
            communityMembers: communityMembers,
            users: users.map { UserProfile(id: $0.id, username: $0.username, email: $0.email, name: $0.name, role: $0.role, level: $0.level) },
            courses: courses,
            tests: tests,
            tools: tools,
            inviteCodes: inviteCodes
        )
    }
}
