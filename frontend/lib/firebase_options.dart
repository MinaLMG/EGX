// File generated manually with web & android configurations.
// For more info: https://firebase.flutter.dev/docs/cli

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── iOS (iPhone/iPad) ──────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCCe_xPT294jyYq1IMAfZxvVzQB4mcGjng',
    appId: '1:950929147311:ios:ae5b8b8a444109a7ecdb5a',
    messagingSenderId: '950929147311',
    projectId: 'egx-10666',
    storageBucket: 'egx-10666.firebasestorage.app',
    iosBundleId: 'com.example.egxMobile',
  );

  // ── Web (Flutter Web / Vercel) ─────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA2FSZ2TzCDdA1F1yjC53EaXgZxY-Ze5uo',
    authDomain: 'egx-10666.firebaseapp.com',
    projectId: 'egx-10666',
    storageBucket: 'egx-10666.firebasestorage.app',
    messagingSenderId: '950929147311',
    appId: '1:950929147311:web:4da686399c527c62ecdb5a',
    measurementId: 'G-5MBCJ61BP3',
  );

  // ── Android ────────────────────────────────────────────────────────────────
  // Values are read from google-services.json automatically on Android.
  // This entry is here for completeness; initializeApp() uses the JSON file.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA2FSZ2TzCDdA1F1yjC53EaXgZxY-Ze5uo',
    authDomain: 'egx-10666.firebaseapp.com',
    projectId: 'egx-10666',
    storageBucket: 'egx-10666.firebasestorage.app',
    messagingSenderId: '950929147311',
    appId: '1:950929147311:android:0c69d30647265d3cecdb5a',
  );
}
