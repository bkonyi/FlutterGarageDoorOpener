import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'garage_common.dart';

// Since we're using a self-signed cert, we can't verify. Not ideal, but it is
// what it is.
bool _onBadCertificate(X509Certificate cert) => true;

abstract class GarageDoorRemote {
  static SecurityContext _context;

  static void initialize(SecurityContext context) => _context = context;

  static Future<bool> get isOpen async =>
      _sendRequest(garageIsOpenEvent, returnResponse: true);
  static Future<bool> openDoor() async => _sendRequest(garageOpenEvent);
  static Future<bool> closeDoor() async => _sendRequest(garageCloseEvent);
  static Future<bool> triggerDoor() async => _sendRequest(garageTriggerEvent);
  static Future<void> closeDoorIn(int seconds) async =>
      _sendRequest(garageCloseInEvent, delay: seconds);
  static Future<void> openDoorFor(int seconds) async =>
      _sendRequest(garageOpenForEvent, delay: seconds);

  static Future<bool> _sendRequest(int type,
      {int delay, bool returnResponse = false}) async {
    try {
      final connection = await SecureSocket.connect(
          garageExternalIP, garagePort,
          context: _context, onBadCertificate: _onBadCertificate);
      final request = {
        garageEventType: type,
      };
      if (delay != null) {
        request[garageEventDelay] = delay;
      }
      connection.write(json.encode(request));
      if (returnResponse) {
        final completer = Completer<bool>();
        connection.listen((r) {
          final Map response = json.decode(utf8.decode(r));
          completer.complete(response[garageResponse]);
        });
        connection.close();
        return completer.future;
      }
      connection.close();
      return true;
    } catch (e) {
      print('Client Error: $e');
      return false;
    }
  }
}
