import UIKit
import XCTest
import StatusBarColorTraps

@MainActor
final class StatusBarColorTrapsTests: XCTestCase {
    private var window: UIWindow!
    private var view: UIView!

    override func setUp() async throws {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view = controller.view
    }

    override func tearDown() async throws {
        window.isHidden = true
        window = nil
        view = nil
    }

    /// What the in-app "Dark" appearance option does.
    private func forceDarkAppearance() {
        window.overrideUserInterfaceStyle = .dark
        // The trait change is not propagated to subviews synchronously. Update the
        // traits of the view that carries the override (the window), or lay it out.
        window.updateTraitsIfNeeded()
        XCTAssertEqual(view.traitCollection.userInterfaceStyle, .dark)
    }

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    // MARK: - Test setup gotcha

    /// overrideUserInterfaceStyle on the window does not reach subviews until the
    /// window's traits are updated (updateTraitsIfNeeded or a layout pass).
    func test_windowOverride_reachesSubviewsOnlyAfterTraitUpdate() {
        window.overrideUserInterfaceStyle = .dark
        XCTAssertEqual(window.traitCollection.userInterfaceStyle, .dark)
        XCTAssertEqual(view.traitCollection.userInterfaceStyle, .light)
        view.updateTraitsIfNeeded() // not enough: the pending change lives on the window
        XCTAssertEqual(view.traitCollection.userInterfaceStyle, .light)
        window.updateTraitsIfNeeded()
        XCTAssertEqual(view.traitCollection.userInterfaceStyle, .dark)
    }

    // MARK: - Trap 2: CGColorGetComponents on grey colours

    /// blackColor has two components (white, alpha) - not three.
    func test_greyColors_haveOnlyTwoComponents() {
        XCTAssertEqual(UIColor.black.cgColor.numberOfComponents, 2)
        XCTAssertEqual(UIColor.white.cgColor.numberOfComponents, 2)
        XCTAssertEqual(UIColor.systemBackground.resolvedColor(with: dark).cgColor.numberOfComponents, 2)
    }

    /// Naive: black is measured as 0.587 (alpha landed in the "green" slot) -> "light".
    func test_naive_blackMeasuresAsLight() {
        XCTAssertEqual(NaiveStatusBarStyler.brightness(of: .black, in: view), 0.587, accuracy: 0.001)
        XCTAssertEqual(NaiveStatusBarStyler.style(forBackground: .black, in: view), .default)
    }

    /// Naive: dark systemBackground (already resolved) also measures 0.587.
    func test_naive_resolvedDarkSystemBackgroundMeasuresAsLight() {
        let black = UIColor.systemBackground.resolvedColor(with: dark)
        XCTAssertEqual(NaiveStatusBarStyler.brightness(of: black, in: view), 0.587, accuracy: 0.001)
    }

    /// Naive: white is also mis-measured (0.299 + 0.587 = 0.886), but lands on the
    /// right side of 0.5 - which is why nobody noticed.
    func test_naive_whiteLooksCorrectByAccident() {
        XCTAssertEqual(NaiveStatusBarStyler.brightness(of: .white, in: view), 0.886, accuracy: 0.001)
    }

    /// Fixed: getRed:green:blue:alpha: converts grey to RGB, so black is 0 and white is 1.
    func test_fixed_greyColorsMeasureCorrectly() {
        XCTAssertEqual(FixedStatusBarStyler.brightness(of: .black, in: view), 0, accuracy: 0.001)
        XCTAssertEqual(FixedStatusBarStyler.brightness(of: .white, in: view), 1, accuracy: 0.001)
        XCTAssertEqual(FixedStatusBarStyler.style(forBackground: .black, in: view), .lightContent)
    }

