#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Picks the status-bar text colour from the colour painted behind the status bar.
///
/// The naive version contains three bugs that were found in a real app:
/// 1. it returns `UIStatusBarStyleDefault` when it wants dark text;
/// 2. it measures brightness with `CGColorGetComponents` and assumes three RGB
///    components, and it resolves dynamic colours against the *current* trait
///    collection instead of the view's;
/// 3. it treats only `nil` as "no background", although a transparent
///    (`clearColor`) background means the same thing.
NS_SWIFT_NAME(NaiveStatusBarStyler)
@interface SBCNaiveStatusBarStyler : NSObject

/// Perceived brightness (0...1) using the `(r*299 + g*587 + b*114) / 1000` formula.
+ (CGFloat)brightnessOfColor:(UIColor *)color inView:(UIView *)view
    NS_SWIFT_NAME(brightness(of:in:));

/// Status-bar style for text drawn on top of `color`.
+ (UIStatusBarStyle)styleForBackgroundColor:(UIColor *)color inView:(UIView *)view
    NS_SWIFT_NAME(style(forBackground:in:));

/// Colour to paint behind the status bar: the top view's background, or `fallback`.
+ (UIColor *)stripColorForTopView:(UIView *)view fallback:(UIColor *)fallback
    NS_SWIFT_NAME(stripColor(forTopView:fallback:));

@end

NS_SWIFT_NAME(FixedStatusBarStyler)
@interface SBCFixedStatusBarStyler : NSObject

/// Perceived brightness (0...1) of `color` resolved against `view.traitCollection`.
/// Returns `NAN` when the colour has no RGB equivalent (e.g. a pattern colour).
+ (CGFloat)brightnessOfColor:(UIColor *)color inView:(UIView *)view
    NS_SWIFT_NAME(brightness(of:in:));

/// `UIStatusBarStyleDarkContent` on light colours, `UIStatusBarStyleLightContent`
/// on dark ones, `UIStatusBarStyleDefault` only when the colour cannot be measured.
+ (UIStatusBarStyle)styleForBackgroundColor:(UIColor *)color inView:(UIView *)view
    NS_SWIFT_NAME(style(forBackground:in:));

/// Like the naive version, but a fully transparent background also counts as "none".
+ (UIColor *)stripColorForTopView:(UIView *)view fallback:(UIColor *)fallback
    NS_SWIFT_NAME(stripColor(forTopView:fallback:));

@end

/// Models what the system draws for a given style (see the `UIStatusBarStyle` docs):
/// `Default` follows the interface style, `DarkContent` / `LightContent` are fixed.
NS_SWIFT_NAME(StatusBarText)
@interface SBCStatusBarText : NSObject

/// YES when the status-bar text is dark for `style` under `traitCollection`.
+ (BOOL)isDarkForStyle:(UIStatusBarStyle)style traitCollection:(UITraitCollection *)traitCollection
    NS_SWIFT_NAME(isDark(for:traitCollection:));

@end

NS_ASSUME_NONNULL_END
