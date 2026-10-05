#import "StatusBarColorTraps.h"
#import <string.h>

#pragma mark - Naive

@implementation SBCNaiveStatusBarStyler

+ (CGFloat)brightnessOfColor:(UIColor *)color inView:(UIView *)view {
    // BUG (trap 2a): `.CGColor` of a dynamic colour is resolved against
    // UITraitCollection.currentTraitCollection, not against `view`.
    CGColorRef cg = color.CGColor;

    // BUG (trap 2b): the original code was
    //
    //     const CGFloat *c = CGColorGetComponents(cg);
    //     return (c[0] * 299 + c[1] * 587 + c[2] * 114) / 1000;
    //
    // Grey colours (blackColor, whiteColor, resolved systemBackgroundColor, ...)
    // live in a grey colour space with only two components: (white, alpha).
    // c[1] is then the ALPHA and c[2] reads past the end of the array.
    // To keep this reproduction deterministic we copy the components into a
    // zero-padded buffer - which is exactly what the original computed whenever
    // the out-of-bounds slot happened to hold 0.
    CGFloat c[4] = {0, 0, 0, 0};
    size_t n = MIN(CGColorGetNumberOfComponents(cg), (size_t)4);
    memcpy(c, CGColorGetComponents(cg), n * sizeof(CGFloat));
    return (c[0] * 299 + c[1] * 587 + c[2] * 114) / 1000;
}

+ (UIStatusBarStyle)styleForBackgroundColor:(UIColor *)color inView:(UIView *)view {
    // BUG (trap 1): since iOS 13 Default means "follow the interface style",
    // not "dark text".
    return [self brightnessOfColor:color inView:view] > 0.5 ? UIStatusBarStyleDefault
                                                            : UIStatusBarStyleLightContent;
}

+ (UIColor *)stripColorForTopView:(UIView *)view fallback:(UIColor *)fallback {
    // BUG (trap 3): a view "without a background" may carry clearColor, not nil.
    return view.backgroundColor ?: fallback;
}

@end

#pragma mark - Fixed

@implementation SBCFixedStatusBarStyler

+ (CGFloat)brightnessOfColor:(UIColor *)color inView:(UIView *)view {
    // Resolve dynamic colours against the view that shows them.
    UIColor *resolved = [color resolvedColorWithTraitCollection:view.traitCollection];
    CGFloat r, g, b, a;
    // -getRed:green:blue:alpha: converts grey colour spaces to RGB. It returns NO
    // only for colours without an RGB equivalent, such as pattern colours.
    if (![resolved getRed:&r green:&g blue:&b alpha:&a]) {
        return NAN;
    }
    return (r * 299 + g * 587 + b * 114) / 1000;
}

+ (UIStatusBarStyle)styleForBackgroundColor:(UIColor *)color inView:(UIView *)view {
    CGFloat brightness = [self brightnessOfColor:color inView:view];
    if (isnan(brightness)) {
        return UIStatusBarStyleDefault; // cannot measure: let the system decide
    }
    return brightness > 0.5 ? UIStatusBarStyleDarkContent : UIStatusBarStyleLightContent;
}

+ (UIColor *)stripColorForTopView:(UIView *)view fallback:(UIColor *)fallback {
    UIColor *background = view.backgroundColor;
    if (background == nil) {
        return fallback;
    }
    CGFloat alpha = CGColorGetAlpha([background resolvedColorWithTraitCollection:view.traitCollection].CGColor);
    return alpha > 0 ? background : fallback;
}

@end

#pragma mark - What the system draws

@implementation SBCStatusBarText

+ (BOOL)isDarkForStyle:(UIStatusBarStyle)style traitCollection:(UITraitCollection *)traitCollection {
    switch (style) {
        case UIStatusBarStyleDarkContent:
            return YES;
        case UIStatusBarStyleLightContent:
            return NO;
        default: // UIStatusBarStyleDefault: automatic, follows the interface style
            return traitCollection.userInterfaceStyle != UIUserInterfaceStyleDark;
    }
}

@end
