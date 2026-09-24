import Testing

@testable import Sborders

@Suite("QueryCommand")
struct QueryCommandTests {
  @Test("validate: rejects conflicting query subjects") func queryRejectsConflictingSubjects() {
    #expect(throws: (any Error).self) { try QueryCommand.parse(["--windows", "--config"]) }
  }
}