    /// Fixed: a pattern colour has no RGB equivalent -> NaN -> let the system decide.
    func test_fixed_patternColorIsNotMeasurable() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
        let pattern = UIColor(patternImage: image)
        XCTAssertTrue(FixedStatusBarStyler.brightness(of: pattern, in: view).isNaN)
        XCTAssertEqual(FixedStatusBarStyler.style(forBackground: pattern, in: view), .default)
    }

    // MARK: - Trap 2: dynamic colours resolve against the CURRENT trait collection

    /// Naive: under a dark override, systemBackground (black on screen) is resolved
    /// as WHITE, because .CGColor used the current (light) trait collection
    /// (and white is then mis-measured as 0.886, see trap 2 above).
    func test_naive_dynamicColorResolvedAgainstCurrentTraitsNotTheView() {
        forceDarkAppearance()
        light.performAsCurrent {
            XCTAssertEqual(NaiveStatusBarStyler.brightness(of: .systemBackground, in: view), 0.886, accuracy: 0.001)
            XCTAssertEqual(NaiveStatusBarStyler.style(forBackground: .systemBackground, in: view), .default)
        }
    }

    /// Fixed: resolving against view.traitCollection gives the colour that is on screen.
    func test_fixed_dynamicColorResolvedAgainstTheView() {
        forceDarkAppearance()
        light.performAsCurrent {
            XCTAssertEqual(FixedStatusBarStyler.brightness(of: .systemBackground, in: view), 0, accuracy: 0.001)
            XCTAssertEqual(FixedStatusBarStyler.style(forBackground: .systemBackground, in: view), .lightContent)
        }
    }

    // MARK: - Trap 1: UIStatusBarStyleDefault is not "dark text"

    /// Naive: a white strip under the in-app Dark override gets WHITE text (invisible).
    func test_naive_defaultStyleGivesWhiteTextOnWhiteStripInDarkMode() {
        forceDarkAppearance()
        let style = NaiveStatusBarStyler.style(forBackground: .white, in: view)
        XCTAssertEqual(style, .default)
        XCTAssertFalse(StatusBarText.isDark(for: style, traitCollection: view.traitCollection))
    }

    /// Naive: the same code looks fine in light mode - which is why review missed it.
    func test_naive_defaultStyleLooksFineInLightMode() {
        window.overrideUserInterfaceStyle = .light
        window.updateTraitsIfNeeded()
        let style = NaiveStatusBarStyler.style(forBackground: .white, in: view)
        XCTAssertTrue(StatusBarText.isDark(for: style, traitCollection: view.traitCollection))
    }

    /// Fixed: DarkContent is dark text regardless of the interface style.
    func test_fixed_darkContentGivesDarkTextInDarkMode() {
        forceDarkAppearance()
        let style = FixedStatusBarStyler.style(forBackground: .white, in: view)
        XCTAssertEqual(style, .darkContent)
        XCTAssertTrue(StatusBarText.isDark(for: style, traitCollection: view.traitCollection))
    }

    // MARK: - Trap 3: "no background" is clearColor, not nil

    /// Naive: a clear background wins over the fallback, so the strip is transparent.
    func test_naive_clearBackgroundSkipsFallback() {
        let top = UIView()
        top.backgroundColor = .clear
        XCTAssertEqual(NaiveStatusBarStyler.stripColor(forTopView: top, fallback: .systemRed), .clear)
    }

    /// Fixed: alpha == 0 counts as "no colour" and the fallback is used.
    func test_fixed_clearBackgroundFallsThroughToFallback() {
        let top = UIView()
        top.backgroundColor = .clear
        XCTAssertEqual(FixedStatusBarStyler.stripColor(forTopView: top, fallback: .systemRed), .systemRed)
    }

    /// Fixed: nil and opaque backgrounds behave as before.
    func test_fixed_nilAndOpaqueBackgroundsUnchanged() {
        let top = UIView()
        XCTAssertEqual(FixedStatusBarStyler.stripColor(forTopView: top, fallback: .systemRed), .systemRed)
        top.backgroundColor = .systemBlue
        XCTAssertEqual(FixedStatusBarStyler.stripColor(forTopView: top, fallback: .systemRed), .systemBlue)
    }
}
