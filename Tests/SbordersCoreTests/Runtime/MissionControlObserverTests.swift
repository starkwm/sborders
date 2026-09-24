import Testing

@testable import SbordersCore

@Suite("MissionControlObserver")
struct MissionControlObserverTests {
  @Test("isOverview(owner:layer:): identifies overview windows") func identifiesOverviewWindows() {
    #expect(MissionControlObserver.isOverview(owner: "com.apple.dock", layer: 18))
    #expect(MissionControlObserver.isOverview(owner: "com.apple.WindowManager", layer: 19))
    #expect(!MissionControlObserver.isOverview(owner: "com.apple.dock", layer: 20))
    #expect(
      !MissionControlObserver.isOverview(owner: "com.apple.WindowManager", layer: -2_147_483_624)
    )

    #expect(!MissionControlObserver.isOverview(owner: "test.app", layer: 19))
    #expect(!MissionControlObserver.isOverview(owner: nil, layer: 18))
  }
}
