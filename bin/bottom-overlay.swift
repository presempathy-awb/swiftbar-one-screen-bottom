import Cocoa
import ApplicationServices

let overlayRev = "v14"
let swiftBarDefaultsDomain = "com.ameba.SwiftBar"
let stubFolderName = ".one-screen-bottom-stub"
let savedPluginDirName = ".one-screen-bottom.saved-plugin-dir"

enum BarPlacement {
  case bottom
  case hidden
}

func placement(forScreenCount _: Int) -> BarPlacement {
  .bottom
}

func hasStackedLowerDisplay(_ screens: [NSScreen]) -> Bool {
  guard screens.count >= 2 else { return false }
  for (i, a) in screens.enumerated() {
    for (j, b) in screens.enumerated() where i != j {
      if b.frame.maxY <= a.frame.minY + 16 { return true }
    }
  }
  return false
}

func lowestScreen(_ screens: [NSScreen]) -> NSScreen? {
  screens.min(by: { $0.frame.minY < $1.frame.minY }) ?? screens.first
}

func screenDisplayID(_ screen: NSScreen) -> CGDirectDisplayID {
  let key = NSDeviceDescriptionKey("NSScreenNumber")
  if let num = screen.deviceDescription[key] as? NSNumber {
    return num.uint32Value
  }
  return 0
}

func screenMatching(id: CGDirectDisplayID) -> NSScreen? {
  NSScreen.screens.first { screenDisplayID($0) == id }
}

func placement(screens: [NSScreen]) -> BarPlacement {
  .bottom
}

func overlayLog(_ message: String) {
  FileHandle.standardError.write(Data("overlay rev=\(overlayRev) \(message)\n".utf8))
  try? FileHandle.standardError.synchronize()
}

func swiftBarBundleID() -> String { "com.ameba.SwiftBar" }

func runDefaults(_ arguments: [String]) -> String {
  let proc = Process()
  proc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
  proc.arguments = arguments
  let out = Pipe()
  proc.standardOutput = out
  proc.standardError = Pipe()
  do { try proc.run() } catch { return "" }
  proc.waitUntilExit()
  let data = out.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func readSwiftBarDefault(_ key: String) -> String {
  runDefaults(["read", swiftBarDefaultsDomain, key])
}

func writeSwiftBarDefault(_ key: String, string value: String) {
  _ = runDefaults(["write", swiftBarDefaultsDomain, key, value])
}

func writeSwiftBarDefault(_ key: String, bool value: Bool) {
  _ = runDefaults(["write", swiftBarDefaultsDomain, key, "-bool", value ? "true" : "false"])
}

func stubDirectory(_ pluginsDir: URL) -> URL {
  pluginsDir.appendingPathComponent(stubFolderName)
}

func savedPluginDirURL(_ pluginsDir: URL) -> URL {
  pluginsDir.appendingPathComponent(savedPluginDirName)
}

func pathLooksLikeStub(_ path: String) -> Bool {
  path.contains("one-screen-bottom-stub")
}

func shellQuoted(_ path: String) -> String {
  "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func writeStubKeeper(pluginsDir: URL) {
  let stub = stubDirectory(pluginsDir)
  try? FileManager.default.createDirectory(at: stub, withIntermediateDirectories: true)
  let quoted = shellQuoted(pluginsDir.path)
  let lines = [
    "#!/bin/bash",
    "# <swiftbar.hideAbout>true</swiftbar.hideAbout>",
    "# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>",
    "# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>",
    "# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>",
    "# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>",
    "REAL=\(quoted)",
    "export SWIFTBAR_PLUGINS_PATH=\"$REAL\"",
    "if [[ -x \"$REAL/one-screen-bottom.5s.sh\" ]]; then",
    "  exec \"$REAL/one-screen-bottom.5s.sh\"",
    "fi",
  ]
  let body = lines.joined(separator: "\n") + "\n"
  let keeper = stub.appendingPathComponent("one-screen-bottom.5s.sh")
  try? body.write(to: keeper, atomically: true, encoding: .utf8)
  try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: keeper.path)
}

