import 'package:AndroidPushNotificationServer/android_push_notification_server.dart';
import 'package:test/test.dart';

void main() {
  test('initializeServer', () async {
    PushNotificationServer server = await PushNotificationServer.initializeServer(12345, []);
    expect(server.clientCount(), 0);
    server.shutDown();
  });
}