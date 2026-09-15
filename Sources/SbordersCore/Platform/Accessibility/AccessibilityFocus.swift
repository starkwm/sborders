import AppKit
@preconcurrency import ApplicationServices

@MainActor
final class AccessibilityFocus {
  private let getWindow: @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> Int32

  init() throws {
    guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow")
    else {
      throw MessageError.message("Accessibility window lookup is unavailable.")
    }
    getWindow = unsafeBitCast(
      pointer,
      to: (@convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> Int32).self
    )
  }

  func checkPermission(prompt: Bool) throws {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    guard AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary) else {
      throw MessageError.message(
        "Accessibility focus mode requires permission in System Settings > Privacy & Security > Accessibility."
      )
    }
  }

  func focusedWindow() -> UInt32? {
    guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.1)
    var value: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
      let value, CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return nil }
    let window = unsafeDowncast(value, to: AXUIElement.self)
    var id: UInt32 = 0
    return getWindow(window, &id) == 0 && id != 0 ? id : nil
  }
}