func parkTopSwiftBar(pluginsDir: URL) {
  writeStubKeeper(pluginsDir: pluginsDir)
  let saved = savedPluginDirURL(pluginsDir)
  if !FileManager.default.fileExists(atPath: saved.path) {
    var current = readSwiftBarDefault("PluginDirectory")
    if current.isEmpty || pathLooksLikeStub(current) {
      current = pluginsDir.path
    }
    try? current.write(to: saved, atomically: true, encoding: .utf8)
  }
  writeSwiftBarDefault("PluginDirectory", string: stubDirectory(pluginsDir).path)
  writeSwiftBarDefault("StealthMode", bool: true)
}

func unparkTopSwiftBar(pluginsDir: URL) {
  let saved = savedPluginDirURL(pluginsDir)
  var restored = pluginsDir.path
  if let text = try? String(contentsOf: saved, encoding: .utf8) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty && !pathLooksLikeStub(trimmed) {
      restored = trimmed
    }
  }
  writeSwiftBarDefault("PluginDirectory", string: restored)
  writeSwiftBarDefault("StealthMode", bool: false)
  try? FileManager.default.removeItem(at: saved)
}

func hideTopSwiftBar(pluginsDir: URL) {
  parkTopSwiftBar(pluginsDir: pluginsDir)
  for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == swiftBarBundleID() {
    app.forceTerminate()
  }
}

func showTopSwiftBar() {
  if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == swiftBarBundleID() }) {
    return
  }
  guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: swiftBarBundleID()) else { return }
  NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
}

func restoreTopSwiftBar(pluginsDir: URL) {
  unparkTopSwiftBar(pluginsDir: pluginsDir)
  showTopSwiftBar()
}

func companionStatusBundleIDs() -> [String] {
  [
    "eu.exelban.Stats",
    "com.bjango.istatmenus",
    "com.bjango.istatmenusstatus",
    "com.xbarapp.app",
  ]
}

func hidStatsFlagURL(pluginsDir: URL) -> URL {
  pluginsDir.appendingPathComponent(".one-screen-bottom.hid-stats")
}

func hideCompanionStatusApps(pluginsDir: URL) {
  for app in NSWorkspace.shared.runningApplications {
    guard let id = app.bundleIdentifier, companionStatusBundleIDs().contains(id) else { continue }
    if id == "eu.exelban.Stats" {
      FileManager.default.createFile(
        atPath: hidStatsFlagURL(pluginsDir: pluginsDir).path,
        contents: Data(),
        attributes: nil
      )
    }
    app.forceTerminate()
  }
}

func restoreCompanionStatusApps(pluginsDir: URL) {
  let flag = hidStatsFlagURL(pluginsDir: pluginsDir)
  guard FileManager.default.fileExists(atPath: flag.path) else { return }
  try? FileManager.default.removeItem(at: flag)
  if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "eu.exelban.Stats" }) {
    return
  }
  guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "eu.exelban.Stats") else { return }
  NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
}

func statusBarOwnerSummary() -> String {
  let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
  var names: [String] = []
  for item in info {
    let layer = item[kCGWindowLayer as String] as? Int ?? 0
    if layer < 24 || layer > 27 { continue }
    guard let name = item[kCGWindowOwnerName as String] as? String, !name.isEmpty else { continue }
    if !names.contains(name) { names.append(name) }
  }
  if names.isEmpty { return "none" }
  return names.joined(separator: ",")
}

func hideSystemBarsForStrip() {
  NSMenu.setMenuBarVisible(true)
  var opts = NSApp.presentationOptions
  opts.insert(.autoHideDock)
  NSApp.presentationOptions = opts
}

func restoreSystemBars() {
  NSMenu.setMenuBarVisible(true)
  var opts = NSApp.presentationOptions
  opts.remove(.autoHideDock)
  NSApp.presentationOptions = opts
}

func bottomBarRect(screenFrame: NSRect, height: CGFloat = 28) -> NSRect {
  NSRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: height)
}

func barWindowLevel() -> NSWindow.Level {
  NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
}

func frameIsOnTopHalf(_ frame: NSRect, screen: NSRect) -> Bool {
  frame.midY > screen.midY
}

