import Foundation
import StarkConfiguration

enum ConfigurationDecoder {
  static func decode(from data: Data) throws -> Configuration {
    let json = try JSONC.normalized(data, rejectingDuplicateKeys: true)
    return try JSONDecoder().decode(Configuration.self, from: json)
  }
}
