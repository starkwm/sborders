import Testing

@testable import SbordersCore

@Suite("MissionControlState")
struct MissionControlStateTests {
  @Test("entered(at:): handles cancelled overview entry") func handlesCancelledOverviewEntry() {
    var state = MissionControlState()
    state.entered(at: 10)
    state.update(overviewVisible: false, at: 10.5)

    #expect(state.isActive)

    state.update(overviewVisible: false, at: 10.6)

    #expect(!state.isActive)

    state.entered(at: 11)

    #expect(state.isActive)
  }

  @Test("update(overviewVisible:at:): waits for overview exit") func waitsForOverviewExit() {
    var state = MissionControlState()
    state.entered(at: 10)
    state.update(overviewVisible: false, at: 10.1)
    state.update(overviewVisible: false, at: 10.2)

    #expect(state.isActive)

    state.update(overviewVisible: true, at: 10.3)
    state.update(overviewVisible: false, at: 11)

    #expect(state.isActive)

    state.update(overviewVisible: true, at: 11.1)
    state.update(overviewVisible: false, at: 12)

    #expect(state.isActive)

    state.update(overviewVisible: false, at: 12.1)

    #expect(!state.isActive)
  }

  @Test("update(overviewVisible:at:): detects overview at startup") func detectsOverviewAtStartup()
  {
    var state = MissionControlState()
    state.update(overviewVisible: true, at: 10)

    #expect(state.isActive)

    state.update(overviewVisible: false, at: 11)
    state.update(overviewVisible: nil, at: 11.1)
    state.update(overviewVisible: false, at: 11.2)

    #expect(state.isActive)

    state.update(overviewVisible: false, at: 11.3)

    #expect(!state.isActive)
  }
}