func pinToBottom(_ window: NSWindow, screen: NSScreen) {
  let rect = bottomBarRect(screenFrame: screen.frame, height: 28)
  window.level = barWindowLevel()
  window.setFrame(rect, display: true)
  window.setFrameOrigin(NSPoint(x: rect.minX, y: rect.minY))
  if frameIsOnTopHalf(window.frame, screen: screen.frame) || abs(window.frame.minY - rect.minY) > 1 {
    window.setFrame(rect, display: true)
    window.setFrameOrigin(NSPoint(x: rect.minX, y: rect.minY))
  }
}

func workAreaMinY(screenFrame: NSRect, visibleFrame: NSRect, barHeight: CGFloat = 28) -> CGFloat {
  max(visibleFrame.minY, screenFrame.minY + barHeight)
}

func barProtrudesIntoWorkArea(screenFrame: NSRect, visibleFrame: NSRect, barHeight: CGFloat = 28) -> Bool {
  workAreaMinY(screenFrame: screenFrame, visibleFrame: visibleFrame, barHeight: barHeight) > visibleFrame.minY + 0.5
}

func windowNeedsLift(window: NSRect, bar: NSRect, screen: NSRect) -> Bool {
  if windowIsFullscreenLike(window, screen: screen) { return false }
  if window.minY >= bar.maxY - 1 { return false }
  if window.maxY <= bar.maxY + 1 { return false }
  return window.intersects(bar)
}

func windowIsFullscreenLike(_ window: NSRect, screen: NSRect) -> Bool {
  abs(window.minX - screen.minX) < 4
    && abs(window.maxX - screen.maxX) < 4
    && abs(window.minY - screen.minY) < 4
    && abs(window.maxY - screen.maxY) < 4
}

func quartzRect(fromAppKit rect: NSRect) -> CGRect {
  let globalMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? rect.maxY
  return CGRect(x: rect.minX, y: globalMaxY - rect.maxY, width: rect.width, height: rect.height)
}

func quartzBottomLimit(barTopAppKit: CGFloat) -> CGFloat {
  let globalMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? barTopAppKit
  return globalMaxY - barTopAppKit
}

func appKitRect(fromQuartz rect: CGRect) -> NSRect {
  let globalMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? (rect.minY + rect.height)
  return NSRect(x: rect.minX, y: globalMaxY - rect.maxY, width: rect.width, height: rect.height)
}

