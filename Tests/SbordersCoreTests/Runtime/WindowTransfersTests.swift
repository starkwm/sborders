import Testing

@testable import SbordersCore

@Test @MainActor func repeatedTransferKeepsDeadline() async {
  let transfers = WindowTransfers(gracePeriod: .milliseconds(10))
  var state = BorderCoordinator()
  state.update(window())
  var expirations = 0
  let expiration = transfers.insert(1) {
    expirations += 1
    state.reconcile([], liveIDs: [1], preservingIDs: transfers.ids)
  }
  for _ in 0..<10 {
    transfers.insert(1) { Issue.record("A repeated notification replaced the original expiry.") }
    state.reconcile([], liveIDs: [1], preservingIDs: transfers.ids)

    #expect(state.windows[1] != nil)
  }
  await expiration.value

  #expect(expirations == 1)
  #expect(transfers.ids.isEmpty)
  #expect(state.windows.isEmpty)
}

@Test @MainActor func cancellationPreservesReplacement() async {
  let transfers = WindowTransfers(gracePeriod: .milliseconds(10))
  let cancelled = transfers.insert(1) { Issue.record("A cancelled transfer expired.") }
  transfers.remove(1)
  var expired = false
  let replacement = transfers.insert(1) { expired = true }
  await cancelled.value
  await replacement.value

  #expect(expired)
  #expect(transfers.ids.isEmpty)
}

@Test @MainActor func cancelsAllTransfers() async {
  let transfers = WindowTransfers(gracePeriod: .milliseconds(10))
  let first = transfers.insert(1) { Issue.record("A stopped transfer expired.") }
  let second = transfers.insert(2) { Issue.record("A stopped transfer expired.") }
  transfers.removeAll()
  await first.value
  await second.value

  #expect(transfers.ids.isEmpty)
}
