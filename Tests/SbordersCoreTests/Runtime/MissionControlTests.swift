import Testing

@testable import SbordersCore

@Test func missionControlEntryDoesNotReadAWindowID() {
  #expect(
    WindowEvent.decode(code: 1204, data: nil, count: 0)
      == WindowEvent(kind: .missionControl, windowID: nil)
  )
}

@Test func missionControlWaitsForEntryAnimationAndConfirmedExit() {
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

@Test func missionControlDetectsStartupDuringOverviewAndSurvivesFailedQueries() {
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

@Test func cancelledMissionControlEntryEventuallyRestoresBorders() {
  var state = MissionControlState()
  state.entered(at: 10)
  state.update(overviewVisible: false, at: 10.5)

  #expect(state.isActive)

  state.update(overviewVisible: false, at: 10.6)

  #expect(!state.isActive)

  state.entered(at: 11)

  #expect(state.isActive)
}

@Test func overviewIdentificationDoesNotNeedWindowTitles() {
  #expect(MissionControlObserver.isOverview(owner: "com.apple.dock", layer: 18))
  #expect(MissionControlObserver.isOverview(owner: "com.apple.WindowManager", layer: 19))
  #expect(!MissionControlObserver.isOverview(owner: "com.apple.dock", layer: 20))
  #expect(
    !MissionControlObserver.isOverview(owner: "com.apple.WindowManager", layer: -2_147_483_624)
  )

  #expect(!MissionControlObserver.isOverview(owner: "test.app", layer: 19))
  #expect(!MissionControlObserver.isOverview(owner: nil, layer: 18))
}
