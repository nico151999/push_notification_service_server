import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:AndroidPushNotificationServer/android_push_notification_server.dart';
import 'package:tuple/tuple.dart';

void main() async {
  (await NotificationRunner.initializeRunner(12345))._waitForInput();
}

class NotificationRunner {

  ReceivePort _mainPort;
  PushNotificationServer _server;

  final Map<String, Tuple2<String, Function(NotificationRunner, [String, String, String, String])>> _options = {
    'a': Tuple2('Send message to all', (runner, [title, message, uri, icon]) {
      print('Sending message to ${runner._server.clientCount()} clients');
      runner._server.sendPushNotification(
        title,
        message,
        uri: uri,
        icon: icon
      );
      runner._waitForInput();
    }),
    'i': Tuple2('Send message to it subscribers', (runner, [title, message, uri, icon]) {
      String category = 'it';
      print('Sending message to ${runner._server.clientCount(category)} clients');
      runner._server.sendPushNotification(
          title,
          message,
          uri: uri,
          icon: icon,
          category: category
      );
      runner._waitForInput();
    }),
    's': Tuple2('Send message to sports subscribers', (runner, [title, message, uri, icon]) {
      String category = 'sports';
      print('Sending message to ${runner._server.clientCount(category)} clients');
      runner._server.sendPushNotification(
          title,
          message,
          uri: uri,
          icon: icon,
          category: category
      );
      runner._waitForInput();
    }),
    'f': Tuple2('Send message to finance subscribers', (runner, [title, message, uri, icon]) {
      String category = 'finance';
      print('Sending message to ${runner._server.clientCount(category)} clients');
      runner._server.sendPushNotification(
          title,
          message,
          uri: uri,
          icon: icon,
          category: category
      );
      runner._waitForInput();
    }),
    'x': Tuple2('Exit', (runner, [title, message, uri, icon]) {
      runner._server.shutDown();
      runner._mainPort.close();
    })
  };

  NotificationRunner._(PushNotificationServer server) {
    _server = server;
    _mainPort = ReceivePort();
    _mainPort.listen((input) {
      if (input is SendPort) {
        input.send(_options.keys.join(','));
      } else if (input == _options.keys.last) {
        _options[input].item2(this);
      } else {
        Map<String, dynamic> inputs = jsonDecode(input);
        String uri = inputs['u'];
        String icon = inputs['i'];
        _options[inputs['o']].item2(
          this,
          inputs['t'],
          inputs['m'],
          uri.isEmpty ? null : uri,
          icon.isEmpty ? null : icon
        );
      }
    });
    print('This is the server related to the push notification test app. '
        'You will have following options to choose from when you are '
        'prompted to input something.');
    _options.forEach((key, tuple) {
      print('$key: ${tuple.item1}');
    });
    print('Unless you input ${_options.keys.last}, you will have to '
        'input a title followed by a message right after. Then you will '
        'have the option to either input a URI that will be handled as an '
        'intent by the receivers or just press enter to skip the uri '
        'input. Finally you can optionally input a base64 encoded icon '
        'or just press enter again to make the client show the default icon.');
  }

  void _waitForInput() {
    Isolate.spawn(
        isolatedInput,
        _mainPort.sendPort
    );
  }

  static Future<NotificationRunner> initializeRunner(int port) async {
    return NotificationRunner._(
        await PushNotificationServer.initializeServer(
            port,
            <String>['it', 'finance', 'sports']
        )
    );
  }
}


void isolatedInput(SendPort message) {
  ReceivePort isolatePort = ReceivePort();
  isolatePort.listen((allowedInputs) {
    List<String> allowedInputsList = allowedInputs.split(',');
    String option = getInput(allowedInputsList);
    if (option == allowedInputsList.last) {
      message.send(option);
    } else {
      message.send(jsonEncode(<String, String>{
        'o': option,
        't': getInput(),
        'm': getInput(),
        'u': getInput(),
        'i': getInput()
      }));
    }
    isolatePort.close();
  });
  message.send(isolatePort.sendPort);
}

String getInput([List<String> allowedInputs]) {
  print('Please input something:');
  String input = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
  if (allowedInputs != null && !allowedInputs.contains(input)) {
    print('Only the following inputs are allowed: $allowedInputs\nTry again...');
    return getInput(allowedInputs);
  }
  return input;
}