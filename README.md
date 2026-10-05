# Status-bar text colour from a background colour: three traps

A minimal Objective-C reproduction (with Swift XCTest tests) of three bugs that
show up together when an app picks light or dark status-bar text by measuring the
colour behind the status bar, and also lets the user force Light/Dark appearance
in-app with `window.overrideUserInterfaceStyle`.

| | Naive | Fixed |
|---|---|---|
| 1. Style for dark text | `UIStatusBarStyleDefault` | `UIStatusBarStyleDarkContent` |
| 2. Brightness | `CGColorGetComponents(color.CGColor)` read as r, g, b | `resolvedColorWithTraitCollection:view.traitCollection` + `getRed:green:blue:alpha:` |
| 3. "No background" | `view.backgroundColor ?: fallback` | `nil` **or alpha == 0** uses the fallback |

## How to run

1. Open `Demo/Demo.xcodeproj` in Xcode (16 or newer). It uses this package as a local
   Swift package, so there is nothing to install.
2. Pick an iPhone simulator (iOS 17+) and press **⌘R**.
3. Watch the clock and battery icons at the top while you switch
   **Naive / Fixed**, the in-app appearance and the page background:
   - **Black page** (trap 2): Naive measures black as 0.587 and draws dark text on black.
   - **White page + Dark appearance** (trap 1): Naive returns `.default`, which follows
     Dark mode, so the text is white on white.
   - **Clear page** (trap 3): Naive keeps the transparent background instead of the blue
     fallback, so the strip vanishes and the text can end up white on white.
   - **Fixed**: readable in every combination. The on-screen readout shows the measured
     brightness, the chosen style and a readable / UNREADABLE verdict.
4. Press **⌘U** to run the package's XCTest suite (the `test_naive_*` tests pin the
   bugs, the `test_fixed_*` tests pin the fixes).

`swift test` on macOS does not work: the library and tests need UIKit, so they run only
on an iOS simulator (via the Demo scheme, or `xcodebuild test` as shown below).
`Demo/Demo.xcodeproj` is generated from `Demo/project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`cd Demo && xcodegen generate`).

## Trap 1 - `UIStatusBarStyleDefault` is not "dark text"

Since iOS 13 `UIStatusBarStyleDefault` means *automatic*: dark text in light
mode, light text in dark mode. With `overrideUserInterfaceStyle = .dark`, a light
strip gets white text. Use `UIStatusBarStyleDarkContent` when you mean dark text.

## Trap 2 - `CGColorGetComponents` on grey and dynamic colours

`blackColor`, `whiteColor` and a resolved `systemBackgroundColor` live in a grey
colour space with **two** components: `(white, alpha)`. Treating them as
`(r, g, b)` puts alpha in the green slot and reads `c[2]` past the end of the
array. Black then measures about 0.587 - "light" - and gets black text.

Also, `.CGColor` of a dynamic colour is resolved against
`UITraitCollection.currentTraitCollection`, not against the view showing it.

```objc
UIColor *resolved = [color resolvedColorWithTraitCollection:view.traitCollection];
CGFloat r, g, b, a;
if (![resolved getRed:&r green:&g blue:&b alpha:&a]) {
    return NAN; // pattern colours etc. have no RGB equivalent
}
return (r * 299 + g * 587 + b * 114) / 1000;
```

(The naive implementation in this repo copies the components into a zero-padded
buffer so the out-of-bounds read becomes deterministic; it computes exactly what
the original code computed when that slot held 0.)

## Trap 3 - "no background" is often `clearColor`, not `nil`

If a view without a configured background carries `[UIColor clearColor]`,
`view.backgroundColor ?: fallback` never uses the fallback and the strip is
painted transparent. Treat alpha == 0 as "no colour".

## Layout

- `Sources/StatusBarColorTraps/` - `SBCNaiveStatusBarStyler`, `SBCFixedStatusBarStyler`
  and `SBCStatusBarText` (models what the system draws for each style).
- `Tests/StatusBarColorTrapsTests/` - `test_naive_*` tests pin the broken
  behaviour, `test_fixed_*` tests pin the fix.

## Running the tests

UIKit is needed, so the tests run on an iOS simulator:

```bash
xcodebuild test -scheme StatusBarColorTraps \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

Test tip: setting `window.overrideUserInterfaceStyle` updates the window's
`traitCollection` immediately, but not its subviews'. Calling
`view.updateTraitsIfNeeded()` on the subview is not enough - call
`window.updateTraitsIfNeeded()` (iOS 17+) or lay the window out before asserting.

## License

MIT

Write-up: https://alexeyhatkevich.blogspot.com