func anyOnscreenWindowOverlaps(_ bar: NSRect, on screen: NSScreen) -> Bool {
  let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
  let selfPid = Int(ProcessInfo.processInfo.processIdentifier)
  for item in info {
    guard let pid = item[kCGWindowOwnerPID as String] as? Int, pid != selfPid else { continue }
    guard let layer = item[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
    guard let bounds = item[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
    let quartz = CGRect(
      x: bounds["X"] ?? 0,
      y: bounds["Y"] ?? 0,
      width: bounds["Width"] ?? 0,
      height: bounds["Height"] ?? 0
    )
    let window = appKitRect(fromQuartz: quartz)
    if windowNeedsLift(window: window, bar: bar, screen: screen.frame) { return true }
  }
  return false
}

func promptAXOnce(pluginsDir: URL) {
  if AXIsProcessTrusted() { return }
  let flag = pluginsDir.appendingPathComponent(".one-screen-bottom.ax-prompted")
  if FileManager.default.fileExists(atPath: flag.path) { return }
  FileManager.default.createFile(atPath: flag.path, contents: Data(), attributes: nil)
  let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
  _ = AXIsProcessTrustedWithOptions(opts)
}

func liftStandardWindows(aboveBar bar: NSRect, on screen: NSScreen) {
  guard AXIsProcessTrusted() else { return }
  guard anyOnscreenWindowOverlaps(bar, on: screen) else { return }
  let maxBottom = quartzBottomLimit(barTopAppKit: bar.maxY)
  let screenQuartz = quartzRect(fromAppKit: screen.frame)
  let selfPid = ProcessInfo.processInfo.processIdentifier
  for app in NSWorkspace.shared.runningApplications {
    if app.isTerminated { continue }
    if app.processIdentifier == selfPid { continue }
    if app.bundleIdentifier == "com.apple.dock" { continue }
    let appEl = AXUIElementCreateApplication(app.processIdentifier)
    var windowsRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &windowsRef) == .success,
          let windows = windowsRef as? [AXUIElement]
    else { continue }
    for win in windows {
      liftWindowIfNeeded(win, maxQuartzBottom: maxBottom, screenQuartz: screenQuartz, bar: bar, screen: screen.frame)
    }
  }
}

func copyAXValue(_ ref: CFTypeRef?) -> AXValue? {
  guard let ref = ref else { return nil }
  guard CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
  return unsafeBitCast(ref, to: AXValue.self)
}

func liftWindowIfNeeded(
  _ win: AXUIElement,
  maxQuartzBottom: CGFloat,
  screenQuartz: CGRect,
  bar: NSRect,
  screen: NSRect
) {
  var roleRef: CFTypeRef?
  guard AXUIElementCopyAttributeValue(win, kAXRoleAttribute as CFString, &roleRef) == .success,
        let role = roleRef as? String,
        role == (kAXWindowRole as String)
  else { return }
  var subRef: CFTypeRef?
  if AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &subRef) == .success,
     let subrole = subRef as? String
  {
    let skip: Set<String> = [
      "AXDialog", "AXSystemDialog", "AXFloatingWindow", "AXPictureInPictureWindow", "AXUnknown",
    ]
    if skip.contains(subrole) { return }
  }
  var fullRef: CFTypeRef?
  if AXUIElementCopyAttributeValue(win, "AXFullScreen" as CFString, &fullRef) == .success,
     let full = fullRef as? Bool, full { return }
  var minRef: CFTypeRef?
  if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRef) == .success,
     let minimized = minRef as? Bool, minimized { return }
  var posRef: CFTypeRef?
  var sizeRef: CFTypeRef?
  guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
        AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success,
        let posAX = copyAXValue(posRef),
        let sizeAX = copyAXValue(sizeRef)
  else { return }
  var origin = CGPoint.zero
  var size = CGSize.zero
  guard AXValueGetValue(posAX, .cgPoint, &origin), AXValueGetValue(sizeAX, .cgSize, &size) else { return }
  let quartzWindow = CGRect(origin: origin, size: size)
  if windowIsFullscreenLike(
    NSRect(x: quartzWindow.minX, y: quartzWindow.minY, width: quartzWindow.width, height: quartzWindow.height),
    screen: NSRect(x: screenQuartz.minX, y: screenQuartz.minY, width: screenQuartz.width, height: screenQuartz.height)
  ) { return }
  let appKitWindow = appKitRect(fromQuartz: quartzWindow)
  guard windowNeedsLift(window: appKitWindow, bar: bar, screen: screen) else { return }
  let newHeight = maxQuartzBottom - origin.y
  if newHeight < 80 { return }
  if abs(newHeight - size.height) < 2 { return }
  var lifted = CGSize(width: size.width, height: newHeight)
  guard let encoded = AXValueCreate(.cgSize, &lifted) else { return }
  AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, encoded)
}

func closedFlagURL(pluginsDir: URL) -> URL {
  pluginsDir.appendingPathComponent(".one-screen-bottom.closed")
}

final class BottomWindow: NSWindow {
  var displayID: CGDirectDisplayID = 0
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    let match = screenMatching(id: displayID) ?? screen ?? self.screen
    guard let match else { return frameRect }
    return bottomBarRect(screenFrame: match.frame, height: 28)
  }
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

