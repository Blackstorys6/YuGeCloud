import 'package:flutter/material.dart';
import 'fade_in_widget.dart';

/// 交错动画列表
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration animationDuration;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final bool eagerBuild;

  const StaggeredList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.animationDuration = const Duration(milliseconds: 600),
    this.controller,
    this.padding,
    this.eagerBuild = false,
  });

  @override
  Widget build(BuildContext context) {
    if (eagerBuild) {
      return ListView(
        controller: controller,
        padding: padding,
        children: [
          for (var index = 0; index < children.length; index++)
            FadeInWidget(
              delay: Duration.zero,
              duration: animationDuration,
              child: children[index],
            ),
        ],
      );
    }

    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return FadeInWidget(
          delay: staggerDelay * index,
          duration: animationDuration,
          child: children[index],
        );
      },
    );
  }
}
