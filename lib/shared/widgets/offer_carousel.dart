import 'dart:async';

import 'package:flutter/material.dart';

class OfferCarousel extends StatefulWidget {
  final List<Widget> slides;
  final List<String>? slideIds;
  final ValueChanged<int>? onOpen;
  const OfferCarousel({
    super.key,
    required this.slides,
    this.slideIds,
    this.onOpen,
  });
  @override
  State<OfferCarousel> createState() => _OfferCarouselState();
}

/// Only the non-interactive banner content handles next/open gestures.
/// Buttons and inputs stay outside this region so double-tap cannot steal them.
class OfferCarouselTapArea extends StatelessWidget {
  final Widget child;
  const OfferCarouselTapArea({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final carousel = context.findAncestorStateOfType<_OfferCarouselState>();
    if (carousel == null || carousel.widget.onOpen == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => carousel.move(1),
      onDoubleTapDown: (_) => carousel.touching = true,
      onDoubleTapCancel: () {
        carousel.touching = false;
        carousel.restart();
      },
      onDoubleTap: () {
        carousel.touching = false;
        carousel.restart();
        carousel.widget.onOpen!(carousel.index);
      },
      child: child,
    );
  }
}

class _OfferCarouselState extends State<OfferCarousel>
    with WidgetsBindingObserver {
  Timer? timer;
  int index = 0;
  bool touching = false, hovering = false, foreground = true;
  String? get activeId => widget.slideIds?.elementAtOrNull(index);

  void restart() {
    if (!mounted) return;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted ||
          touching ||
          hovering ||
          !foreground ||
          !TickerMode.valuesOf(context).enabled ||
          ModalRoute.of(context)?.isCurrent == false ||
          MediaQuery.disableAnimationsOf(context) ||
          widget.slides.length < 2) {
        return;
      }
      move(1);
    });
  }

  void move(int step) {
    if (!mounted || widget.slides.length < 2) return;
    setState(
      () =>
          index = (index + step + widget.slides.length) % widget.slides.length,
    );
    restart();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    restart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    restart();
  }

  @override
  void didUpdateWidget(covariant OfferCarousel old) {
    super.didUpdateWidget(old);
    final previousId = old.slideIds?.elementAtOrNull(index);
    if (previousId != null && widget.slideIds != null) {
      final next = widget.slideIds!.indexOf(previousId);
      index = next < 0 ? 0 : next;
    } else if (index >= widget.slides.length) {
      index = 0;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    return MouseRegion(
      onEnter: (_) => hovering = true,
      onExit: (_) {
        hovering = false;
        restart();
      },
      child: Listener(
        onPointerDown: (_) => touching = true,
        onPointerUp: (_) {
          touching = false;
          restart();
        },
        onPointerCancel: (_) {
          touching = false;
          restart();
        },
        child: GestureDetector(
          key: ValueKey(widget.slideIds?.join('|')),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            move((details.primaryVelocity ?? 0) < 0 ? 1 : -1);
          },
          child: Semantics(
            label:
                'Ưu đãi ${index + 1} trong ${widget.slides.length}. Vuốt để xem ưu đãi khác.${widget.onOpen == null ? '' : ' Chạm một lần để chuyển, chạm hai lần để xem chi tiết.'}',
            child: AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    for (final child in previous)
                      IgnorePointer(child: ExcludeSemantics(child: child)),
                    ?current,
                  ],
                ),
                child: KeyedSubtree(
                  key: ValueKey(activeId ?? index),
                  child: widget.slides[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
