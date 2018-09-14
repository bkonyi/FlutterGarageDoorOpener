import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:geofencing/geofencing.dart';

import 'garage_door_remote.dart';

Future<String> getFileData(String path) async =>
    await rootBundle.loadString(path);

Future<void> initialize() async {
  print('initializing');
  final context = SecurityContext()
    ..useCertificateChainBytes(
        (await getFileData('certs/client.crt')).codeUnits)
    ..usePrivateKeyBytes((await getFileData('certs/client.key')).codeUnits)
    ..setTrustedCertificatesBytes(
        (await getFileData('certs/domain.crt')).codeUnits);
  GarageDoorRemote.initialize(context);
  await GeofencingManager.initialize();
}
