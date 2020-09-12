import 'dart:convert';
import 'dart:core';
import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

import 'package:tuple/tuple.dart';

class PushNotificationServer {
  ServerSocket _serverSocket;
  List<Tuple2<Socket, Map<String, List<String>>>> _sockets;

  void shutDown() async {
    for (Tuple2<Socket, Map<String, List<String>>> socket in _sockets) {
      await socket.item1.close();
    }
    await _serverSocket.close();
  }

  Iterable<Tuple2<Socket, Map<String, List<String>>>> _getSockets([String package, String channel]) {
    if (package == null) {
      return _sockets;
    }
    Iterable<Tuple2<Socket, Map<String, List<String>>>> sockets = _sockets
        .where((socket) => socket.item2.containsKey(package));
    if (channel == null) {
      return sockets;
    }
    return sockets.where((socket) => socket.item2[package].contains(channel));
  }

  int clientCount([String package, String channel]) {
    return _getSockets(package, channel).length;
  }

  void sendPushNotification(String title, String message, {String uri, String icon, String package, String channel}) {
    Map<String, dynamic> notification = {
      'title': title,
      'content': message
    };
    <String, String>{'uri': uri, 'icon': icon}.forEach((name, param) {
      if (param != null) {
        notification[name] = param;
      }
    });
    Map<String, Map<String, dynamic>> pushNotification = {
      'push_notification': notification
    };
    _getSockets(package, channel).forEach(
      (socket) {
        socket.item2.keys.forEach((package) {
          notification['receiver'] = package;
          socket.item1.writeln(jsonEncode(pushNotification));
        });
      }
    );
  }

  PushNotificationServer._(ServerSocket serverSocket) {
    _serverSocket = serverSocket;
    _sockets = <Tuple2<Socket, Map<String, List<String>>>>[];
    _serverSocket.listen((Socket socket) {
      Tuple2<Socket, Map<String, List<String>>> socketEntry = Tuple2(socket, <String, List<String>>{});
      _sockets.add(socketEntry);
      socket.listen((Uint8List data) {
        String message = String.fromCharCodes(data);
        message = message.substring(0, message.length - 1);
        Map<String, dynamic> rootJson = jsonDecode(message);
        switch (rootJson.keys.first) {
          case 'application_subscription':
            String package = rootJson['application_subscription']['package'];
            Map<String, List<String>> packages = socketEntry.item2;
            if (package != null && !packages.containsKey(package)) {
              packages[package] = <String>[];
            }
            break;
          case 'channel_subscription':
            Map<String, dynamic> json = Map.from(rootJson['channel_subscription']);
            String package = json['package'];
            String channel = json['channel'];
            Map<String, List<String>> packageChannels = socketEntry.item2;
            if (package != null && packageChannels.containsKey(package) && channel != null) {
              List<String> channels = packageChannels[package];
              if (!channels.contains(channel)) {
                channels.add(channel);
              }
            } else {
              _finishSocket(socketEntry);
            }
            break;
          case 'clients':
            try {
              socketEntry.item2.addAll(
                  Map.from(rootJson['clients']).map(
                          (key, value) => MapEntry<String, List<String>>(key, List<String>.from(value))
                  )
              );
            } on TypeError {
              _finishSocket(socketEntry);
            }
            break;
          default:
            _finishSocket(socketEntry);
            break;
        }
      }, onDone: () {
        _finishSocket(socketEntry);
      }, onError: (error) {
        _finishSocket(socketEntry);
      });
    });
  }

  static Future<PushNotificationServer> initializeServer(int port) async {
    return PushNotificationServer._(
        await ServerSocket.bind(InternetAddress.anyIPv4, port)
    );
  }

  void _finishSocket(Tuple2<Socket, Map<String, List<String>>> socketEntry) {
    try {
      socketEntry.item1.close();
    } on SocketException {}
    _sockets.remove(socketEntry);
  }
}