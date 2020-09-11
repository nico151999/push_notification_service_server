import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:AndroidPushNotificationServer/android_push_notification_server.dart';
import 'package:tuple/tuple.dart';

void main() {
  NotificationRunner.initializeRunner(12345).then((runner) => runner._waitForInput());
}

class NotificationRunner {

  ReceivePort _mainPort;

  static final Map<String, dynamic> _options = {
    's': Tuple2('Send message', [
      Tuple3('p', 'target package', false),
      Tuple3('c', 'target channel (senseless if no target package was specified)', false),
      Tuple3('t', 'notification title', true),
      Tuple3('m', 'notification message', true),
      Tuple3('u', 'URI that\'s opened when notification is clicked by the user', false),
      Tuple3('i', 'icon that\'s shown in the notification (base64 encoded)', false)
    ]),
    'x': 'Exit'
  };

  NotificationRunner._(PushNotificationServer server) {
    print('This is the server related to the push notification test app.');
    _mainPort = ReceivePort();
    _mainPort.listen((input) {
      if (input is SendPort) {
        input.send(_options);
      } else if (input is String) {
        if (input == _options.keys.last) {
          server.shutDown();
          _mainPort.close();
        }
      } else if (input is Map<String, String>) {
        server.sendPushNotification(
            input['t'],
            input['m'],
            uri: input['u'],
            icon: input['i'],
            channel: input['c'],
            package: input['p']
        );
        _waitForInput();
      }
    });
  }

  void _waitForInput() {
    Isolate.spawn(
        isolatedInput,
        _mainPort.sendPort
    );
  }

  static Future<NotificationRunner> initializeRunner(int port) async {
    return NotificationRunner._(
        await PushNotificationServer.initializeServer(port)
    );
  }
}


void isolatedInput(SendPort message) {
  ReceivePort isolatePort = ReceivePort();
  isolatePort.listen((options) {
    String selection = getMainInput(options);
    dynamic selectionValue = options[selection];
    if (selectionValue is String) {
      message.send(selection);
    } else {
      Map<String, String> ret = Map<String, String>();
      (selectionValue.item2 as List<Tuple3>).forEach((tuple3) {
        String input = getInput(tuple3);
        if (input.length > 0) {
          ret[tuple3.item1] = input;
        }
      });
      message.send(ret);
    }
    isolatePort.close();
  });
  message.send(isolatePort.sendPort);
}

String getInput(Tuple3 tuple3) {
  if (!tuple3.item3) {
    print('The following selection is optional. '
        'If you do not want to specify it, just press enter.');
  }
  print('Please type your desired ${tuple3.item2}:');
  String input = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
  if (tuple3.item3 && input.length == 0) {
    print('This selection is not optional. Try again...');
    getInput(tuple3);
  }
  return input;
}

String getMainInput(Map<String, dynamic> allowedInputs) {
  print('You have following options:');
  allowedInputs.forEach((key, value) {
    print('$key: ' + (value is Tuple2 ? value.item1 : value));
  });
  String input = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
  if (!allowedInputs.keys.contains(input)) {
    print('Only the following inputs are allowed: $allowedInputs\nTry again...');
    return getMainInput(allowedInputs);
  }
  return input;
}