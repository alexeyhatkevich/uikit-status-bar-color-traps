import StatusBarColorTraps
import UIKit

/// Paints a strip behind the status bar and picks the status-bar text colour from it,
/// using either the naive or the fixed implementation from the package.
final class DemoViewController: UIViewController {
    private enum Implementation: Int { case naive, fixed }
    private enum Appearance: Int { case system, light, dark }
    private enum PageBackground: Int { case white, black, clear }

    /// Colour the app wants behind the status bar when the page has no background.
    private let fallback = UIColor(red: 0.12, green: 0.23, blue: 0.58, alpha: 1)

    private let pageView = UIView()   // "the screen": its background is what gets measured
    private let stripView = UIView()  // painted behind the status bar
    private let implementationControl = UISegmentedControl(items: ["Naive", "Fixed"])
    private let appearanceControl = UISegmentedControl(items: ["System", "Light", "Dark"])
    private let backgroundControl = UISegmentedControl(items: ["White", "Black", "Clear"])
    private let readoutLabel = UILabel()
    private let verdictLabel = UILabel()

    private var statusBarStyle: UIStatusBarStyle = .default
    override var preferredStatusBarStyle: UIStatusBarStyle { statusBarStyle }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        pageView.translatesAutoresizingMaskIntoConstraints = false
        stripView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageView)
        view.addSubview(stripView)

        implementationControl.selectedSegmentIndex = Implementation.naive.rawValue
        appearanceControl.selectedSegmentIndex = Appearance.system.rawValue
        backgroundControl.selectedSegmentIndex = PageBackground.black.rawValue
        applyLaunchArguments()
        implementationControl.accessibilityIdentifier = "implementation"
        appearanceControl.accessibilityIdentifier = "appearance"
        backgroundControl.accessibilityIdentifier = "pageBackground"
        for control in [implementationControl, appearanceControl, backgroundControl] {
            control.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        }

        let title = UILabel()
        title.text = "Status-bar text colour traps"
        title.font = .preferredFont(forTextStyle: .headline)

        let help = UILabel()
        help.numberOfLines = 0
        help.font = .preferredFont(forTextStyle: .footnote)
        help.textColor = .secondaryLabel
        help.text = """
        Watch the clock and battery icons at the very top. \
        The app measures the strip colour behind them and picks light or dark text.

        Trap 1: White page + Dark appearance. Naive returns .default, which follows \
        Dark mode: white text on white.
        Trap 2: Black page. Naive reads a grey colour's (white, alpha) as (r, g, b), \
        measures black as 0.587 and draws dark text on black.
        Trap 3: Clear page. Naive keeps the transparent background instead of the \
        blue fallback, so the strip disappears.

        Switch to Fixed: the text stays readable in every combination.
        """

        readoutLabel.numberOfLines = 0
        readoutLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        verdictLabel.font = .preferredFont(forTextStyle: .headline)
        verdictLabel.accessibilityIdentifier = "verdict"

        let stack = UIStackView(arrangedSubviews: [
            title,
            caption("Implementation"), implementationControl,
            caption("In-app appearance (window.overrideUserInterfaceStyle)"), appearanceControl,
            caption("Page background"), backgroundControl,
            verdictLabel, readoutLabel, help,
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(16, after: title)
        stack.setCustomSpacing(16, after: backgroundControl)

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(card)
        pageView.addSubview(scroll)

        NSLayoutConstraint.activate([
            pageView.topAnchor.constraint(equalTo: view.topAnchor),
            pageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stripView.topAnchor.constraint(equalTo: view.topAnchor),
            stripView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stripView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stripView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            scroll.topAnchor.constraint(equalTo: stripView.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),

            card.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            card.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            card.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.refresh()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        controlChanged()
    }

    /// Launch arguments for scripted runs, e.g. `-mode fixed -appearance dark -background white`.
    private func applyLaunchArguments() {
        let defaults = UserDefaults.standard
        if let mode = defaults.string(forKey: "mode")?.lowercased() {
            implementationControl.selectedSegmentIndex = mode == "fixed" ? Implementation.fixed.rawValue
                                                                         : Implementation.naive.rawValue
        }
        switch defaults.string(forKey: "appearance")?.lowercased() {
        case "light": appearanceControl.selectedSegmentIndex = Appearance.light.rawValue
        case "dark": appearanceControl.selectedSegmentIndex = Appearance.dark.rawValue
        case "system": appearanceControl.selectedSegmentIndex = Appearance.system.rawValue
        default: break
        }
        switch defaults.string(forKey: "background")?.lowercased() {
        case "white": backgroundControl.selectedSegmentIndex = PageBackground.white.rawValue
        case "black": backgroundControl.selectedSegmentIndex = PageBackground.black.rawValue
        case "clear": backgroundControl.selectedSegmentIndex = PageBackground.clear.rawValue
        default: break
        }
    }

    private func caption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        return label
    }

    @objc private func controlChanged() {
        let appearance = Appearance(rawValue: appearanceControl.selectedSegmentIndex) ?? .system
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        if let window = view.window, window.overrideUserInterfaceStyle != style {
            window.overrideUserInterfaceStyle = style
            window.updateTraitsIfNeeded()
        }
        refresh()
    }

    private func refresh() {
        let implementation = Implementation(rawValue: implementationControl.selectedSegmentIndex) ?? .naive
        pageView.backgroundColor = switch PageBackground(rawValue: backgroundControl.selectedSegmentIndex) ?? .white {
        case .white: .white
        case .black: .black
        case .clear: .clear
        }

        let strip: UIColor
        switch implementation {
        case .naive:
            strip = NaiveStatusBarStyler.stripColor(forTopView: pageView, fallback: fallback)
            statusBarStyle = NaiveStatusBarStyler.style(forBackground: strip, in: stripView)
        case .fixed:
            strip = FixedStatusBarStyler.stripColor(forTopView: pageView, fallback: fallback)
            statusBarStyle = FixedStatusBarStyler.style(forBackground: strip, in: stripView)
        }
        stripView.backgroundColor = strip
        setNeedsStatusBarAppearanceUpdate()

        // What is really on screen behind the status bar: the strip, or (if it is
        // transparent) the root view's systemBackground showing through.
        let resolvedStrip = strip.resolvedColor(with: traitCollection)
        let onScreen = resolvedStrip.cgColor.alpha > 0 ? resolvedStrip
                                                       : UIColor.systemBackground.resolvedColor(with: traitCollection)
        let onScreenBrightness = FixedStatusBarStyler.brightness(of: onScreen, in: view)
        let measured = implementation == .naive
            ? NaiveStatusBarStyler.brightness(of: strip, in: stripView)
            : FixedStatusBarStyler.brightness(of: strip, in: stripView)
        let textIsDark = StatusBarText.isDark(for: statusBarStyle, traitCollection: traitCollection)
        let readable = textIsDark == (onScreenBrightness > 0.5)

        readoutLabel.text = """
        strip colour:   \(describe(strip))
        measured:       \(String(format: "%.3f", measured))
        style:          \(name(of: statusBarStyle))
        text drawn:     \(textIsDark ? "dark" : "light")
        behind text:    \(describe(onScreen)) (\(onScreenBrightness > 0.5 ? "light" : "dark"))
        """
        verdictLabel.text = readable ? "Status bar readable" : "Status bar UNREADABLE"
        verdictLabel.textColor = readable ? .systemGreen : .systemRed
    }

    private func describe(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.resolvedColor(with: traitCollection).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return "(not RGB)"
        }
        if a == 0 { return "clear" }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func name(of style: UIStatusBarStyle) -> String {
        switch style {
        case .default: ".default (follows appearance)"
        case .lightContent: ".lightContent"
        case .darkContent: ".darkContent"
        @unknown default: "unknown"
        }
    }
}
