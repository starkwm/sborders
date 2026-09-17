import Foundation

public enum LocalSocket {
  public static var defaultPath: String { NSHomeDirectory() + "/.config/sborders/control.sock" }
}
