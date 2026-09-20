import Cocoa
import ApplicationServices

enum BarPlacement {
  case bottom
  case hidden
}

func placement(forScreenCount count: Int) -> BarPlacement {
  count <= 1 ? .bottom : .hidden
}

func bottomBarRect(screenFrame: NSRect, height: CGFloat = 28) -> NSRect {
  NSRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: height)
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
      "AXDialog",
      "AXSystemDialog",
      "AXFloatingWindow",
      "AXPictureInPictureWindow",
      "AXUnknown",
    ]
    if skip.contains(subrole) { return }
  }

  var fullRef: CFTypeRef?
  if AXUIElementCopyAttributeValue(win, "AXFullScreen" as CFString, &fullRef) == .success,
     let full = fullRef as? Bool, full
  {
    return
  }

  var minRef: CFTypeRef?
  if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRef) == .success,
     let minimized = minRef as? Bool, minimized
  {
    return
  }

  var posRef: CFTypeRef?
  var sizeRef: CFTypeRef?
  guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
        AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success,
        let posAX = posRef as? AXValue,
        let sizeAX = sizeRef as? AXValue
  else { return }

  var origin = CGPoint.zero
  var size = CGSize.zero
  guard AXValueGetValue(posAX, .cgPoint, &origin), AXValueGetValue(sizeAX, .cgSize, &size) else { return }

  let quartzWindow = CGRect(origin: origin, size: size)
  if windowIsFullscreenLike(
    NSRect(x: quartzWindow.minX, y: quartzWindow.minY, width: quartzWindow.width, height: quartzWindow.height),
    screen: NSRect(x: screenQuartz.minX, y: screenQuartz.minY, width: screenQuartz.width, height: screenQuartz.height)
  ) {
    return
  }

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
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

struct PluginSnapshot {
  var url: URL
  var name: String
  var title: String
  var body: String
}

final class BottomBarController: NSObject {
  private let pluginsDir: URL
  private var panel: NSWindow!
  private var stack: NSStackView!
  private var clockLabel: NSTextField!
  private var snapshots: [PluginSnapshot] = []
  private var clockTimer: Timer?
  private var pluginTimer: Timer?

