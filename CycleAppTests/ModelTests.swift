@testable import CycleApp
import Foundation
import Testing

struct UserModelTests {
    @Test
    func testUserFullName() {
        let user1 = User(id: .init("1"), email: "test@test.com", firstName: "John", lastName: "Doe")
        #expect(user1.fullName == "John Doe")

        let user2 = User(id: .init("2"), email: "test@test.com", firstName: "John")
        #expect(user2.fullName == "John")

        let user3 = User(id: .init("3"), email: "test@test.com", lastName: "Doe")
        #expect(user3.fullName == "Doe")

        let user4 = User(id: .init("4"), email: "test@test.com")
        #expect(user4.fullName == nil)
    }

    @Test
    func testUserInitials() {
        let user1 = User(id: .init("1"), email: "test@test.com", firstName: "John", lastName: "Doe")
        #expect(user1.initials == "JD")

        let user2 = User(id: .init("2"), email: "test@test.com", firstName: "John")
        #expect(user2.initials == "J")

        let user3 = User(id: .init("3"), email: "test@test.com", lastName: "Doe")
        #expect(user3.initials == "D")

        let user4 = User(id: .init("4"), email: "test@test.com")
        #expect(user4.initials == "")
    }
}
