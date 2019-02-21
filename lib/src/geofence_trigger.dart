import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofencing/geofencing.dart';
import 'package:geolocator/geolocator.dart';

import 'common.dart';
import 'garage_door_remote.dart';

abstract class GeofenceTrigger {
  // State needed to post notifications.
  static final _notificationPlugin = FlutterLocalNotificationsPlugin();
  static final _androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  static final _initializationSettings =
      InitializationSettings(_androidInitSettings, null);
  static final _androidNot = AndroidNotificationDetails('garage_door_opener',
      'garage_door_opener', 'Show when garage door is opened from geofencing');
  static final _platNot = NotificationDetails(_androidNot, null);

  static Future<void> postNotification(
          int id, String title, String body) async =>
      await _notificationPlugin.show(id, title, body, _platNot);

  // Geofencing state.
  static final _androidSettings = AndroidGeofencingSettings(initialTrigger: [
    GeofenceEvent.enter,
    GeofenceEvent.exit,
  ], notificationResponsiveness: 0, loiteringDelay: 0);

  static bool _isInitialized = false;
  static StreamSubscription _locationUpdates;

  static Future<void> _initialize() async {
    if (!_isInitialized) {
      await initialize();
      _notificationPlugin.initialize(_initializationSettings);
      _isInitialized = true;
    }
  }

  static Future<void> _startUpdates() async {
    print('Starting location updates');
    await GeofencingManager.promoteToForeground();
    _locationUpdates =
        (await Geolocator().getPositionStream()).listen(_handleLocationUpdate);
  }

  static Future<void> _stopUpdates() async {
    await _locationUpdates?.cancel();
    _locationUpdates = null;
    await GeofencingManager.demoteToBackground();
  }

  static Future<void> _handleLocationUpdate(Position p) async {
    final home = homeRegion.location;
    final distance = await Geolocator().distanceBetween(
        p.latitude, p.longitude, home.latitude, home.longitude);
    print('Distance to home: $distance');
    if (distance < 100.0) {
      if (!(await GarageDoorRemote.isOpen)) {
        await postNotification(0, 'Opening Garage Door',
            'A geofence event has triggered the garage door!');
        await GarageDoorRemote.openDoor();
      } else {
        await postNotification(0, 'Within 100m of home', 'Door is already open.');
      }
      await _stopUpdates();
    }
  }

  static final homeRegion = GeofenceRegion(
      'home',
      0.0,
      0.0,
      1000.0,
      <GeofenceEvent>[
        GeofenceEvent.enter,
        GeofenceEvent.exit,
      ],
      androidSettings: _androidSettings);

  static Future<void> homeGeofenceCallback(
      List<String> id, Location location, GeofenceEvent event) async {
    await _initialize();
    if (event == GeofenceEvent.enter) {
      await _startUpdates();
    } else if ((event == GeofenceEvent.exit) && (_locationUpdates != null)) {
      await postNotification(0, 'Leaving home geofence', 'Stopped frequent location updates.');
      await _stopUpdates();
    }
  }
}
