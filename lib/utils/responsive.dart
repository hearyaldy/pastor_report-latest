import 'package:flutter/material.dart';

class ResponsiveLayout {
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1024;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1400;
  }

  static EdgeInsets responsivePadding(BuildContext context) {
    if (isLargeScreen(context)) {
      return const EdgeInsets.all(32.0);
    } else if (isDesktop(context)) {
      return const EdgeInsets.all(24.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(20.0);
    } else {
      return const EdgeInsets.all(16.0);
    }
  }

  static EdgeInsets responsiveHorizontalPadding(BuildContext context) {
    if (isLargeScreen(context)) {
      return const EdgeInsets.symmetric(horizontal: 32.0);
    } else if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 24.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 20.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16.0);
    }
  }

  static double getMaxContentWidth(BuildContext context) {
    if (isLargeScreen(context)) {
      return 1200.0;
    } else if (isDesktop(context)) {
      return 1000.0;
    } else {
      return double.infinity;
    }
  }
}

class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileCrossAxisCount;
  final int tabletCrossAxisCount;
  final int desktopCrossAxisCount;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.mobileCrossAxisCount = 1,
    this.tabletCrossAxisCount = 2,
    this.desktopCrossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    int crossAxisCount;

    if (ResponsiveLayout.isDesktop(context)) {
      crossAxisCount = desktopCrossAxisCount;
    } else if (ResponsiveLayout.isTablet(context)) {
      crossAxisCount = tabletCrossAxisCount;
    } else {
      crossAxisCount = mobileCrossAxisCount;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: ResponsiveLayout.isDesktop(context) ? 1.2 : 1.5,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

class AdaptiveNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onDestinationSelected;
  final List<NavigationDestination> destinations;

  const AdaptiveNavigation({
    super.key,
    required this.currentIndex,
    this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isDesktop(context)) {
      return NavigationRail(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        labelType: NavigationRailLabelType.selected,
        destinations: destinations
            .map((destination) => NavigationRailDestination(
                  icon: destination.icon,
                  selectedIcon: destination.selectedIcon ?? destination.icon,
                  label: Text(destination.label),
                ))
            .toList(),
      );
    } else {
      return NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      );
    }
  }
}

class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isDesktop(context)) {
      return Card(
        margin: margin ?? const EdgeInsets.all(8.0),
        color: color,
        elevation: 4,
        child: child,
      );
    } else {
      return Card(
        margin:
            margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: color,
        elevation: 2,
        child: child,
      );
    }
  }
}

class AdaptiveDialogOrPage {
  static Future<void> show({
    required BuildContext context,
    required WidgetBuilder builder,
  }) async {
    if (ResponsiveLayout.isDesktop(context)) {
      // Navigate to full page on desktop
      await Navigator.of(context).push(
        MaterialPageRoute(builder: builder),
      );
    } else {
      // Show dialog on mobile
      await showDialog(
        context: context,
        builder: builder,
      );
    }
  }
}
