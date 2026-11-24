import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'glossa_motion.dart';

/// Horizontal slide and fade transition page (for onboarding and sequential screens).
CustomTransitionPage<T> slideFadeTransitionPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  if (GlossaMotion.shouldReduceMotion(context)) {
    return NoTransitionPage<T>(child: child, key: state.pageKey);
  }

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: GlossaMotion.pageTransition,
    reverseTransitionDuration: GlossaMotion.pageTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: GlossaMotion.enter,
        reverseCurve: GlossaMotion.exit,
      );

      final offsetTween = Tween<Offset>(
        begin: const Offset(0.25, 0.0),
        end: Offset.zero,
      );

      return SlideTransition(
        position: offsetTween.animate(curvedAnimation),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
  );
}

/// Smooth crossfade transition page (for tabs, loading transitions).
CustomTransitionPage<T> fadeTransitionPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  if (GlossaMotion.shouldReduceMotion(context)) {
    return NoTransitionPage<T>(child: child, key: state.pageKey);
  }

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: child,
      );
    },
  );
}

/// Themed battle entrance transition page (subtle zoom + fade for battle).
CustomTransitionPage<T> battleEntranceTransitionPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  if (GlossaMotion.shouldReduceMotion(context)) {
    return NoTransitionPage<T>(child: child, key: state.pageKey);
  }

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: GlossaMotion.enter,
        reverseCurve: GlossaMotion.exit,
      );

      final scaleTween = Tween<double>(begin: 0.94, end: 1.0);

      return ScaleTransition(
        scale: scaleTween.animate(curvedAnimation),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
  );
}

/// Celebratory transition page for Level Up (playful scale up + fade).
CustomTransitionPage<T> celebrationTransitionPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  if (GlossaMotion.shouldReduceMotion(context)) {
    return NoTransitionPage<T>(child: child, key: state.pageKey);
  }

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );

      final scaleTween = Tween<double>(begin: 0.90, end: 1.0);

      return ScaleTransition(
        scale: scaleTween.animate(curvedAnimation),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}
