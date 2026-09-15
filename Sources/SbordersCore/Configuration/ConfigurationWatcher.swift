import Foundation

/// Watches the file and its nearest existing directory so atomic replacement and first creation both reload.
@MainActor
final class ConfigurationWatcher {
  private let url: URL
  private let onChange: () -> Void

  private var sources: [any DispatchSourceFileSystemObject] = []
  private var reloadTask: Task<Void, Never>?
  private var isStarted = false

  init(url: URL, onChange: @escaping () -> Void) {
    self.url = url
    self.onChange = onChange
  }

  func start() {
    guard !isStarted else { return }

    isStarted = true
    installSources()
  }

  func stop() {
    isStarted = false
    reloadTask?.cancel()
    reloadTask = nil

    for source in sources { source.cancel() }
    sources.removeAll()
  }

  private func installSources() {
    for source in sources { source.cancel() }
    sources.removeAll()

    var directory = url.deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: directory.path), directory.path != "/" {
      directory.deleteLastPathComponent()
    }

    watch(directory)
    watch(url)
  }

  private func watch(_ target: URL) {
    let descriptor = open(target.path, O_EVTONLY)
    guard descriptor >= 0 else { return }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor,
      eventMask: [.write, .extend, .attrib, .rename, .delete, .revoke],
      queue: .main
    )
    source.setEventHandler { [weak self] in
      Task { @MainActor [weak self] in self?.scheduleReload() }
    }
    source.setCancelHandler { close(descriptor) }
    sources.append(source)
    source.resume()
  }

  private func scheduleReload() {
    guard isStarted else { return }

    reloadTask?.cancel()
    reloadTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
      guard let self, self.isStarted else { return }

      self.installSources()
      self.onChange()
    }
  }
}