final class ScreenStrip {
  let displayID: CGDirectDisplayID
  let window: BottomWindow
  let stack: NSStackView
  let clockLabel: NSTextField
  init(display: NSScreen) {
    displayID = screenDisplayID(display)
    let rect = bottomBarRect(screenFrame: display.frame)
    let window = BottomWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
    window.displayID = displayID
    window.level = barWindowLevel()
    window.isOpaque = true
    window.backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 1)
    window.appearance = NSAppearance(named: .darkAqua)
    window.hasShadow = false
    window.hidesOnDeactivate = false
    window.isMovable = false
    window.isRestorable = false
    window.animationBehavior = .none
    window.collectionBehavior = [.stationary, .ignoresCycle, .canJoinAllSpaces]
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    overlayLog("created strip id=\(displayID) y=\(Int(rect.minY)) w=\(Int(rect.width))")
    let root = NSView(frame: NSRect(origin: .zero, size: rect.size))
    root.autoresizingMask = [.width, .height]
    root.wantsLayer = true
    root.layer?.backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 1).cgColor
    let hairline = NSView(frame: NSRect(x: 0, y: rect.height - 1, width: rect.width, height: 1))
    hairline.wantsLayer = true
    hairline.layer?.backgroundColor = NSColor(calibratedWhite: 0.42, alpha: 1).cgColor
    hairline.autoresizingMask = [.width, .minYMargin]
    root.addSubview(hairline)
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 10
    stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 8)
    stack.translatesAutoresizingMaskIntoConstraints = false
    let clock = NSTextField(labelWithString: "")
    clock.font = NSFont.menuBarFont(ofSize: 13)
    clock.textColor = NSColor.white
    window.contentView = root
    root.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      stack.topAnchor.constraint(equalTo: root.topAnchor),
      stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
    ])
    self.window = window
    self.stack = stack
    self.clockLabel = clock
  }
  var screen: NSScreen? { screenMatching(id: displayID) }
}

struct PluginSnapshot {
  var url: URL
  var name: String
  var title: String
  var body: String
}

