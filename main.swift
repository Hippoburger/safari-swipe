// SafariSwipe: a two-finger horizontal swipe in Safari sends ⌘[ / ⌘] instantly,
// skipping Safari's slow page-slide animation. A Chrome-style arrow slides in from the
// window edge while you swipe.
// Needs System Settings › Trackpad › More Gestures › "Swipe between pages" turned off,
// otherwise Safari still plays its own animation too.
import AppKit

enum Nav { case back, forward }

let threshold: CGFloat = 60  // points of horizontal travel before we fire

// Finger direction: >0 = fingers moved right (back), <0 = left (forward).
func decide(dx: CGFloat, dy: CGFloat) -> Nav? {
    guard abs(dx) >= threshold, abs(dx) > 2 * abs(dy) else { return nil }
    return dx > 0 ? .back : .forward
}

if CommandLine.arguments.contains("--selftest") {
    assert(decide(dx: 100, dy: 10) == .back)
    assert(decide(dx: -100, dy: 10) == .forward)
    assert(decide(dx: 30, dy: 0) == nil)     // too short
    assert(decide(dx: 100, dy: 80) == nil)   // mostly vertical / diagonal
    print("selftest ok")
    exit(0)
}

NSApplication.shared.setActivationPolicy(.accessory)  // no Dock icon; NSApp must exist before the panel

var dx: CGFloat = 0, dy: CGFloat = 0, fired = false
var gesture = 0                // bumped per gesture so a late fade-out can't hide the next arrow
var safariFrame: NSRect?       // Safari's front window, looked up once per gesture
var tap: CFMachPort?

// Launched from Finder there is no terminal, so status goes to ~/Library/Logs/SafariSwipe.log.
func log(_ s: String) {
    print(s)
    let url = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Logs/SafariSwipe.log")
    let line = Data("\(Date()) \(s)\n".utf8)
    if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(line); h.closeFile() }
    else { try? line.write(to: url) }
}

func send(_ nav: Nav) {
    // shortcut: virtual key codes are US-layout positions of [ and ]; remap if your layout differs.
    let key: CGKeyCode = nav == .back ? 0x21 : 0x1E
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)
        e?.flags = .maskCommand
        e?.post(tap: .cghidEventTap)
    }
}

// MARK: Arrow overlay

let arrowSize: CGFloat = 44
let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: arrowSize, height: arrowSize),
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
let arrow = NSImageView(frame: NSRect(x: 0, y: 0, width: arrowSize, height: arrowSize))

func setupArrow() {
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.ignoresMouseEvents = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    let circle = NSView(frame: arrow.frame)
    circle.wantsLayer = true
    circle.layer?.cornerRadius = arrowSize / 2
    circle.addSubview(arrow)
    arrow.symbolConfiguration = .init(pointSize: 18, weight: .semibold)
    panel.contentView = circle
}

func styleArrow(_ nav: Nav, highlighted: Bool) {
    arrow.image = NSImage(systemSymbolName: nav == .back ? "arrow.left" : "arrow.right",
                          accessibilityDescription: nil)
    arrow.contentTintColor = highlighted ? .white : .labelColor
    panel.contentView?.layer?.backgroundColor =
        (highlighted ? NSColor.controlAccentColor : NSColor.windowBackgroundColor).cgColor
}

// Front Safari window in Cocoa coordinates (CGWindowList uses a top-left origin).
func frontWindowFrame(pid: pid_t) -> NSRect? {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []
    guard let w = list.first(where: { $0[kCGWindowOwnerPID as String] as? pid_t == pid
                                      && $0[kCGWindowLayer as String] as? Int == 0 }),
          let b = w[kCGWindowBounds as String] as? NSDictionary,
          let r = CGRect(dictionaryRepresentation: b),
          let primary = NSScreen.screens.first
    else { return nil }
    return NSRect(x: r.minX, y: primary.frame.maxY - r.maxY, width: r.width, height: r.height)
}

// Slides the arrow in from the window edge on the side we're heading to, by progress 0...1.
func showArrow(_ nav: Nav, progress: CGFloat) {
    guard let f = safariFrame else { return }
    let travel = arrowSize + 16
    let x = nav == .back ? f.minX - arrowSize + progress * travel : f.maxX - progress * travel
    panel.setFrameOrigin(NSPoint(x: x, y: f.midY - arrowSize / 2))
    panel.alphaValue = progress
    panel.orderFrontRegardless()
}

func hideArrow(after delay: TimeInterval) {
    let g = gesture
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        guard g == gesture else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; panel.animator().alphaValue = 0 }) {
            if g == gesture { panel.orderOut(nil) }
        }
    }
}

// MARK: Gesture handling

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    guard let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier == "com.apple.Safari",
          let ns = NSEvent(cgEvent: event), ns.hasPreciseScrollingDeltas,
          ns.momentumPhase.isEmpty  // ignore inertia after lift-off
    else { return Unmanaged.passUnretained(event) }

    if ns.phase.contains(.began) {
        dx = 0; dy = 0; fired = false; gesture += 1
        safariFrame = frontWindowFrame(pid: app.processIdentifier)
    }
    // Normalise to finger direction regardless of the natural-scrolling setting.
    dx += ns.isDirectionInvertedFromDevice ? ns.scrollingDeltaX : -ns.scrollingDeltaX
    dy += ns.scrollingDeltaY

    if !fired {
        if let nav = decide(dx: dx, dy: dy) {
            fired = true
            send(nav)
            styleArrow(nav, highlighted: true)
            showArrow(nav, progress: 1)
            hideArrow(after: 0.15)
        } else if abs(dx) > 2 * abs(dy) {
            let nav: Nav = dx > 0 ? .back : .forward
            styleArrow(nav, highlighted: false)
            showArrow(nav, progress: min(abs(dx) / threshold, 1))
        }
    }
    if ns.phase.contains(.ended) || ns.phase.contains(.cancelled), !fired { hideArrow(after: 0) }
    return Unmanaged.passUnretained(event)
}

func startTap() {
    tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                            eventsOfInterest: 1 << CGEventType.scrollWheel.rawValue,
                            callback: callback, userInfo: nil)
    guard let tap else { log("could not create event tap"); exit(1) }
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    log("event tap ready")
}

setupArrow()

// Without Accessibility the tap sees no events and keystrokes are dropped. The system prompt only
// appears once per app, so also open the settings page, and start the tap once access is granted.
log("started, accessibility trusted: \(AXIsProcessTrusted())")
if AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) {
    startTap()
} else {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
        if AXIsProcessTrusted() { log("accessibility granted"); t.invalidate(); startTap() }
    }
}

NSApplication.shared.run()
