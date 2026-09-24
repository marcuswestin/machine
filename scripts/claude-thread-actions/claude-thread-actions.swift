#!/usr/bin/env swift
/**
 Claude Desktop thread Pin/Archive via Accessibility.

 Discovers the focused Code-tab session from local session manifests
 (lastFocusedAt), opens its sidebar "More options" menu through AX, then
 either reports available actions (default dry-run) or presses Pin/Unpin
 or Archive.

 Requires: macOS Accessibility permission for the process running this
 script (Terminal, iTerm, Swift, or a compiled binary).

 Usage:
   swift scripts/claude-thread-actions/claude-thread-actions.swift
   swift scripts/claude-thread-actions/claude-thread-actions.swift --dry-run
   swift scripts/claude-thread-actions/claude-thread-actions.swift --pin
   swift scripts/claude-thread-actions/claude-thread-actions.swift --archive
   swift scripts/claude-thread-actions/claude-thread-actions.swift --unpin
 */

import ApplicationServices
import AppKit
import Foundation

// MARK: - AX helpers

func axAttr(_ el: AXUIElement, _ name: String) -> AnyObject? {
  var value: AnyObject?
  let err = AXUIElementCopyAttributeValue(el, name as CFString, &value)
  return err == .success ? value : nil
}

@discardableResult
func axSet(_ el: AXUIElement, _ name: String, _ value: AnyObject) -> AXError {
  AXUIElementSetAttributeValue(el, name as CFString, value)
}

func axStr(_ el: AXUIElement, _ name: String) -> String? {
  axAttr(el, name) as? String
}

func axChildren(_ el: AXUIElement) -> [AXUIElement] {
  (axAttr(el, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
}

func axRole(_ el: AXUIElement) -> String {
  axStr(el, kAXRoleAttribute as String) ?? "?"
}

func axLabel(_ el: AXUIElement) -> String {
  let title = axStr(el, kAXTitleAttribute as String) ?? ""
  if !title.isEmpty { return title }
  return axStr(el, kAXDescriptionAttribute as String) ?? ""
}

@discardableResult
func axPerform(_ el: AXUIElement, _ action: String) -> AXError {
  AXUIElementPerformAction(el, action as CFString)
}

func axWalk(_ el: AXUIElement, _ body: (AXUIElement) -> Void) {
  body(el)
  for child in axChildren(el) {
    axWalk(child, body)
  }
}

func postKey(_ keyCode: CGKeyCode, down: Bool) {
  let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down)
  event?.post(tap: .cghidEventTap)
}

func pressEscape() {
  postKey(53, down: true)
  postKey(53, down: false)
}

// MARK: - Session discovery

struct SessionInfo {
  var sessionId: String
  var title: String
  var isStarred: Bool
  var lastFocusedAt: Double
  var path: String
}

func loadActiveSessions() -> [SessionInfo] {
  let root = NSHomeDirectory() + "/Library/Application Support/Claude/claude-code-sessions"
  guard let enumerator = FileManager.default.enumerator(atPath: root) else { return [] }
  var sessions: [SessionInfo] = []
  for case let relative as String in enumerator {
    guard relative.hasSuffix(".json") else { continue }
    let path = root + "/" + relative
    guard
      let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let sessionId = json["sessionId"] as? String,
      let title = json["title"] as? String,
      (json["isArchived"] as? Bool) != true
    else { continue }
    let focused: Double
    if let n = json["lastFocusedAt"] as? Double {
      focused = n
    } else if let n = json["lastFocusedAt"] as? Int {
      focused = Double(n)
    } else {
      focused = 0
    }
    sessions.append(
      SessionInfo(
        sessionId: sessionId,
        title: title,
        isStarred: (json["isStarred"] as? Bool) == true,
        lastFocusedAt: focused,
        path: path
      )
    )
  }
  return sessions.sorted { $0.lastFocusedAt > $1.lastFocusedAt }
}

// MARK: - Claude AX

func claudeApplicationElement() -> (NSRunningApplication, AXUIElement)? {
  let apps = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.anthropic.claudefordesktop"
  )
  guard let app = apps.first else { return nil }
  let el = AXUIElementCreateApplication(app.processIdentifier)
  // Unlock Chromium's full AX tree (otherwise sidebar rows are invisible).
  _ = axSet(el, "AXEnhancedUserInterface", kCFBooleanTrue)
  return (app, el)
}

