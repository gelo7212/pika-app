import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class FirebaseConfig {
  // Firebase configuration options
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDN9j1m8Kxw5KqVmxtA9p_q2dPMGXF_fMc',
    appId: '1:772116536818:android:1f02017fe9836f48271f6b',
    messagingSenderId: '772116536818',
    projectId: 'esbi-cafe-dev',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDN9j1m8Kxw5KqVmxtA9p_q2dPMGXF_fMc',
    appId: '1:772116536818:ios:1f02017fe9836f48271f6b',
    messagingSenderId: '772116536818',
    projectId: 'esbi-cafe-dev',
    iosBundleId: 'com.example.customerOrderApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDN9j1m8Kxw5KqVmxtA9p_q2dPMGXF_fMc',
    appId: '1:772116536818:web:1f02017fe9836f48271f6b',
    messagingSenderId: '772116536818',
    projectId: 'esbi-cafe-dev',
    authDomain: 'esbi-cafe-dev.firebaseapp.com',
    storageBucket: 'esbi-cafe-dev.firebasestorage.app',
    measurementId: 'G-SHXZRP1H0P',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDN9j1m8Kxw5KqVmxtA9p_q2dPMGXF_fMc',
    appId: '1:772116536818:ios:1f02017fe9836f48271f6b',
    messagingSenderId: '772116536818',
    projectId: 'esbi-cafe-dev',
    iosBundleId: 'com.example.customerOrderApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDN9j1m8Kxw5KqVmxtA9p_q2dPMGXF_fMc',
    appId: '1:772116536818:web:1f02017fe9836f48271f6b',
    messagingSenderId: '772116536818',
    projectId: 'esbi-cafe-dev',
    authDomain: 'esbi-cafe-dev.firebaseapp.com',
    storageBucket: 'esbi-cafe-dev.firebasestorage.app',
    measurementId: 'G-SHXZRP1H0P',
  );

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
}
