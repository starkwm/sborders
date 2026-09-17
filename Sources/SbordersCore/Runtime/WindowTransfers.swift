import Foundation

/// Keeps each transfer's deadline independent of reconciliation retries.
@MainActor
final class WindowTransfers {
  var ids: Set<UInt32> { Set(expirations.keys) }

  private let gracePeriod: Duration
  private var expirations: [UInt32: Task<Void, Never>] = [:]

  init(gracePeriod: Duration = .milliseconds(380)) { self.gracePeriod = gracePeriod }

  @discardableResult
  func insert(_ id: UInt32, onExpiry: @escaping @MainActor () -> Void) -> Task<Void, Never> {
    if let expiration = expirations[id] { return expiration }
    let deadline = ContinuousClock.now.advanced(by: gracePeriod)
    let expiration = Task { [weak self] in
      do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }

      guard !Task.isCancelled, let self else { return }

      self.expirations.removeValue(forKey: id)
      onExpiry()
    }

    expirations[id] = expiration

    return expiration
  }

  func remove(_ id: UInt32) { expirations.removeValue(forKey: id)?.cancel() }

  func removeAll() {
    for expiration in expirations.values { expiration.cancel() }
    expirations = [:]
  }
}
