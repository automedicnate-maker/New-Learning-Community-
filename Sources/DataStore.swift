import Foundation

final class LearningDataStore {
    private var users: [User]
    private var courses: [Course]
    private var tests: [Test]
    private var announcements: [Announcement]
    private var pages: [Page]
    private var toolbar: [ToolbarLink]
    private var scores: [Score]
    private var achievements: [Achievement]

    init(
        users: [User],
        courses: [Course],
        tests: [Test],
        announcements: [Announcement],
        pages: [Page],
        toolbar: [ToolbarLink],
        scores: [Score],
        achievements: [Achievement]
    ) {
        self.users = users
        self.courses = courses
        self.tests = tests
        self.announcements = announcements
        self.pages = pages
        self.toolbar = toolbar
        self.scores = scores
        self.achievements = achievements
    }

    static func bootstrap() -> LearningDataStore {
        let admin = User(
            id: UUID(),
            username: "admin",
            email: "admin@frenchmonkeys.io",
            name: "French Monkeys Admin",
            role: .admin,
            token: "admin-token",
            password: "ChangeMeNow!123"
        )
        let learner = User(
            id: UUID(),
            username: "learner1",
            email: "student@frenchmonkeys.io",
            name: "First Learner",
            role: .learner,
            token: "learner-token",
            password: "LearnerPass!123"
        )

        let safetyCourseID = UUID()
        let basicsCourse = Course(
            id: safetyCourseID,
            title: "Mechanic Foundations 101",
            category: "Basics",
            description: "Start with shop safety, tooling basics, and how to diagnose simple issues.",
            modules: ["Safety and PPE", "Tool Familiarity", "Lift Operation", "Troubleshooting Basics"],
            isPublished: true
        )

        let inspectionCourse = Course(
            id: UUID(),
            title: "Vehicle Inspection Workflow",
            category: "Diagnostics",
            description: "Build repeatable pre-service and post-service inspection habits.",
            modules: ["Visual Walkaround", "Fluids & Filters", "Documenting Findings"],
            isPublished: false
        )

        let test = Test(
            id: UUID(),
            courseID: safetyCourseID,
            title: "Foundations Quick Check",
            questions: [
                TestQuestion(prompt: "What is the first step before using an unfamiliar tool?", options: ["Ask a senior tech / read the manual", "Use it immediately", "Clean it later"], correctOptionIndex: 0),
                TestQuestion(prompt: "Which PPE item is always recommended in the bay?", options: ["Safety glasses", "Flip flops", "None"], correctOptionIndex: 0)
            ]
        )

        let announcement = Announcement(id: UUID(), title: "Welcome to French Monkeys Academy", message: "Week 1 is live!", createdAt: Date())
        let landingPage = Page(id: UUID(), title: "Program Overview", slug: "overview", contentMarkdown: "# French Monkeys Learning Platform")
        let toolbar = [
            ToolbarLink(id: UUID(), label: "Dashboard", path: "/"),
            ToolbarLink(id: UUID(), label: "Courses", path: "/api/courses"),
            ToolbarLink(id: UUID(), label: "Tests", path: "/api/tests"),
            ToolbarLink(id: UUID(), label: "Announcements", path: "/api/announcements")
        ]
        let score = Score(id: UUID(), userID: learner.id, testID: test.id, value: 85, completedAt: Date())
        let achievement = Achievement(id: UUID(), userID: learner.id, title: "Safety Starter", summary: "Completed first mechanic safety module.")

        return LearningDataStore(
            users: [admin, learner],
            courses: [basicsCourse, inspectionCourse],
            tests: [test],
            announcements: [announcement],
            pages: [landingPage],
            toolbar: toolbar,
            scores: [score],
            achievements: [achievement]
        )
    }

    func login(username: String, password: String) -> User? {
        users.first {
            $0.username.caseInsensitiveCompare(username) == .orderedSame && $0.password == password
        }
    }

    func user(token: String?) -> User? {
        guard let token else { return nil }
        return users.first { $0.token == token }
    }

    func snapshot() -> PlatformSnapshot {
        PlatformSnapshot(courses: courses, tests: tests, announcements: announcements, pages: pages, toolbar: toolbar)
    }

    func dashboard(user: User) -> LearnerDashboard {
        LearnerDashboard(
            user: UserProfile(id: user.id, username: user.username, email: user.email, name: user.name, role: user.role),
            scores: scores.filter { $0.userID == user.id },
            achievements: achievements.filter { $0.userID == user.id },
            availableCourses: courses.filter(\.isPublished)
        )
    }

    func listCourses(for user: User) -> [Course] { user.role == .admin ? courses : courses.filter(\.isPublished) }
    func listTests() -> [Test] { tests }
    func listAnnouncements() -> [Announcement] { announcements }

    func addCourse(_ item: Course) { courses.append(item) }
    func addTest(_ item: Test) { tests.append(item) }
    func addAnnouncement(_ item: Announcement) { announcements.append(item) }
    func addPage(_ item: Page) { pages.append(item) }
    func addToolbar(_ item: ToolbarLink) { toolbar.append(item) }
}
