# SafariSwipe

Safari's two-finger swipe back/forward plays a slow page-slide animation. SafariSwipe replaces it: a two-finger swipe in Safari instantly sends **⌘[** (back) or **⌘]** (forward), with a small Chrome-style arrow that slides in from the window edge while you swipe.

It's a tiny background app with no Dock icon or window.

## Install

1. Download `SafariSwipe.dmg` from [Releases](../../releases) and drag **SafariSwipe** into **Applications**.
2. The app isn't notarized, so the first launch is blocked. Open it once, then go to **System Settings › Privacy & Security** and click **Open Anyway**. Or run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/SafariSwipe.app
   ```
3. Turn off **System Settings › Trackpad › More Gestures › Swipe between pages**. Otherwise Safari still plays its own animation.
4. Launch SafariSwipe. It opens **Privacy & Security › Accessibility**. Switch **SafariSwipe** on there, and it starts working right away.
5. Optional: add it under **System Settings › General › Login Items** so it starts when you log in.

Requires an Apple Silicon Mac running macOS 13 or later.

## How to use

In Safari, swipe two fingers left to right to go back, or right to left to go forward.

Turning off "Swipe between pages" affects every app, so swipe navigation in apps like Preview stops working too.

## Build from source

```bash
./build.sh
```

This builds `SafariSwipe.app` in the project folder and runs a self-test. Each rebuild changes the ad-hoc code signature, so macOS asks for Accessibility access again. To clear the old entry:

```bash
tccutil reset Accessibility local.biye.SafariSwipe
```

Status and errors are logged to `~/Library/Logs/SafariSwipe.log`.

## Known limits

- The shortcut keys are sent as US-layout `[` and `]` positions. Other keyboard layouts may need different key codes in `main.swift`.
- On pages that scroll sideways, a long horizontal scroll also goes back or forward.
