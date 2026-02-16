import XCTest
@testable import App

final class DataStoreCommunityTests: XCTestCase {
    func testSignupAcceptsCaseInsensitiveCommunitySlug() {
        let store = LearningDataStore.bootstrap()

        let result = store.signup(
            SignupRequest(
                username: "tech1",
                password: "pass123",
                email: "tech1@example.com",
                name: "Tech One",
                level: .beginner,
                role: .learner,
                adminInviteCode: nil,
                communitySlug: "Automotive"
            )
        )

        guard case let .success(user) = result else {
            return XCTFail("Expected signup to succeed for case-insensitive community slug")
        }

        XCTAssertNotNil(store.accessibleCommunity(for: user, slug: "automotive"))
    }

    func testCoursePrerequisitesAreScopedToActiveCommunity() {
        let store = LearningDataStore.bootstrap()

        // Prepare learner in automotive by default
        let signup = store.signup(
            SignupRequest(
                username: "tech2",
                password: "pass123",
                email: "tech2@example.com",
                name: "Tech Two",
                level: .intermediate,
                role: .learner,
                adminInviteCode: nil,
                communitySlug: nil
            )
        )
        guard case let .success(learner) = signup else {
            return XCTFail("Expected learner signup success")
        }

        // Automotive course + test that learner passes
        let autoCourseResult = store.addCourse(
            CreateCourseRequest(
                communitySlug: "automotive",
                title: "Auto Fundamentals",
                category: "Auto",
                description: "Auto base",
                requiredStartingLevel: .beginner,
                requiredPassedTestIDs: [],
                sections: [],
                isPublished: true
            )
        )
        guard case let .success(autoCourse) = autoCourseResult else {
            return XCTFail("Expected automotive course creation success")
        }

        let q = TestQuestion(id: UUID(), prompt: "Q", options: ["A", "B"], correctOptionIndex: 0)
        let autoTestResult = store.addTest(
            CreateTestRequest(
                communitySlug: "automotive",
                courseID: autoCourse.id,
                title: "Auto Test",
                passingScore: 100,
                questions: [q]
            )
        )
        guard case let .success(autoTest) = autoTestResult else {
            return XCTFail("Expected automotive test creation success")
        }

        let submit = store.submitTest(
            user: learner,
            payload: SubmitTestRequest(testID: autoTest.id, selectedOptionIndexes: [0]),
            communityID: autoCourse.communityID
        )
        guard case .success = submit else {
            return XCTFail("Expected automotive test submission success")
        }

        // Create HVAC community and enroll learner
        let hvacResult = store.createCommunity(
            CreateCommunityRequest(
                slug: "hvac",
                name: "HVAC",
                description: "HVAC campus",
                brandingConfig: [:],
                status: .active
            )
        )
        guard case let .success(hvacCommunity) = hvacResult else {
            return XCTFail("Expected HVAC community creation success")
        }

        let membership = store.addCommunityMember(
            CreateCommunityMemberRequest(communitySlug: "hvac", username: learner.username, role: .learner)
        )
        guard case .success = membership else {
            return XCTFail("Expected HVAC membership creation success")
        }

        // HVAC course requires automotive test id. This should remain locked because prerequisite
        // completion must be scoped to HVAC tests, not automotive tests.
        let hvacCourseResult = store.addCourse(
            CreateCourseRequest(
                communitySlug: "hvac",
                title: "HVAC Advanced",
                category: "HVAC",
                description: "HVAC base",
                requiredStartingLevel: .beginner,
                requiredPassedTestIDs: [autoTest.id],
                sections: [],
                isPublished: true
            )
        )
        guard case .success = hvacCourseResult else {
            return XCTFail("Expected HVAC course creation success")
        }

        let access = store.courseAccessList(for: learner, communityID: hvacCommunity.id)
        XCTAssertEqual(access.count, 1)
        XCTAssertFalse(access[0].unlocked)
        XCTAssertEqual(access[0].reason, "Requires passing prerequisite tests")
    }
}
