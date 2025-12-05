// File generated and fixed manually.
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCKflI5bAmipvNPJTrQYqGQtQk1UsbMPBk',
    appId: '1:893539426217:web:d154d72cabdb39d93a6eb8',
    messagingSenderId: '893539426217',
    projectId: 'warrantytrackerdemo',
    authDomain: 'warrantytrackerdemo.firebaseapp.com',
    storageBucket: 'warrantytrackerdemo.appspot.com',
    measurementId: 'G-QVZ79N74Z6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDIxNuKUbdI92-6QbXqGkwIzK1AVyt1s6o',
    appId: '1:893539426217:android:a6d489151cfd521f3a6eb8',
    messagingSenderId: '893539426217',
    projectId: 'warrantytrackerdemo',
    storageBucket: 'warrantytrackerdemo.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBE8kEmWPAB4-fk7phb8vZnesJElfOenso',
    appId: '1:893539426217:ios:575caf0a8b42c1293a6eb8',
    messagingSenderId: '893539426217',
    projectId: 'warrantytrackerdemo',
    storageBucket: 'warrantytrackerdemo.appspot.com',
    iosBundleId: 'com.example.warantyTracker',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBE8kEmWPAB4-fk7phb8vZnesJElfOenso',
    appId: '1:893539426217:ios:575caf0a8b42c1293a6eb8',
    messagingSenderId: '893539426217',
    projectId: 'warrantytrackerdemo',
    storageBucket: 'warrantytrackerdemo.appspot.com',
    iosBundleId: 'com.example.warantyTracker',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCKflI5bAmipvNPJTrQYqGQtQk1UsbMPBk',
    appId: '1:893539426217:web:81bbdf689c3a951f3a6eb8',
    messagingSenderId: '893539426217',
    projectId: 'warrantytrackerdemo',
    authDomain: 'warrantytrackerdemo.firebaseapp.com',
    storageBucket: 'warrantytrackerdemo.appspot.com',
    measurementId: 'G-MNQDDX2ZH3',
  );
}