final class BottomBarController: NSObject {
  private let pluginsDir: URL
  private var strips: [ScreenStrip] = []
  private var snapshots: [PluginSnapshot] = []
  private var clockTimer: Timer?
  private var pluginTimer: Timer?
  private var lastPinLog = ""
  private var firstPinDone = false
  init(pluginsDir: URL, marker: String) {
    self.pluginsDir = pluginsDir
    super.init()
    ProcessInfo.processInfo.processName = marker
    overlayLog("starting")
    applyPlacement()
    tickClock()
    clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.tickClock()
      self?.applyPlacement()
    }
    pluginTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
      self?.refreshPlugins()
    }
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil, queue: .main
    ) { [weak self] _ in self?.applyPlacement() }
    DispatchQueue.main.async { [weak self] in self?.refreshPlugins() }
  }
  private func syncStrips() {
    let ids = Set(NSScreen.screens.map(screenDisplayID))
    strips.removeAll { strip in
      if ids.contains(strip.displayID) { return false }
      strip.window.orderOut(nil)
      return true
    }
    for screen in NSScreen.screens {
      let id = screenDisplayID(screen)
      if strips.contains(where: { $0.displayID == id }) { continue }
      strips.append(ScreenStrip(display: screen))
    }
  }
  private func applyPlacement() {
    if FileManager.default.fileExists(atPath: closedFlagURL(pluginsDir: pluginsDir).path) {
      strips.forEach { $0.window.orderOut(nil) }
      restoreSystemBars()
      restoreCompanionStatusApps(pluginsDir: pluginsDir)
      restoreTopSwiftBar(pluginsDir: pluginsDir)
      NSApp.terminate(nil)
      return
    }
    let screens = NSScreen.screens
    if screens.isEmpty {
      overlayLog("waiting-for-screens")
      return
    }
    switch placement(screens: screens) {
    case .hidden:
      overlayLog("hidden-skipped, keeping bottom")
    case .bottom:
      break
    }
    hideSystemBarsForStrip()
    hideTopSwiftBar(pluginsDir: pluginsDir)
    hideCompanionStatusApps(pluginsDir: pluginsDir)
    syncStrips()
    rebuildButtons()
    var log = "screens=\(screens.count)"
    for strip in strips {
      guard let screen = strip.screen else {
        overlayLog("strip id=\(strip.displayID) missing screen")
        continue
      }
      pinToBottom(strip.window, screen: screen)
      strip.window.orderFront(nil)
      pinToBottom(strip.window, screen: screen)
      log +=
        " id=\(strip.displayID) y=\(Int(strip.window.frame.minY)) screenMinY=\(Int(screen.frame.minY))"
        + " topHalf=\(frameIsOnTopHalf(strip.window.frame, screen: screen.frame))"
        + " level=\(strip.window.level.rawValue)"
    }
    log += " stacked=\(hasStackedLowerDisplay(screens)) topOwners=\(statusBarOwnerSummary())"
    if log != lastPinLog {
      lastPinLog = log
      overlayLog(log)
    }
    if firstPinDone {
      for strip in strips {
        guard let screen = strip.screen else { continue }
        let rect = bottomBarRect(screenFrame: screen.frame)
        if barProtrudesIntoWorkArea(screenFrame: screen.frame, visibleFrame: screen.visibleFrame) {
          promptAXOnce(pluginsDir: pluginsDir)
        }
        liftStandardWindows(aboveBar: rect, on: screen)
      }
    }
    firstPinDone = true
  }
  private func tickClock() {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateFormat = "EEE d MMM  HH:mm"
    let text = formatter.string(from: Date())
    for strip in strips { strip.clockLabel.stringValue = text }
  }
  private func refreshPlugins() {
    snapshots = loadPlugins()
    applyPlacement()
  }
  private func rebuildButtons() {
    for strip in strips {
      strip.stack.views.forEach { $0.removeFromSuperview() }
      for (index, plugin) in snapshots.enumerated() {
        let button = NSButton(title: plugin.title, target: self, action: #selector(pluginClicked(_:)))
        button.tag = index
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = NSFont.menuBarFont(ofSize: 13)
        button.contentTintColor = NSColor.white
        button.attributedTitle = NSAttributedString(string: plugin.title, attributes: [
          .foregroundColor: NSColor.white, .font: NSFont.menuBarFont(ofSize: 13),
        ])
        strip.stack.addArrangedSubview(button)
      }
      let spacer = NSView()
      spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
      strip.stack.addArrangedSubview(spacer)
      strip.stack.addArrangedSubview(strip.clockLabel)
      strip.stack.addArrangedSubview(makeCloseButton())
    }
  }
  private func makeCloseButton() -> NSButton {
    let button = NSButton(title: "×", target: self, action: #selector(closeBar(_:)))
    button.bezelStyle = .inline
    button.isBordered = false
    button.font = NSFont.menuBarFont(ofSize: 14)
    button.contentTintColor = NSColor.white
    button.attributedTitle = NSAttributedString(string: "×", attributes: [
      .foregroundColor: NSColor.white, .font: NSFont.menuBarFont(ofSize: 14),
    ])
    button.toolTip = "Close bottom bar"
    return button
  }
  @objc private func closeBar(_: NSButton) {
    FileManager.default.createFile(atPath: closedFlagURL(pluginsDir: pluginsDir).path, contents: Data(), attributes: nil)
    restoreSystemBars()
    restoreCompanionStatusApps(pluginsDir: pluginsDir)
    restoreTopSwiftBar(pluginsDir: pluginsDir)
    NSApp.terminate(nil)
  }
  @objc private func pluginClicked(_ sender: NSButton) {
    guard snapshots.indices.contains(sender.tag) else { return }
    let plugin = snapshots[sender.tag]
    let menu = NSMenu()
    let lines = menuLines(from: plugin.body)
    if lines.isEmpty {
      let item = NSMenuItem(title: plugin.name, action: nil, keyEquivalent: "")
      item.isEnabled = false
      menu.addItem(item)
    } else {
      for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "---" { menu.addItem(.separator()); continue }
        if trimmed.hasPrefix("--") || trimmed.isEmpty { continue }
        let title = String(trimmed.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)[0]).trimmingCharacters(in: .whitespaces)
        if !title.isEmpty { menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: "")) }
      }
    }
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
  }
  private func loadPlugins() -> [PluginSnapshot] {
    let fm = FileManager.default
    guard let entries = try? fm.contentsOfDirectory(at: pluginsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
    return entries.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }.compactMap { url -> PluginSnapshot? in
      let name = url.lastPathComponent
      if name.hasPrefix("one-screen-bottom") { return nil }
      switch name {
      case "bin", "lib", "tests", "ticker", "apply.sh", "install.sh", "macos-install.sh", "README.md": return nil
      default: break
      }
      if name.contains(".disabled.") || name.hasSuffix(".off") { return nil }
      var isDir: ObjCBool = false
      fm.fileExists(atPath: url.path, isDirectory: &isDir)
      if isDir.boolValue { return nil }
      guard fm.isExecutableFile(atPath: url.path) else { return nil }
      let output = runPlugin(url)
      let title = titleLine(from: output)
      guard !title.isEmpty else { return nil }
      return PluginSnapshot(url: url, name: pluginDisplayName(name), title: title, body: output)
    }
  }
  private func runPlugin(_ url: URL) -> String {
    let proc = Process()
    proc.executableURL = url
    proc.currentDirectoryURL = pluginsDir
    var env = ProcessInfo.processInfo.environment
    env["SWIFTBAR"] = "1"
    env["SWIFTBAR_PLUGINS_PATH"] = pluginsDir.path
    env["SWIFTBAR_PLUGIN_PATH"] = url.path
    proc.environment = env
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = Pipe()
    do { try proc.run() } catch { return "" }
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global().async { proc.waitUntilExit(); group.leave() }
    if group.wait(timeout: .now() + 8) == .timedOut { proc.terminate(); return "" }
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  }
}

