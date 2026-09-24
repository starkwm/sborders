import Foundation
import Testing

@testable import SbordersCore

@Suite("WindowEligibility")
struct WindowEligibilityTests {
  @Test("accepts(parent:attributes:tags:): rejects ineligible windows")
  func filtersIneligibleWindows() {
    #expect(WindowEligibility.accepts(parent: 0, attributes: 2, tags: 1))
    #expect(!WindowEligibility.accepts(parent: 1, attributes: 2, tags: 1))
    #expect(!WindowEligibility.accepts(parent: 0, attributes: 2, tags: 1 | (1 << 7)))
    #expect(!WindowEligibility.accepts(parent: 0, attributes: 2, tags: 1 | (1 << 18)))
  }
}
