import AppKit

/// Private ABI declarations stay here. Setter return values are deliberately ignored:
/// several transaction functions return void on current macOS versions.
@MainActor
final class SkyLight {
  typealias Notify =
    @convention(c) (UInt32, UnsafeRawPointer?, Int, UnsafeMutableRawPointer?) -> Void
  typealias ConnectionNotify =
    @convention(c) (UInt32, UnsafeRawPointer?, Int, UnsafeMutableRawPointer?, Int32) -> Void

  let connection: Int32
  let getBounds: @convention(c) (Int32, UInt32, UnsafeMutablePointer<CGRect>) -> Int32
  let getSublevel: @convention(c) (Int32, UInt32) -> Int32
  let getOwner: @convention(c) (Int32, UInt32, UnsafeMutablePointer<Int32>) -> Int32
  let getPID: @convention(c) (Int32, UnsafeMutablePointer<pid_t>) -> Int32
  let isOrdered: @convention(c) (Int32, UInt32, UnsafeMutablePointer<Bool>) -> Int32
  let copyDisplaySpaces: @convention(c) (Int32) -> Unmanaged<CFArray>?
  let copySpaces: @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
  let spaceType: @convention(c) (Int32, UInt64) -> Int32
  let copyWindows:
    @convention(c) (
      Int32, UInt32, CFArray, UInt32, UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>
    ) -> Unmanaged<CFArray>?
  let query: @convention(c) (Int32, CFArray, UInt32) -> Unmanaged<CFTypeRef>?
  let iterator: @convention(c) (CFTypeRef) -> Unmanaged<CFTypeRef>?
  let advance: @convention(c) (CFTypeRef) -> Bool
  let windowID: @convention(c) (CFTypeRef) -> UInt32
  let parentID: @convention(c) (CFTypeRef) -> UInt32
  let tags: @convention(c) (CFTypeRef) -> UInt64
  let attributes: @convention(c) (CFTypeRef) -> UInt64
  let level: @convention(c) (CFTypeRef) -> Int32
  let radii: (@convention(c) (CFTypeRef) -> Unmanaged<CFArray>?)?
  let register: @convention(c) (Notify, UInt32, UnsafeMutableRawPointer?) -> Int32
  let unregister: @convention(c) (Notify, UInt32, UnsafeMutableRawPointer?) -> Int32
  let registerConnection:
    @convention(c) (Int32, ConnectionNotify, UInt32, UnsafeMutableRawPointer?) -> Int32
  let unregisterConnection:
    @convention(c) (Int32, ConnectionNotify, UInt32, UnsafeMutableRawPointer?) -> Int32
  let notifications: @convention(c) (Int32, UnsafePointer<UInt32>?, Int32) -> Int32
  let newRegion:
    @convention(c) (UnsafePointer<CGRect>, UnsafeMutablePointer<Unmanaged<CFTypeRef>?>) -> Int32
  let newWindow:
    @convention(c) (Int32, Int32, Float, Float, CFTypeRef, UnsafeMutablePointer<UInt32>) -> Int32
  let releaseWindow: @convention(c) (Int32, UInt32) -> Void
  let setShape: @convention(c) (Int32, UInt32, Float, Float, CFTypeRef) -> Void
  let setResolution: @convention(c) (Int32, UInt32, Double) -> Void
  let setOpacity: @convention(c) (Int32, UInt32, Bool) -> Void
  let setTags: @convention(c) (Int32, UInt32, UnsafePointer<UInt64>, Int32) -> Void
  let clearTags: @convention(c) (Int32, UInt32, UnsafePointer<UInt64>, Int32) -> Void
  let shadow: @convention(c) (UInt32, CFDictionary) -> Void
  let createContext: @convention(c) (Int32, UInt32, CFDictionary?) -> Unmanaged<CGContext>?
  let flush: @convention(c) (Int32, UInt32, UnsafeRawPointer?) -> Void
  let transaction: @convention(c) (Int32) -> Unmanaged<CFTypeRef>?
  let move: @convention(c) (CFTypeRef, UInt32, CGPoint) -> Void
  let setLevel: @convention(c) (CFTypeRef, UInt32, Int32) -> Void
  let setSublevel: @convention(c) (CFTypeRef, UInt32, Int32) -> Void
  let order: @convention(c) (CFTypeRef, UInt32, Int32, UInt32) -> Void
  let commit: @convention(c) (CFTypeRef, Int32) -> Void
  let addToSpaces: @convention(c) (Int32, CFArray, CFArray) -> Void
  let removeFromSpaces: @convention(c) (Int32, CFArray, CFArray) -> Void