  init(pluginsDir: URL, marker: String) {
    self.pluginsDir = pluginsDir
    super.init()
    ProcessInfo.processInfo.processName = marker
    buildPanel()
    refreshPlugins()
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
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.applyPlacement()
    }
  }

  private func buildPanel() {
    let panel = BottomWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 28),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isMovable = false
    panel.animationBehavior = .none
    panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true

    let fx = NSVisualEffectView()
    fx.material = .menu
    fx.blendingMode = .behindWindow
    fx.state = .active
    fx.translatesAutoresizingMaskIntoConstraints = false

    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 10
    stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 8)
    stack.translatesAutoresizingMaskIntoConstraints = false

    let clock = NSTextField(labelWithString: "")
    clock.font = NSFont.menuBarFont(ofSize: 13)
    clock.textColor = .labelColor

    panel.contentView = fx
    fx.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: fx.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
      stack.topAnchor.constraint(equalTo: fx.topAnchor),
      stack.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
    ])

    self.panel = panel
    self.stack = stack
    self.clockLabel = clock
  }

  private func applyPlacement() {
    if FileManager.default.fileExists(atPath: closedFlagURL(pluginsDir: pluginsDir).path) {
      panel.orderOut(nil)
      NSApp.terminate(nil)
      return
    }
    switch placement(forScreenCount: NSScreen.screens.count) {
    case .hidden:
      panel.orderOut(nil)
    case .bottom:
      guard let screen = NSScreen.screens.min(by: { $0.frame.minY < $1.frame.minY }) ?? NSScreen.screens.first else {
        panel.orderOut(nil)
        return
      }
      let rect = bottomBarRect(screenFrame: screen.frame)
      panel.setFrame(rect, display: true)
      if abs(panel.frame.minY - rect.minY) > 1 {
        panel.setFrameOrigin(NSPoint(x: rect.minX, y: rect.minY))
      }
      panel.orderFrontRegardless()
      if barProtrudesIntoWorkArea(screenFrame: screen.frame, visibleFrame: screen.visibleFrame) {
        promptAXOnce(pluginsDir: pluginsDir)
      }
      liftStandardWindows(aboveBar: rect, on: screen)
    }
  }

  private func tickClock() {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateFormat = "EEE d MMM  HH:mm"
    clockLabel.stringValue = formatter.string(from: Date())
  }

  private func refreshPlugins() {
    snapshots = loadPlugins()
    rebuildButtons()
    applyPlacement()
  }

  private func rebuildButtons() {
    stack.views.forEach { $0.removeFromSuperview() }
    for (index, plugin) in snapshots.enumerated() {
      let button = NSButton(title: plugin.title, target: self, action: #selector(pluginClicked(_:)))
      button.tag = index
      button.bezelStyle = .inline
      button.isBordered = false
      button.font = NSFont.menuBarFont(ofSize: 13)
      stack.addArrangedSubview(button)
    }
    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    stack.addArrangedSubview(spacer)
    stack.addArrangedSubview(clockLabel)
    stack.addArrangedSubview(makeCloseButton())
  }

  private func makeCloseButton() -> NSButton {
    let button = NSButton(title: "×", target: self, action: #selector(closeBar(_:)))
    button.bezelStyle = .inline
    button.isBordered = false
    button.font = NSFont.menuBarFont(ofSize: 14)
    button.toolTip = "Close bottom bar"
    return button
  }

  @objc private func closeBar(_: NSButton) {
    FileManager.default.createFile(
      atPath: closedFlagURL(pluginsDir: pluginsDir).path,
      contents: Data(),
      attributes: nil
    )
    if let url = URL(string: "swiftbar://refreshallplugins") {
      NSWorkspace.shared.open(url)
    }
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
        if trimmed == "---" {
          menu.addItem(.separator())
          continue
        }
        if trimmed.hasPrefix("--") || trimmed.isEmpty { continue }
        let title = String(trimmed.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)[0])
          .trimmingCharacters(in: .whitespaces)
        if !title.isEmpty {
          menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
        }
      }
    }
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
  }

  private func loadPlugins() -> [PluginSnapshot] {
    let fm = FileManager.default
    guard let entries = try? fm.contentsOfDirectory(
      at: pluginsDir,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else { return [] }

    return entries
      .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
      .compactMap { url -> PluginSnapshot? in
        let name = url.lastPathComponent
        if name.hasPrefix("one-screen-bottom") {
          return nil
        }
        switch name {
        case "bin", "lib", "tests", "ticker", "apply.sh", "install.sh", "macos-install.sh", "README.md":
          return nil
        default:
          break
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
    DispatchQueue.global().async {
      proc.waitUntilExit()
      group.leave()
    }
    if group.wait(timeout: .now() + 8) == .timedOut {
      proc.terminate()
      return ""
    }
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  }
}

func pluginDisplayName(_ filename: String) -> String {
  var base = (filename as NSString).deletingPathExtension
  if let range = base.range(of: "[.][0-9]+[smhd]$", options: .regularExpression) {
    base.removeSubrange(range)
  }
  return base
}

func titleLine(from output: String) -> String {
  for raw in output.split(whereSeparator: \.isNewline) {
    let line = String(raw).trimmingCharacters(in: .whitespaces)
    if line == "---" { break }
    if line.isEmpty || line.hasPrefix("#") { continue }
    return String(line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)[0])
      .trimmingCharacters(in: .whitespaces)
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
  var args = Array(CommandLine.arguments.dropFirst())
  var i = 0
  while i < args.count {
    if args[i] == "--plugins-dir", i + 1 < args.count {
      dir = args[i + 1]
      i += 2
      continue
    }
    i += 1
  }
  if let dir { return URL(fileURLWithPath: dir) }
  if let env = ProcessInfo.processInfo.environment["SWIFTBAR_PLUGINS_PATH"], !env.isEmpty {
    return URL(fileURLWithPath: env)
  }
  return URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent(".config/swiftbar/plugins")
}

func markerArgument() -> String {
  var args = Array(CommandLine.arguments.dropFirst())
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
    let dir = pluginsDirectory()
    if FileManager.default.fileExists(atPath: closedFlagURL(pluginsDir: dir).path) {
      NSApp.terminate(nil)
      return
    }
    controller = BottomBarController(pluginsDir: dir, marker: markerArgument())
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
