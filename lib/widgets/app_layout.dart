import 'package:flutter/material.dart';

import 'app_header.dart';
import 'side_menu.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({
    super.key,
    required this.section,
    required this.onSectionSelected,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
    required this.allowedSections,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionSelected;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;
  final List<AppSection> allowedSections;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final menu = SideMenu(
          currentSection: section,
          onSectionSelected: (selectedSection) {
            if (!isDesktop) Navigator.of(context).pop();
            onSectionSelected(selectedSection);
          },
          compact: !isDesktop,
          allowedSections: allowedSections,
        );
        return Scaffold(
          drawer: isDesktop ? null : Drawer(child: menu),
          body: Row(
            children: [
              if (isDesktop) menu,
              Expanded(
                child: Column(
                  children: [
                    Builder(
                      builder: (scaffoldContext) => AppHeader(
                        title: title,
                        subtitle: subtitle,
                        action: action,
                        onMenuPressed: isDesktop
                            ? null
                            : () => Scaffold.of(scaffoldContext).openDrawer(),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child:
                            KeyedSubtree(key: ValueKey(section), child: child),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