  // Function pointers may still be used by WindowServer callbacks during process teardown.
  // Keep the framework loaded for the process lifetime.
  private let handle: UnsafeMutableRawPointer

  init() throws {
    guard
      let handle = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        RTLD_NOW | RTLD_LOCAL
      )
    else {
      throw MessageError.message("Cannot load SkyLight. A logged-in macOS desktop is required.")
    }
    self.handle = handle
    func load<T>(_ name: String) throws -> T {
      guard let pointer = dlsym(handle, name) else {
        throw MessageError.message("Required WindowServer function is unavailable: \(name).")
      }
      return unsafeBitCast(pointer, to: T.self)
    }
    let mainConnection: @convention(c) () -> Int32 = try load("SLSMainConnectionID")
    connection = mainConnection()
    guard connection != 0 else { throw MessageError.message("Cannot connect to WindowServer.") }
    getBounds = try load("SLSGetWindowBounds")
    getSublevel = try load("SLSGetWindowSubLevel")
    getOwner = try load("SLSGetWindowOwner")
    getPID = try load("SLSConnectionGetPID")
    isOrdered = try load("SLSWindowIsOrderedIn")
    copyDisplaySpaces = try load("SLSCopyManagedDisplaySpaces")
    copySpaces = try load("SLSCopySpacesForWindows")
    spaceType = try load("SLSSpaceGetType")
    copyWindows = try load("SLSCopyWindowsWithOptionsAndTags")
    query = try load("SLSWindowQueryWindows")
    iterator = try load("SLSWindowQueryResultCopyWindows")
    advance = try load("SLSWindowIteratorAdvance")
    windowID = try load("SLSWindowIteratorGetWindowID")
    parentID = try load("SLSWindowIteratorGetParentID")
    tags = try load("SLSWindowIteratorGetTags")
    attributes = try load("SLSWindowIteratorGetAttributes")
    level = try load("SLSWindowIteratorGetLevel")
    radii = try? load("SLSWindowIteratorGetCornerRadii")
    register = try load("SLSRegisterNotifyProc")
    unregister = try load("SLSRemoveNotifyProc")
    registerConnection = try load("SLSRegisterConnectionNotifyProc")
    unregisterConnection = try load("SLSRemoveConnectionNotifyProc")
    notifications = try load("SLSRequestNotificationsForWindows")
    newRegion = try load("CGSNewRegionWithRect")
    newWindow = try load("SLSNewWindow")
    releaseWindow = try load("SLSReleaseWindow")
    setShape = try load("SLSSetWindowShape")
    setResolution = try load("SLSSetWindowResolution")
    setOpacity = try load("SLSSetWindowOpacity")
    setTags = try load("SLSSetWindowTags")
    clearTags = try load("SLSClearWindowTags")
    shadow = try load("SLSWindowSetShadowProperties")
    createContext = try load("SLWindowContextCreate")
    flush = try load("SLSFlushWindowContentRegion")
    transaction = try load("SLSTransactionCreate")
    move = try load("SLSTransactionMoveWindowWithGroup")
    setLevel = try load("SLSTransactionSetWindowLevel")
    setSublevel = try load("SLSTransactionSetWindowSubLevel")
    order = try load("SLSTransactionOrderWindow")
    commit = try load("SLSTransactionCommit")
    addToSpaces = try load("SLSAddWindowsToSpaces")
    removeFromSpaces = try load("SLSRemoveWindowsFromSpaces")
  }
}
