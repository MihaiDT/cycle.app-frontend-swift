import Testing

@testable import Core

struct ValidationTests {
    @Test
    func testEmailValidation() {
        #expect(Validation.email("test@example.com").isValid)
        #expect(Validation.email("user.name+tag@domain.co.uk").isValid)
        #expect(!Validation.email("").isValid)
        #expect(!Validation.email("invalid").isValid)
        #expect(!Validation.email("@domain.com").isValid)
        #expect(!Validation.email("user@").isValid)
    }

    @Test
    func testPasswordValidation() {
        #expect(Validation.password("Password1").isValid)
        #expect(Validation.password("MySecure123").isValid)

        #expect(!Validation.password("").isValid)
        #expect(!Validation.password("short").isValid)
        #expect(!Validation.password("nouppercase1").isValid)
        #expect(!Validation.password("NOLOWERCASE1").isValid)
        #expect(!Validation.password("NoNumbers").isValid)
    }

    @Test
    func testRequiredValidation() {
        #expect(Validation.required("value").isValid)
        #expect(!Validation.required("").isValid)
        #expect(!Validation.required("   ").isValid)
    }

    @Test
    func testMinLengthValidation() {
        #expect(Validation.minLength("12345", length: 5).isValid)
        #expect(Validation.minLength("123456", length: 5).isValid)
        #expect(!Validation.minLength("1234", length: 5).isValid)
    }

    @Test
    func testMaxLengthValidation() {
        #expect(Validation.maxLength("12345", length: 5).isValid)
        #expect(Validation.maxLength("1234", length: 5).isValid)
        #expect(!Validation.maxLength("123456", length: 5).isValid)
    }

    @Test
    func testMatchingValidation() {
        #expect(Validation.matching("password", "password").isValid)
        #expect(!Validation.matching("password", "different").isValid)
    }

    @Test
    func testCombinedValidation() {
        let validResults: [ValidationResult] = [.valid, .valid, .valid]
        #expect(validResults.combined.isValid)

        let invalidResults: [ValidationResult] = [.valid, .invalid("Error"), .valid]
        #expect(!invalidResults.combined.isValid)
        #expect(invalidResults.combined.errorMessage == "Error")
    }
}
