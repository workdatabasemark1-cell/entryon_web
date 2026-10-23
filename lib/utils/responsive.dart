import 'package:flutter/material.dart';

/// Screen breakpoint constants
abstract class ResponsiveBreakpoints {
  static const double smallMobileMax = 380.0;
  static const double mobileMax = 700.0;
  static const double tabletMax = 1024.0;
  static const double desktopMax = 1500.0;
}

/// Core Responsive Helper
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  /// Check if current screen is small mobile (< 380px)
  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.smallMobileMax;

  /// Check if the current screen width is mobile (< 700px)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobileMax;

  /// Check if the current screen width is tablet (700px - 1024px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.mobileMax &&
        width < ResponsiveBreakpoints.tabletMax;
  }

  /// Check if the current screen is mobile or tablet (< 1024px)
  static bool isMobileOrTablet(BuildContext context) =>
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.tabletMax;

  /// Check if the current screen width is desktop (>= 1024px)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.tabletMax;

  /// Check if the current screen width is large desktop (>= 1500px)
  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktopMax;

  /// Get current screen width
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get current screen height
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Returns value based on current screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? smallMobile,
    T? tablet,
    required T desktop,
    T? largeDesktop,
  }) {
    final w = width(context);
    if (w >= ResponsiveBreakpoints.desktopMax && largeDesktop != null) {
      return largeDesktop;
    }
    if (w >= ResponsiveBreakpoints.tabletMax) {
      return desktop;
    }
    if (w >= ResponsiveBreakpoints.mobileMax) {
      return tablet ?? desktop;
    }
    if (w < ResponsiveBreakpoints.smallMobileMax && smallMobile != null) {
      return smallMobile;
    }
    return mobile;
  }

  /// Show responsive dialog that comfortably fits within viewports
  static Future<T?> showAdaptiveDialog<T>({
    required BuildContext context,
    required Widget child,
    double maxWidth = 900,
    double? maxHeight,
    EdgeInsets? insetPadding,
    bool barrierDismissible = true,
    BorderRadius? borderRadius,
  }) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isMob = screenW < ResponsiveBreakpoints.mobileMax;

    final defaultInset = isMob
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 14)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 24);

    final dialogW = screenW < maxWidth + 32 ? screenW * 0.96 : maxWidth;
    final dialogH = maxHeight != null
        ? (screenH < maxHeight + 32 ? screenH * 0.94 : maxHeight)
        : (isMob ? screenH * 0.94 : null);

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogCtx) => Dialog(
        insetPadding: insetPadding ?? defaultInset,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(isMob ? 12 : 16),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: dialogW,
          height: dialogH,
          child: child,
        ),
      ),
    );
  }

  /// Show responsive bottom sheet or adaptive modal
  static Future<T?> showAdaptiveBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    double maxWidth = 700,
    bool isScrollControlled = true,
  }) {
    final isMob = isMobile(context);

    if (!isMob) {
      return showAdaptiveDialog<T>(
        context: context,
        maxWidth: maxWidth,
        child: child,
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.tabletMax) {
      return desktop;
    } else if (width >= ResponsiveBreakpoints.mobileMax && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

/// Convenient extension on BuildContext for quick responsive checks and values
extension ResponsiveContextExtension on BuildContext {
  bool get isSmallMobile => Responsive.isSmallMobile(this);
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isMobileOrTablet => Responsive.isMobileOrTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  bool get isLargeDesktop => Responsive.isLargeDesktop(this);

  double get screenWidth => Responsive.width(this);
  double get screenHeight => Responsive.height(this);

  T responsive<T>({
    required T mobile,
    T? smallMobile,
    T? tablet,
    required T desktop,
    T? largeDesktop,
  }) =>
      Responsive.value<T>(
        this,
        mobile: mobile,
        smallMobile: smallMobile,
        tablet: tablet,
        desktop: desktop,
        largeDesktop: largeDesktop,
      );
}

/// Responsive Row or Column based on screen width
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;
  final bool forceColumn;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.spacing = 12.0,
    this.forceColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMob = context.isMobile || forceColumn;

    if (isMob) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: _buildSpacedChildren(true),
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _buildSpacedChildren(false),
    );
  }

  List<Widget> _buildSpacedChildren(bool isColumn) {
    if (spacing <= 0 || children.isEmpty) return children;
    final List<Widget> spaced = [];
    for (int i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i < children.length - 1) {
        spaced.add(isColumn ? SizedBox(height: spacing) : SizedBox(width: spacing));
      }
    }
    return spaced;
  }
}
