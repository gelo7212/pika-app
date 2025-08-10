import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform-aware layout utilities for responsive design
class PlatformLayoutUtils {
  /// Get the appropriate layout type based on screen size and platform
  static LayoutType getLayoutType(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (kIsWeb) {
      if (screenWidth >= 1200) return LayoutType.webDesktop;
      if (screenWidth >= 768) return LayoutType.webTablet;
      return LayoutType.webMobile;
    } else {
      if (screenWidth >= 768) return LayoutType.mobileTablet;
      return LayoutType.mobilePhone;
    }
  }
  
  /// Check if should show sidebar navigation
  static bool shouldShowSidebar(BuildContext context) {
    final layoutType = getLayoutType(context);
    return layoutType == LayoutType.webDesktop || 
           layoutType == LayoutType.webTablet ||
           layoutType == LayoutType.mobileTablet;
  }
  
  /// Check if should show bottom navigation
  static bool shouldShowBottomNav(BuildContext context) {
    final layoutType = getLayoutType(context);
    return layoutType == LayoutType.webMobile || 
           layoutType == LayoutType.mobilePhone;
  }
  
  /// Check if should show header/app bar
  static bool shouldShowHeader(BuildContext context) {
    // Always show header on web, conditional on mobile
    return kIsWeb || !shouldShowSidebar(context);
  }
  
  /// Get appropriate padding for content area
  static EdgeInsets getContentPadding(BuildContext context) {
    final layoutType = getLayoutType(context);
    
    switch (layoutType) {
      case LayoutType.webDesktop:
        return const EdgeInsets.all(24.0);
      case LayoutType.webTablet:
        return const EdgeInsets.all(16.0);
      case LayoutType.webMobile:
        return const EdgeInsets.all(12.0);
      case LayoutType.mobileTablet:
        return const EdgeInsets.all(16.0);
      case LayoutType.mobilePhone:
        return const EdgeInsets.all(12.0);
    }
  }
  
  /// Get appropriate sidebar width
  static double getSidebarWidth(BuildContext context) {
    final layoutType = getLayoutType(context);
    
    switch (layoutType) {
      case LayoutType.webDesktop:
        return 280.0;
      case LayoutType.webTablet:
      case LayoutType.mobileTablet:
        return 240.0;
      default:
        return 200.0;
    }
  }
  
  /// Get appropriate app bar height
  static double getAppBarHeight(BuildContext context) {
    return kIsWeb ? 64.0 : 56.0;
  }
  
  /// Check if should use drawer instead of permanent sidebar
  static bool shouldUseDrawer(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < 768; // Below tablet size
  }
  
  /// Get appropriate cross-axis count for grid layouts
  static int getGridCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth >= 1200) return 4;
    if (screenWidth >= 900) return 3;
    if (screenWidth >= 600) return 2;
    return 1;
  }
  
  /// Get appropriate list tile leading width for navigation items
  static double getNavItemLeadingWidth(BuildContext context) {
    final layoutType = getLayoutType(context);
    return layoutType == LayoutType.webDesktop ? 56.0 : 40.0;
  }
  
  /// Check if should show tooltips on navigation items
  static bool shouldShowNavTooltips(BuildContext context) {
    return kIsWeb; // Tooltips are more useful on web with mouse hover
  }
  
  /// Get appropriate animation duration for transitions
  static Duration getTransitionDuration(BuildContext context) {
    // Faster animations on web, slightly slower on mobile
    return kIsWeb 
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 300);
  }
  
  /// Get breakpoints for responsive design
  static ResponsiveBreakpoints get breakpoints => const ResponsiveBreakpoints();
}

/// Layout types for different screen sizes and platforms
enum LayoutType {
  webDesktop,
  webTablet,
  webMobile,
  mobileTablet,
  mobilePhone,
}

/// Responsive breakpoints constants
class ResponsiveBreakpoints {
  const ResponsiveBreakpoints();
  
  static const double mobile = 480;
  static const double tablet = 768;
  static const double laptop = 1024;
  static const double desktop = 1200;
  static const double ultraWide = 1920;
}

/// Responsive widget that builds different layouts based on screen size
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? laptop;
  final Widget? desktop;
  
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.laptop,
    this.desktop,
  });
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth >= ResponsiveBreakpoints.desktop) {
      return desktop ?? laptop ?? tablet ?? mobile;
    } else if (screenWidth >= ResponsiveBreakpoints.laptop) {
      return laptop ?? tablet ?? mobile;
    } else if (screenWidth >= ResponsiveBreakpoints.tablet) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }
}

/// Extension for responsive design helpers
extension ResponsiveContext on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < ResponsiveBreakpoints.tablet;
  bool get isTablet => MediaQuery.of(this).size.width >= ResponsiveBreakpoints.tablet && 
                      MediaQuery.of(this).size.width < ResponsiveBreakpoints.laptop;
  bool get isLaptop => MediaQuery.of(this).size.width >= ResponsiveBreakpoints.laptop && 
                       MediaQuery.of(this).size.width < ResponsiveBreakpoints.desktop;
  bool get isDesktop => MediaQuery.of(this).size.width >= ResponsiveBreakpoints.desktop;
  
  LayoutType get layoutType => PlatformLayoutUtils.getLayoutType(this);
  bool get shouldShowSidebar => PlatformLayoutUtils.shouldShowSidebar(this);
  bool get shouldShowBottomNav => PlatformLayoutUtils.shouldShowBottomNav(this);
  bool get shouldUseDrawer => PlatformLayoutUtils.shouldUseDrawer(this);
}
