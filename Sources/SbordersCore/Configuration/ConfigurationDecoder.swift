import Foundation

/// Removes configuration-only syntax before decoding the existing JSON model.
enum ConfigurationDecoder {
  static func decode(from data: Data) throws -> Configuration {
    let json = try normalized(data)
    _ = try JSONSerialization.jsonObject(with: json)
    try rejectDuplicateKeys(json)
    return try JSONDecoder().decode(Configuration.self, from: json)
  }

  // JSONDecoder otherwise silently accepts duplicate keys. Scan already validated JSON
  // and decode each key so escaped spellings compare as the same string.
  static func rejectDuplicateKeys(_ data: Data) throws {
    let bytes = Array(data)
    var scopes: [Set<String>?] = []
    var index = 0
    while index < bytes.count {
      switch bytes[index] {
      case 123: scopes.append([])
      case 91: scopes.append(nil)
      case 125, 93: scopes.removeLast()
      case 34:
        let start = index
        index += 1
        while index < bytes.count {
          if bytes[index] == 92 {
            index += 2
            continue
          }
          if bytes[index] == 34 { break }
          index += 1
        }
        let end = index + 1
        var next = end
        while next < bytes.count, [9, 10, 13, 32].contains(bytes[next]) { next += 1 }
        if next < bytes.count, bytes[next] == 58, !scopes.isEmpty {
          let key = try JSONDecoder().decode(String.self, from: Data(bytes[start..<end]))
          let last = scopes.count - 1
          guard scopes[last]?.insert(key).inserted == true else {
            throw MessageError.message("Duplicate configuration key: \(key).")
          }
        }
      default: break
      }
      index += 1
    }
  }

  static func normalized(_ data: Data) throws -> Data {
    var bytes = Array(data)
    var index = 0
    var inString = false
    var escaped = false
    var previous: UInt8?
    var trailingComma: Int?

    while index < bytes.count {
      let byte = bytes[index]
      if inString {
        if escaped {
          escaped = false
        } else if byte == 0x5C {
          escaped = true
        } else if byte == 0x22 {
          inString = false
        }
        index += 1
        continue
      }

      if byte == 0x2F, index + 1 < bytes.count {
        let next = bytes[index + 1]
        if next == 0x2F {
          while index < bytes.count, bytes[index] != 0x0A, bytes[index] != 0x0D {
            bytes[index] = 0x20
            index += 1
          }
          continue
        }
        if next == 0x2A {
          let start = index
          bytes[index] = 0x20
          bytes[index + 1] = 0x20
          index += 2
          var closed = false
          while index < bytes.count {
            if bytes[index] == 0x2A, index + 1 < bytes.count, bytes[index + 1] == 0x2F {
              bytes[index] = 0x20
              bytes[index + 1] = 0x20
              index += 2
              closed = true
              break
            }
            if bytes[index] != 0x0A, bytes[index] != 0x0D { bytes[index] = 0x20 }
            index += 1
          }
          guard closed else {
            throw MessageError.message("Unterminated block comment at byte \(start + 1).")
          }
          continue
        }
      }

      if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
        index += 1
        continue
      }

      if byte == 0x2C {
        // Do not turn missing values or repeated commas into valid JSON.
        guard let previous, ![0x5B, 0x7B, 0x3A, 0x2C].contains(previous) else {
          throw MessageError.message("Unexpected comma at byte \(index + 1).")
        }
        trailingComma = index
      } else {
        if byte == 0x5D || byte == 0x7D, let trailingComma {
          bytes[trailingComma] = 0x20
        }
        trailingComma = nil
      }

      if byte == 0x22 { inString = true }
      previous = byte
      index += 1
    }

    return Data(bytes)
  }
}
