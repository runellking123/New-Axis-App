# Share Extension Setup

Files are committed under `AxisShareExtension/`. The Xcode target itself has to be added by hand — Apple's project format makes that the safest path. Two minutes of clicks, then you're done.

## What this extension does

When you tap the iOS Share Sheet from any app (Safari, Mail, Messages, anywhere), **Add to Axis** appears. Picking it shows a small compose sheet with the shared text/URL prefilled. Hitting *Post* hands the title to the main app via the `axis://reminder?title=...` URL handler, where `QuickAddParser` does the rest — natural-language tokens like `tomorrow 5pm p1 #work` get parsed into due date, priority, and labels.

No app group or shared persistence is needed for the basic flow. The entitlements file is staged in case you later want to share data directly between the extension and the main app.

## One-time Xcode steps

1. Open `Axis.xcodeproj` in Xcode.
2. **File → New → Target…** → iOS tab → **Share Extension** → *Next*.
   - Product Name: `AxisShareExtension`
   - Team / Organization: same as Axis
   - Bundle Identifier: `com.runellking.axis.AxisShareExtension`
   - Embed in Application: **Axis**
   - Click *Finish*. Decline the activation prompt.
3. **Delete** the Swift / Storyboard files Xcode just generated under the new `AxisShareExtension` group — keep the *group* itself.
4. Right-click the empty `AxisShareExtension` group → **Add Files to "Axis"…** and select the four files in `AxisShareExtension/`:
   - `ShareViewController.swift`
   - `Info.plist`
   - `MainInterface.storyboard`
   - `AxisShareExtension.entitlements`
   Make sure *Add to targets* has **only AxisShareExtension** checked (NOT Axis).
5. Select the `AxisShareExtension` target → **Build Settings**:
   - Set **Info.plist File** to `AxisShareExtension/Info.plist`
   - Set **Code Signing Entitlements** to `AxisShareExtension/AxisShareExtension.entitlements`
   - Deployment Target = whatever the Axis target uses (e.g., iOS 17.0).
6. Select the **Axis** target → **Info** → **URL Types**. Confirm `axis` is registered (it already is — used by the widget). If you ever lose it, re-add: URL Schemes = `axis`.
7. Build & run the **Axis** scheme on a device or simulator. Then try sharing a URL from Safari — **Add to Axis** should be in the Share Sheet (you may need to tap *More* and toggle it on the first time).

## How it works

`ShareViewController` is a `SLComposeServiceViewController` subclass. On *Post*, it composes the body of the compose sheet (plus any shared URL) into a single string and opens:

```
axis://reminder?title=<encoded combined text>
```

The main app's `AppReducer` already handles that URL (see commit `d39a914`): it parses the title with `QuickAddParser` and creates the reminder. So sharing **"Read this tomorrow 5pm p1 https://example.com"** creates a High-priority reminder due tomorrow at 5pm with the URL in the title.

## Testing without a device

In the iOS Simulator, open **Safari** → tap the Share button → scroll to find **Add to Axis**. If it's missing, tap *Edit Actions…* and toggle it on. The first activation on a fresh install may need a relaunch of the Share Sheet.
