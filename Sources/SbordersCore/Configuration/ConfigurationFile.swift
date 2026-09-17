import Foundation
import StarkConfiguration

public enum ConfigurationFile {
  public static func defaultURL(
    directory: URL = FileManager.default.homeDirectoryForCurrentUser.appending(
      path: ".config/sborders"
    )
  ) -> URL {
    let jsonc = directory.appending(path: "config.jsonc")
    return FileManager.default.fileExists(atPath: jsonc.path)
      ? jsonc : directory.appending(path: "config.json")
  }

  public static func validate(url: URL) throws { _ = try load(url: url) }

  static func load(url: URL) throws -> Configuration {
    try decode(Data(contentsOf: url))
  }

  static func decode(_ data: Data) throws -> Configuration {
    do {
      let json = try JSONC.normalized(data, rejectingDuplicateKeys: true)
      return try JSONDecoder().decode(Configuration.self, from: json)
    } catch let error as DecodingError {
      let context: DecodingError.Context
      switch error {
      case .dataCorrupted(let c), .keyNotFound(_, let c), .typeMismatch(_, let c),
        .valueNotFound(_, let c):
        context = c
      @unknown default: throw error
      }
      let path = context.codingPath.map(\.stringValue).joined(separator: ".")
      throw MessageError.message("\(path.isEmpty ? "$" : path): \(context.debugDescription)")
    }
  }
}

@MainActor
final class ConfigurationStore {
  private(set) var configuration: Configuration
  private(set) var lastError: String?
  private(set) var fileData: Data?
  private(set) var hasOverrides = false
  let url: URL

  init(url: URL, allowMissing: Bool) throws {
    self.url = url
    do {
      let data = try Data(contentsOf: url)
      configuration = try ConfigurationFile.decode(data)
      fileData = data
    } catch CocoaError.fileReadNoSuchFile where allowMissing {
      configuration = Configuration()
    }
  }

  @discardableResult
  func reload(validate: (Configuration) throws -> Void = { _ in }) throws -> Configuration {
    do {
      let data = try Data(contentsOf: url)
      let candidate = try ConfigurationFile.decode(data)
      try validate(candidate)
      configuration = candidate
      fileData = data
      hasOverrides = false
      lastError = nil
      return candidate
    } catch {
      lastError = error.localizedDescription
      throw error
    }
  }

  func set(
    _ key: String,
    value: String,
    validate: (Configuration) throws -> Void = { _ in }
  ) throws {
    let candidate = try configuration.setting(key, value: value)
    try validate(candidate)
    configuration = candidate
    hasOverrides = true
  }
}