func findSidebarRoot(in appEl: AXUIElement) -> AXUIElement? {
  var sidebar: AXUIElement?
  axWalk(appEl) { el in
    // Chromium exposes the left nav as a group named "Sidebar".
    if axLabel(el) == "Sidebar" {
      sidebar = el
    }
  }
  return sidebar
}

func findMoreOptionsButton(in appEl: AXUIElement, sessionTitle: String) -> AXUIElement? {
  let needle = "More options for \(sessionTitle)"
  // Prefer the sidebar control: the main pane also has a "More options for <title>"
  // popup whose menu lacks Pin/Unpin.
  let roots: [AXUIElement] = {
    if let sidebar = findSidebarRoot(in: appEl) { return [sidebar, appEl] }
    return [appEl]
  }()
  for root in roots {
    var match: AXUIElement?
    axWalk(root) { el in
      guard axRole(el) == "AXPopUpButton" else { return }
      if axLabel(el) == needle {
        match = el
      }
    }
    if let match { return match }
  }
  return nil
}

func findSessionMenu(in appEl: AXUIElement) -> (AXUIElement, [AXUIElement])? {
  var found: (AXUIElement, [AXUIElement])?
  axWalk(appEl) { el in
    guard axRole(el) == "AXMenu" else { return }
    let items = axChildren(el)
    let labels = items.map(axLabel)
    // Sidebar session menu always offers Pin or Unpin. The main-pane
    // "More options" menu has Archive/Rename/Fork but not Pin — ignore it.
    guard labels.contains("Pin") || labels.contains("Unpin") else { return }
    found = (el, items)
  }
  return found
}

func waitForSessionMenu(in appEl: AXUIElement, timeoutMs: Int) -> (AXUIElement, [AXUIElement], Double)? {
  let start = CFAbsoluteTimeGetCurrent()
  let deadline = start + Double(timeoutMs) / 1000.0
  while CFAbsoluteTimeGetCurrent() < deadline {
    if let menu = findSessionMenu(in: appEl) {
      let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
      return (menu.0, menu.1, ms)
    }
    usleep(5_000)
  }
  return nil
}

enum Action: String {
  case pin
  case unpin
  case archive
  case dryRun = "dry-run"
}

func menuItemLabel(for action: Action, isStarred: Bool) -> String? {
  switch action {
  case .pin:
    return isStarred ? nil : "Pin"
  case .unpin:
    return isStarred ? "Unpin" : nil
  case .archive:
    return "Archive"
  case .dryRun:
    return nil
  }
}

