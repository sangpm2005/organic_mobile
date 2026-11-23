import 'dart:async';

import 'package:flutter/material.dart';

class OfferCarousel extends StatefulWidget {
  final List<Widget> slides;
  const OfferCarousel({super.key, required this.slides});
  @override
  State<OfferCarousel> createState() => _OfferCarouselState();
}

class _OfferCarouselState extends State<OfferCarousel>
    with WidgetsBindingObserver {
  Timer? timer;
  int index = 0;
  bool touching = false, hovering = false, foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    timer = Timer.periodic(const Duration(seconds: 6), (_) {
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
      setState(() => index = (index + 1) % widget.slides.length);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(covariant OfferCarousel old) {
    super.didUpdateWidget(old);
    if (index >= widget.slides.length) index = 0;
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
      onExit: (_) => hovering = false,
      child: Listener(
        onPointerDown: (_) => touching = true,
        onPointerUp: (_) => touching = false,
        onPointerCancel: (_) => touching = false,
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (widget.slides.length > 1) {
              setState(
                () => index =
                    (index +
                        ((details.primaryVelocity ?? 0) < 0 ? 1 : -1) +
                        widget.slides.length) %
                    widget.slides.length,
              );
            }
          },
          child: Semantics(
            label:
                'Ưu đãi ${index + 1} trong ${widget.slides.length}. Vuốt để xem ưu đãi khác.',
            child: AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                child: KeyedSubtree(
                  key: ValueKey(index),
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
