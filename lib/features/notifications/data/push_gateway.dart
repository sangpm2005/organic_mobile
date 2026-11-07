import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';

class PushEvent {
  final Json data;
  final bool opened;
  const PushEvent(this.data, {this.opened = false});
}

abstract class PushGateway {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<String?> token();
  Future<void> deleteToken();
  Stream<String> get tokens;
  Stream<PushEvent> get events;
  Future<PushEvent?> initialEvent();
}

/// Native configuration stays outside Dart; builds without it keep inbox working.
class FirebasePushGateway implements PushGateway {
  FirebaseMessaging get messaging => FirebaseMessaging.instance;
  @override
  Future<void> initialize() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw const ApiException(
        'Thông báo đẩy hiện hỗ trợ ứng dụng Android và iOS.',
      );
    }
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (_) {
      throw const ApiException(
        'Ứng dụng chưa được cấu hình thông báo trên thiết bị này. Bạn vẫn xem được thông báo trong ứng dụng.',
      );
    }
  }

  @override
  Future<bool> requestPermission() async {
    final permission = await messaging.requestPermission();
    return [
      AuthorizationStatus.authorized,
      AuthorizationStatus.provisional,
    ].contains(permission.authorizationStatus);
  }

  @override
  Future<String?> token() async {
    await messaging.setAutoInitEnabled(true);
    // Backend currently targets FCM registration tokens. Keep that contract
    // until its Firebase Admin SDK is migrated to installation-ID delivery.
    // ignore: deprecated_member_use
    return messaging.getToken();
  }

  @override
  Future<void> deleteToken() async {
    await messaging.setAutoInitEnabled(false);
    // ignore: deprecated_member_use
    await messaging.deleteToken();
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokens => messaging.onTokenRefresh;
  @override
  Stream<PushEvent> get events => Stream.multi((controller) {
    final foreground = FirebaseMessaging.onMessage.listen(
      (m) => controller.add(PushEvent(m.data)),
    );
    final opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => controller.add(PushEvent(m.data, opened: true)),
    );
    controller.onCancel = () async {
      await foreground.cancel();
      await opened.cancel();
    };
  });
  @override
  Future<PushEvent?> initialEvent() async {
    final message = await messaging.getInitialMessage();
    return message == null ? null : PushEvent(message.data, opened: true);
  }
}