func run(action: Action) -> Int32 {
  let t0 = CFAbsoluteTimeGetCurrent()
  func elapsed() -> Double { (CFAbsoluteTimeGetCurrent() - t0) * 1000 }

  guard AXIsProcessTrusted() else {
    fputs("error: this process is not trusted for Accessibility\n", stderr)
    fputs("Grant access in System Settings → Privacy & Security → Accessibility,\n", stderr)
    fputs("then re-run from the same app (Terminal/iTerm/compiled binary).\n", stderr)
    return 2
  }

  guard let (app, appEl) = claudeApplicationElement() else {
    fputs("error: Claude Desktop is not running (com.anthropic.claudefordesktop)\n", stderr)
    return 3
  }

  let sessions = loadActiveSessions()
  guard let current = sessions.first else {
    fputs("error: no active (non-archived) local sessions found\n", stderr)
    return 4
  }

  print("session: \(current.title)")
  print("sessionId: \(current.sessionId)")
  print("isStarred(pinned): \(current.isStarred)")
  print(String(format: "discover_ms: %.1f", elapsed()))

  // Always activate: AXPress on the sidebar popup is unreliable if Claude
  // was frontmost but not key in the way Chromium expects.
  app.activate()
  usleep(50_000)

  // Enhanced tree can take a beat after AXEnhancedUserInterface.
  var moreButton: AXUIElement?
  for _ in 0..<50 {
    moreButton = findMoreOptionsButton(in: appEl, sessionTitle: current.title)
    if moreButton != nil { break }
    usleep(5_000)
  }

  guard let button = moreButton else {
    fputs(
      "error: could not find sidebar control \"More options for \(current.title)\"\n",
      stderr
    )
    fputs("Is the Code sidebar visible and the session scrolled into view?\n", stderr)
    return 5
  }
  print(String(format: "found_more_options_ms: %.1f", elapsed()))

  _ = axPerform(button, "AXScrollToVisible")

  // Hover the control first — the "…" affordance is hover-revealed in the UI
  // and AXPress is more reliable after the cursor is over it.
  if let posVal = axAttr(button, kAXPositionAttribute as String),
     let sizeVal = axAttr(button, kAXSizeAttribute as String)
  {
    var origin = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(posVal as! AXValue, .cgPoint, &origin)
    AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
    let center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    if let move = CGEvent(
      mouseEventSource: nil,
      mouseType: .mouseMoved,
      mouseCursorPosition: center,
      mouseButton: .left
    ) {
      move.post(tap: .cghidEventTap)
      usleep(25_000)
    }
  }

  // AXShowMenu often returns success without opening this Chromium popup.
  // AXPress reliably opens the sidebar session menu after hover.
  let pressErr = axPerform(button, kAXPressAction as String)
  if pressErr != .success {
    fputs("error: AXPress failed (\(pressErr.rawValue)); trying AXShowMenu\n", stderr)
    let showErr = axPerform(button, "AXShowMenu")
    if showErr != .success {
      fputs("error: AXShowMenu also failed (\(showErr.rawValue))\n", stderr)
      return 6
    }
  }

  guard let (menu, items, menuWaitMs) = waitForSessionMenu(in: appEl, timeoutMs: 800) else {
    fputs("error: session context menu did not appear\n", stderr)
    pressEscape()
    return 7
  }
  _ = menu
  print(String(format: "menu_visible_ms: %.1f (waited %.1f)", elapsed(), menuWaitMs))
  let labels = items.map(axLabel).filter { !$0.isEmpty }
  print("menu: \(labels.joined(separator: " | "))")

  if action == .dryRun {
    let pinLabel = current.isStarred ? "Unpin" : "Pin"
    let hasPin = labels.contains(pinLabel)
    let hasArchive = labels.contains("Archive")
    print("dry_run: would press \(pinLabel) (\(hasPin ? "present" : "MISSING")), Archive (\(hasArchive ? "present" : "MISSING"))")
    pressEscape()
    usleep(20_000)
    print(String(format: "total_ms: %.1f", elapsed()))
    print("ok: dry-run complete (no mutation)")
    return 0
  }

  guard let want = menuItemLabel(for: action, isStarred: current.isStarred) else {
    if action == .pin {
      print("noop: session is already pinned (menu shows Unpin)")
    } else if action == .unpin {
      print("noop: session is not pinned (menu shows Pin)")
    }
    pressEscape()
    print(String(format: "total_ms: %.1f", elapsed()))
    return 0
  }

  guard let target = items.first(where: { axLabel($0) == want }) else {
    fputs("error: menu item \"\(want)\" not found\n", stderr)
    pressEscape()
    return 8
  }

  let itemErr = axPerform(target, kAXPressAction as String)
  if itemErr != .success {
    fputs("error: AXPress on \"\(want)\" failed (\(itemErr.rawValue))\n", stderr)
    pressEscape()
    return 9
  }
  print("pressed: \(want)")
  print(String(format: "total_ms: %.1f", elapsed()))
  print("ok: \(action.rawValue)")
  return 0
}

// MARK: - CLI

let args = Array(CommandLine.arguments.dropFirst())
var action: Action = .dryRun
if args.contains("-h") || args.contains("--help") {
  print(
    """
    Claude Desktop thread Pin/Archive (Accessibility)

    Usage:
      claude-thread-actions.swift [--dry-run | --pin | --unpin | --archive]

    Default is --dry-run (opens the menu, lists items, Escapes; no mutation).
    """
  )
  exit(0)
}
if args.contains("--pin") { action = .pin }
else if args.contains("--unpin") { action = .unpin }
else if args.contains("--archive") { action = .archive }
else if args.contains("--dry-run") || args.isEmpty { action = .dryRun }
else {
  fputs("unknown args: \(args.joined(separator: " "))\n", stderr)
  exit(1)
}

exit(run(action: action))
