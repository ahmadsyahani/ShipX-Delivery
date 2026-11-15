import 'package:flutter/material.dart';

/// Keeps map controls readable when the phone rotates or text is enlarged.
class NavigationPanels extends StatelessWidget {
  const NavigationPanels({
    super.key,
    required this.header,
    required this.footer,
  });

  final Widget header, footer;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        Widget panel(Widget child) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * .46),
          child: SingleChildScrollView(child: child),
        );
        return Column(children: [panel(header), const Spacer(), panel(footer)]);
      },
    ),
  );
}