func pluginDisplayName(_ filename: String) -> String {
  var base = (filename as NSString).deletingPathExtension
  if let range = base.range(of: "[.][0-9]+[smhd]$", options: .regularExpression) { base.removeSubrange(range) }
  return base
}

func titleLine(from output: String) -> String {
  for raw in output.split(whereSeparator: \.isNewline) {
    let line = String(raw).trimmingCharacters(in: .whitespaces)
    if line == "---" { break }
    if line.isEmpty || line.hasPrefix("#") { continue }
    return String(line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)[0]).trimmingCharacters(in: .whitespaces)
  }
  return ""
}

func menuLines(from output: String) -> [String] {
  let parts = output.components(separatedBy: "\n---\n")
  guard parts.count > 1 else { return [] }
  return parts.dropFirst().joined(separator: "\n---\n").components(separatedBy: "\n")
}

func pluginsDirectory() -> URL {
  var dir: String?
  let args = Array(CommandLine.arguments.dropFirst())
  var i = 0
  while i < args.count {
    if args[i] == "--plugins-dir", i + 1 < args.count { dir = args[i + 1]; i += 2; continue }
    i += 1
  }
  if let dir = dir {
    let url = URL(fileURLWithPath: dir)
    if pathLooksLikeStub(url.path) { return url.deletingLastPathComponent() }
    return url
  }
  if let env = ProcessInfo.processInfo.environment["SWIFTBAR_PLUGINS_PATH"], !env.isEmpty {
    let url = URL(fileURLWithPath: env)
    if pathLooksLikeStub(url.path) { return url.deletingLastPathComponent() }
    return url
  }
  return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/swiftbar/plugins")
}

func markerArgument() -> String {
  let args = Array(CommandLine.arguments.dropFirst())
  var i = 0
  while i < args.count {
    if args[i] == "--marker", i + 1 < args.count { return args[i + 1] }
    i += 1
  }
  return "swiftbar-one-screen-bottom"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  var controller: BottomBarController?
  func applicationDidFinishLaunching(_ notification: Notification) {
    ProcessInfo.processInfo.disableSuddenTermination()
    overlayLog("launching")
    let dir = pluginsDirectory()
    if FileManager.default.fileExists(atPath: closedFlagURL(pluginsDir: dir).path) {
      overlayLog("closed-flag, exiting")
      NSApp.terminate(nil)
      return
    }
    controller = BottomBarController(pluginsDir: dir, marker: markerArgument())
  }
  func applicationWillTerminate(_ notification: Notification) {
    restoreSystemBars()
    let dir = pluginsDirectory()
    if FileManager.default.fileExists(atPath: closedFlagURL(pluginsDir: dir).path) {
      restoreCompanionStatusApps(pluginsDir: dir)
      restoreTopSwiftBar(pluginsDir: dir)
    }
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
