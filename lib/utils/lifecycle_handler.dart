import 'package:flutter/widgets.dart';

class LifecycleHandler extends WidgetsBindingObserver {
  final VoidCallback? onPaused;
  final VoidCallback? onResumed;
  final VoidCallback? onDetached;

  LifecycleHandler({this.onPaused, this.onResumed, this.onDetached}) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("🔍 App State Changed: $state"); // ✅ تأكد من أن هذه الرسالة تظهر في الـ console

    switch (state) {
      case AppLifecycleState.paused:
        if (onPaused != null) {
          print("⏸ App is Paused - Executing onPaused()"); // ✅ تأكيد أن `onPaused` يتم تنفيذه
          onPaused!();
        }
        break;
      case AppLifecycleState.resumed:
        if (onResumed != null) onResumed!();
        break;
      case AppLifecycleState.detached:
        if (onDetached != null) onDetached!();
        break;
      default:
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
