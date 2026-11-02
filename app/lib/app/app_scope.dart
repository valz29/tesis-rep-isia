import 'package:flutter/widgets.dart';

import 'session_controller.dart';

/// Constructor injection exposed to page boundaries. This scope stores no data.
class AppScope extends InheritedWidget {
  final SessionController session;
  const AppScope({super.key, required this.session, required super.child});
  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'An AppScope is required above the app navigator');
    return scope!.session;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => session != oldWidget.session;
}
