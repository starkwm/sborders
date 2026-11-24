import CoreGraphics
import StarkSkyLight

@MainActor
struct BorderSpaces {
  private let client: any SpaceQuerying
  private var visible = Set<SpaceID>()

  init(client: any SpaceQuerying) { self.client = client }

  mutating func refresh() throws -> [UInt64] {
    guard let snapshot = try? client.snapshot() else {
      throw MessageError.message("Cannot read display Spaces.")
    }

    visible = snapshot.visibleSpaceIDs
    let ids = snapshot.allSpaceIDs
    guard !ids.isEmpty else { throw MessageError.message("No desktop Spaces are available.") }

    return ids.map(\.rawValue)
  }

  func membership(of windowID: CGWindowID, ordered: Bool, sticky: Bool) -> (
    ids: [UInt64], visible: Bool, fullscreen: Bool
  ) {
    let ids = (try? client.spaceIDs(containing: windowID)) ?? []
    return (
      ids.map(\.rawValue),
      ordered && (sticky || !visible.isDisjoint(with: ids)),
      ids.contains { (try? client.spaceType(for: $0)) == .fullscreen }
    )
  }
}
