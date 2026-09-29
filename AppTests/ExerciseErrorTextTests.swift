import XCTest
@testable import GrooveCore

final class ExerciseErrorTextTests: XCTestCase {
    func testEveryErrorHasAMessage() {
        for error in [ExerciseNameError.empty, .tooLong, .duplicate] {
            XCTAssertFalse(error.message.isEmpty)
            XCTAssertFalse(error.message.hasPrefix("editor.error"), "untranslated key: \(error.message)")
        }
    }
}
