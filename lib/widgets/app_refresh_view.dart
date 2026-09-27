import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AppRefreshState { idle, drag, armed, loading, success, error }

bool appPrimaryRefreshNotification(ScrollNotification notification) =>
    notification.depth == 0 &&
    notification.metrics.axis == Axis.vertical &&
    notification.metrics.pixels <= notification.metrics.minScrollExtent + .5;

class AppRefreshIndicator extends StatefulWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.enabled = true,
    this.errorMessage = 'No se pudieron actualizar los datos',
    this.errorMessageBuilder,
    this.notificationPredicate,
    this.showWhileDragging = true,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final bool enabled;
  final String errorMessage;
  final String Function(Object error)? errorMessageBuilder;
  final ScrollNotificationPredicate? notificationPredicate;
  final bool showWhileDragging;

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator> {
  static const _transitionDuration = Duration(milliseconds: 200);
  static const _successDuration = Duration(milliseconds: 700);
  static const _errorDuration = Duration(milliseconds: 1100);
  static const _dragExtent = 90.0;

  AppRefreshState _state = AppRefreshState.idle;
  double _dragDistance = 0;
  bool _refreshing = false;

  ScrollNotificationPredicate get _notificationPredicate =>
      widget.notificationPredicate ?? appPrimaryRefreshNotification;

  @override
  void didUpdateWidget(covariant AppRefreshIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) _reset();
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _state = AppRefreshState.idle;
      _dragDistance = 0;
    });
  }

  void _setVisualState(AppRefreshState state, {double? dragDistance}) {
    if (!mounted) return;
    final distance = dragDistance ?? _dragDistance;
    if (_state == state && _dragDistance == distance) return;
    setState(() {
      _state = state;
      _dragDistance = distance;
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.enabled ||
        !widget.showWhileDragging ||
        _refreshing ||
        !_notificationPredicate(notification)) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _setVisualState(AppRefreshState.idle, dragDistance: 0);
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0) {
      final distance = math.max(
        _dragDistance - notification.overscroll,
        -notification.metrics.pixels,
      );
      if (_state != AppRefreshState.armed) {
        _setVisualState(AppRefreshState.drag, dragDistance: distance);
      }
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.metrics.pixels < notification.metrics.minScrollExtent) {
      final distance =
          notification.metrics.minScrollExtent - notification.metrics.pixels;
      if (_state != AppRefreshState.armed) {
        _setVisualState(AppRefreshState.drag, dragDistance: distance);
      }
    }
    return false;
  }

  void _handleIndicatorStatus(RefreshIndicatorStatus? status) {
    if (!widget.enabled) {
      _reset();
      return;
    }
    if (_state == AppRefreshState.success || _state == AppRefreshState.error) {
      return;
    }
    switch (status) {
      case RefreshIndicatorStatus.drag:
        if (widget.showWhileDragging && _state == AppRefreshState.idle) {
          _setVisualState(AppRefreshState.drag);
        }
        return;
      case RefreshIndicatorStatus.armed:
      case RefreshIndicatorStatus.snap:
        if (widget.showWhileDragging) {
          _setVisualState(AppRefreshState.armed, dragDistance: _dragExtent);
        }
        return;
      case RefreshIndicatorStatus.refresh:
        _setVisualState(AppRefreshState.loading, dragDistance: 0);
        return;
      case RefreshIndicatorStatus.canceled:
        _reset();
        return;
      case RefreshIndicatorStatus.done:
      case null:
        if (!_refreshing) _reset();
        return;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    _setVisualState(AppRefreshState.loading, dragDistance: 0);
    try {
      await widget.onRefresh();
      _setVisualState(AppRefreshState.success);
      await Future<void>.delayed(_successDuration);
    } catch (error, stackTrace) {
      debugPrint('Refresh failed: $error\n$stackTrace');
      _setVisualState(AppRefreshState.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.errorMessageBuilder?.call(error) ?? widget.errorMessage,
            ),
          ),
        );
      }
      await Future<void>.delayed(_errorDuration);
    } finally {
      _refreshing = false;
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final transitionDuration =
        reduceMotion ? Duration.zero : _transitionDuration;
    final progress = (_dragDistance / _dragExtent).clamp(0.0, 1.0);
    final visible = _state != AppRefreshState.idle;
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: RefreshIndicator.noSpinner(
        notificationPredicate: _notificationPredicate,
        onStatusChange: _handleIndicatorStatus,
        onRefresh: _refresh,
        child: Stack(
          children: [
            widget.child,
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: transitionDuration,
                  opacity: visible
                      ? _state == AppRefreshState.drag
                          ? math.max(.25, progress)
                          : 1
                      : 0,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _state == AppRefreshState.drag ? -8 + progress * 8 : 0,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: transitionDuration,
                        reverseDuration: transitionDuration,
                        child: _RefreshBubble(
                          key: ValueKey(_state),
                          state: _state,
                          reduceMotion: reduceMotion,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshBubble extends StatelessWidget {
  const _RefreshBubble({
    super.key,
    required this.state,
    required this.reduceMotion,
  });

  final AppRefreshState state;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      AppRefreshState.drag => (
          const Icon(Icons.arrow_downward_rounded, size: 18),
          'Desliza para actualizar',
          const Color(0xFF202020),
        ),
      AppRefreshState.armed => (
          const Icon(Icons.arrow_upward_rounded, size: 18),
          'Suelta para actualizar',
          const Color(0xFF202020),
        ),
      AppRefreshState.loading => (
          const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          'Actualizando…',
          const Color(0xFF202020),
        ),
      AppRefreshState.success => (
          const Icon(Icons.check_rounded, size: 19, color: Color(0xFF2E7D32)),
          'Actualizado',
          const Color(0xFF245D32),
        ),
      AppRefreshState.error => (
          const Icon(Icons.warning_amber_rounded,
              size: 19, color: Color(0xFFB3261E)),
          'No se pudo actualizar',
          const Color(0xFF8C2923),
        ),
      AppRefreshState.idle => (
          const SizedBox(width: 18, height: 18),
          '',
          const Color(0xFF202020),
        ),
    };
    return Semantics(
      liveRegion: true,
      label: label,
      child: Material(
        color: const Color(0xFFFAFAFA),
        elevation: 2,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE3E3E3)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: KeyedSubtree(key: ValueKey(state), child: icon),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ]),
        ),
      ),
    );
  }
}
