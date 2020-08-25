import 'dart:convert';
import 'dart:core';
import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

import 'package:tuple/tuple.dart';

class PushNotificationServer {

  ServerSocket _serverSocket;
  List<Tuple2<Socket, List<String>>> _sockets;
  List<String> _categories;

  void shutDown() async {
    for (Tuple2<Socket, List<String>> socket in _sockets) {
      await socket.item1.close();
    }
    await _serverSocket.close();
  }

  Iterable<Tuple2<Socket, List<String>>> _getSockets([String category]) {
    return category == null ?
        _sockets :
        _sockets.where((socket) => socket.item2.contains(category)).toList();
  }

  int clientCount([String category]) {
    return _getSockets(category).length;
  }

  void sendPushNotification(String title, String message, {String uri, String icon, String category}) {
    Map<String, dynamic> pushNotification = {
      'title': title,
      'message': message
    };
    <String, String>{
      'uri': uri,
      'icon': icon
    }.forEach((name, param) {
      if (param != null) {
        pushNotification[name] = param;
      }
    });
    _getSockets(category).forEach((socket) =>
        socket.item1.writeln(jsonEncode(pushNotification))
    );
  }

  PushNotificationServer._(ServerSocket serverSocket, [List<String> categories]) {
    _categories = categories == null ? <String>[] : categories;
    _serverSocket = serverSocket;
    _sockets = <Tuple2<Socket, List<String>>>[];
    _serverSocket.listen((Socket socket) {
      Tuple2<Socket, List<String>> socketEntry = Tuple2(socket, <String>[]);
      _sockets.add(socketEntry);
      socket.listen((Uint8List data) {
        String category = String.fromCharCodes(data);
        category = category.substring(0, category.length - 1);
        if (_categories.contains(category)) {
          socketEntry.item2.add(category);
        } else {
          _closeSocket(socket);
        }
      }, onDone: () {
        _closeSocket(socket);
        _sockets.remove(socketEntry);
      });
    });
  }

  static Future<PushNotificationServer> initializeServer(int port, List<String> categories) async {
    return PushNotificationServer._(
        await ServerSocket.bind(InternetAddress.anyIPv4, port),
        categories
    );
  }

  void _closeSocket(Socket socket) {
    try {
      socket.close();
    } on SocketException {}
  }
}