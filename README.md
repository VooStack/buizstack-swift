# BuizStack for iOS

Errors, crashes, hangs, product events, screens and session replay from native iOS apps (UIKit and
SwiftUI) to [BuizStack](https://buizstack.com). iOS 15 or later, Swift Package Manager.

In Xcode choose File > Add Package Dependencies and enter `https://github.com/VooStack/buizstack-swift`, or in
`Package.swift`:

```swift
.package(url: "https://github.com/VooStack/buizstack-swift", from: "0.1.0")
```

```swift
import BuizStack

BuizStack.start(
    dsn: "https://<public key>@ingest.buizstack.com/<app id>",
    serviceName: "shop-ios",
    release: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
    replay: ReplayOptions()
)

BuizStack.identify(user.id, email: user.email)
BuizStack.track("checkout_completed", properties: ["plan": "pro"])
BuizStack.captureException(error)
```

## What it sends

- **Errors**: `captureException`, uncaught Objective-C exceptions (saved and sent on the next launch),
  crashes and hangs from MetricKit diagnostics (delivered on the next launch), and a 5 second main-thread
  hang watchdog.
- **Screens and events**: every view controller that appears (containers and system controllers are
  skipped; call `trackScreen` for SwiftUI screens), plus `track` calls.
- **Session replay**: by default the last 60 seconds are kept in memory and uploaded only when an error
  happens; `sessionSampleRate` records whole sessions. Project settings in BuizStack can turn replay off,
  change the sample rates, mask all text, or always record chosen environments, releases and users.

## Privacy and performance

Masking happens on the device before a frame is encoded. Text fields, editable text views and secure
fields are always masked, images are masked by default, web views are always masked, and
`ReplayOptions(maskAllText: true)` masks labels too. Set `view.buizStackReplayMasked = true` (or `false`)
on any UIView, and use `.buizStackReplayMask()` on SwiftUI views, whose text and images are not UIKit
views and so are not masked automatically.

The main thread collects mask rectangles (2 ms budget, abandoned beyond it) and draws a 360 px wide
snapshot about once a second, taken only when the main run loop is about to go idle and never while the user is touching or scrolling (touches defer it up to 3 seconds). Encoding to
H.264 runs on a background queue, and capture stops while the app is not active.

## Develop

```
xcodebuild test -scheme BuizStack -destination 'platform=iOS Simulator,name=iPhone 17'
```

The source lives in the BuizStack monorepo under `sdks/ios` and is mirrored to
[VooStack/buizstack-swift](https://github.com/VooStack/buizstack-swift) for Swift Package Manager.
