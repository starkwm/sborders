import Testing

@testable import Sborders

@Test func queryRejectsConflictingSubjects() {
  #expect(throws: (any Error).self) { try QueryCommand.parse(["--windows", "--config"]) }
}
