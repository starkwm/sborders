import Foundation
import StarkConfiguration

private func rejectUnknownKeys(_ decoder: any Decoder, allowed: [String]) throws {
  let values = try decoder.container(keyedBy: AnyKey.self)

  if let key = values.allKeys.first(where: { !allowed.contains($0.stringValue) }) {
    throw DecodingError.dataCorrupted(
      .init(
        codingPath: decoder.codingPath + [key],
        debugDescription: "Unknown configuration key: \(key.stringValue)."
      )
    )
  }
}

struct Configuration: Codable, Equatable, Sendable {
  enum Style: String, Codable, Sendable { case round, square }
  enum FocusMode: String, Codable, Sendable { case windowServer, accessibility }
  enum CodingKeys: String, CodingKey, CaseIterable {
    case schema = "$schema"
    case enabled, width, style, activeColor, inactiveColor, focusMode, includeApps, excludeApps
  }

  var schema: String?
  var enabled = true
  var width = 4.0
  var style = Style.round
  var activeColor = "#E1E3E4"
  var inactiveColor = "#00000000"
  var focusMode = FocusMode.windowServer
  var includeApps: [AppMatcher] = []
  var excludeApps: [AppMatcher] = []

  init() {}

  init(from decoder: any Decoder) throws {
    try rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.rawValue))

    let values = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = Configuration()

    schema = values.contains(.schema) ? try values.decode(String.self, forKey: .schema) : nil
    enabled = try values.value(Bool.self, forKey: .enabled, default: defaults.enabled)
    width = try values.value(Double.self, forKey: .width, default: defaults.width)
    style = try values.value(Style.self, forKey: .style, default: defaults.style)
    activeColor = try values.value(String.self, forKey: .activeColor, default: defaults.activeColor)
    inactiveColor = try values.value(
      String.self,
      forKey: .inactiveColor,
      default: defaults.inactiveColor
    )
    focusMode = try values.value(FocusMode.self, forKey: .focusMode, default: defaults.focusMode)
    includeApps = try values.value(
      [AppMatcher].self,
      forKey: .includeApps,
      default: defaults.includeApps
    )
    excludeApps = try values.value(
      [AppMatcher].self,
      forKey: .excludeApps,
      default: defaults.excludeApps
    )

    try validate()
  }

  func validate() throws {
    guard width.isFinite, (0.5...64).contains(width) else {
      throw MessageError.message("width must be between 0.5 and 64 points.")
    }

    guard BorderColor(hex: activeColor) != nil else {
      throw MessageError.message("activeColor must use #RRGGBB or #RRGGBBAA.")
    }

    guard BorderColor(hex: inactiveColor) != nil else {
      throw MessageError.message("inactiveColor must use #RRGGBB or #RRGGBBAA.")
    }
  }

  func allows(_ window: WindowSnapshot) -> Bool {
    (includeApps.isEmpty || includeApps.contains { $0.matches(window) })
      && !excludeApps.contains { $0.matches(window) }
  }

  func setting(_ key: String, value: String) throws -> Configuration {
    guard CodingKeys.allCases.contains(where: { $0.rawValue == key && $0 != .schema }) else {
      throw MessageError.message("Unknown setting: \(key).")
    }

    var object =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as! [String: Any]

    if ["activeColor", "inactiveColor", "style", "focusMode"].contains(key) {
      object[key] = value
    } else {
      let data = Data(value.utf8)
      let parsed = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
      try JSONC.rejectDuplicateKeys(data)

      object[key] = parsed
    }

    return try ConfigurationFile.decode(JSONSerialization.data(withJSONObject: object))
  }
}

struct AppMatcher: Codable, Equatable, Sendable {
  enum CodingKeys: String, CodingKey, CaseIterable { case bundleID, processName }

  var bundleID: String?
  var processName: String?

  init(bundleID: String? = nil, processName: String? = nil) {
    self.bundleID = bundleID
    self.processName = processName
  }

  init(from decoder: any Decoder) throws {
    try rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.rawValue))

    let values = try decoder.container(keyedBy: CodingKeys.self)

    bundleID = try values.decodeIfPresent(String.self, forKey: .bundleID)
    processName = try values.decodeIfPresent(String.self, forKey: .processName)

    guard values.allKeys.count == 1, let value = bundleID ?? processName,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw MessageError.message(
        "Each application matcher needs exactly one nonempty bundleID or processName."
      )
    }
  }

  func matches(_ window: WindowSnapshot) -> Bool {
    if let bundleID { return window.bundleID == bundleID }

    return processName == window.processName
  }
}

private struct AnyKey: CodingKey {
  let stringValue: String
  let intValue: Int? = nil

  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { return nil }
}

extension KeyedDecodingContainer {
  fileprivate func value<T: Decodable>(_ type: T.Type, forKey key: Key, default fallback: T) throws
    -> T
  {
    contains(key) ? try decode(type, forKey: key) : fallback
  }
}
