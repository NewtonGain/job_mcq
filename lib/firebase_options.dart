// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'AIzaSyBwdtvjDA6HHDfD5nob4FIiT2IbmhNj3VQ',
    appId: '1:355935041178:web:2199f1aa164c1322681123',
    messagingSenderId: '355935041178',
    projectId: 'job-mcq-712e4',
    authDomain: 'job-mcq-712e4.firebaseapp.com',
    storageBucket: 'job-mcq-712e4.firebasestorage.app',
    measurementId: 'G-CVZCSY36W9',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDgElMYVS0fOXME4wFkGf0gC2yFKzJ8eIY',
    appId: '1:355935041178:android:0ab10e0284af6096681123',
    messagingSenderId: '355935041178',
    projectId: 'job-mcq-712e4',
    storageBucket: 'job-mcq-712e4.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC8SJwFCbpJFGoGVOjLVJfc4zDe03Ky5EY',
    appId: '1:355935041178:ios:05f542cc706ccf93681123',
    messagingSenderId: '355935041178',
    projectId: 'job-mcq-712e4',
    storageBucket: 'job-mcq-712e4.firebasestorage.app',
    iosBundleId: 'com.example.jobMcq',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC8SJwFCbpJFGoGVOjLVJfc4zDe03Ky5EY',
    appId: '1:355935041178:ios:05f542cc706ccf93681123',
    messagingSenderId: '355935041178',
    projectId: 'job-mcq-712e4',
    storageBucket: 'job-mcq-712e4.firebasestorage.app',
    iosBundleId: 'com.example.jobMcq',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBwdtvjDA6HHDfD5nob4FIiT2IbmhNj3VQ',
    appId: '1:355935041178:web:886c886a88c7d2d0681123',
    messagingSenderId: '355935041178',
    projectId: 'job-mcq-712e4',
    authDomain: 'job-mcq-712e4.firebaseapp.com',
    storageBucket: 'job-mcq-712e4.firebasestorage.app',
    measurementId: 'G-R42RNW0S8Z',
  );
}
