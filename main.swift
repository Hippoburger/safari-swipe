// SafariSwipe: a two-finger horizontal swipe in Safari sends ⌘[ / ⌘] instantly,
// skipping Safari's slow page-slide animation.
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

var dx: CGFloat = 0, dy: CGFloat = 0, fired = false
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
    log("\(nav) (accessibility trusted: \(AXIsProcessTrusted()))")
    // shortcut: virtual key codes are US-layout positions of [ and ]; remap if your layout differs.
    let key: CGKeyCode = nav == .back ? 0x21 : 0x1E
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)
        e?.flags = .maskCommand
        e?.post(tap: .cghidEventTap)
    }
}

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    guard let ns = NSEvent(cgEvent: event), ns.hasPreciseScrollingDeltas,
          ns.momentumPhase.isEmpty  // ignore inertia after lift-off
    else { return Unmanaged.passUnretained(event) }

    if ns.phase.contains(.began) { dx = 0; dy = 0; fired = false }
    // Normalise to finger direction regardless of the natural-scrolling setting.
    dx += ns.isDirectionInvertedFromDevice ? ns.scrollingDeltaX : -ns.scrollingDeltaX
    dy += ns.scrollingDeltaY
    let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    if front == "com.apple.Safari", !fired, let nav = decide(dx: dx, dy: dy) { fired = true; send(nav) }
    if ns.phase.contains(.ended), abs(dx) > abs(dy) {
        log("sideways gesture dx=\(Int(dx)) dy=\(Int(dy)) front=\(front ?? "?") fired=\(fired)")
    }
    return Unmanaged.passUnretained(event)
}

// Accessibility is needed to send the keystrokes. The system prompt only appears once per app,
// so if we're not trusted also open the settings page and wait for the switch to be flipped.
log("started, accessibility trusted: \(AXIsProcessTrusted())")
if !AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
        if AXIsProcessTrusted() { log("accessibility granted"); t.invalidate() }
    }
}

tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                        eventsOfInterest: 1 << CGEventType.scrollWheel.rawValue,
                        callback: callback, userInfo: nil)
guard let tap else { log("could not create event tap"); exit(1) }
log("event tap ready")
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

NSApplication.shared.setActivationPolicy(.accessory)  // no Dock icon
NSApplication.shared.run()
