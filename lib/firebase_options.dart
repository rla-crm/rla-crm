// File generated manually for RLA CRM Firebase project
// Project: rla-crm | https://console.firebase.google.com/project/rla-crm

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBiogarEeThBPthpevhCBC3F4ONtYedLqc',
    authDomain: 'rla-crm.firebaseapp.com',
    projectId: 'rla-crm',
    storageBucket: 'rla-crm.firebasestorage.app',
    messagingSenderId: '753567723562',
    appId: '1:753567723562:web:0c531585a3a43199161353',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBiogarEeThBPthpevhCBC3F4ONtYedLqc',
    authDomain: 'rla-crm.firebaseapp.com',
    projectId: 'rla-crm',
    storageBucket: 'rla-crm.firebasestorage.app',
    messagingSenderId: '753567723562',
    appId: '1:753567723562:web:0c531585a3a43199161353',
  );
}
