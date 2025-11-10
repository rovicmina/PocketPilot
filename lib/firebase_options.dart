import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'AIzaSyDpEidxdLoZ9LWYXS4HcsYEV3aaJ12DT7Q',
    appId: '1:735861101098:web:pocketpilot',
    messagingSenderId: '735861101098',
    projectId: 'pocketpilot-c7ef3',
    authDomain: 'pocketpilot-c7ef3.firebaseapp.com',
    storageBucket: 'pocketpilot-c7ef3.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDpEidxdLoZ9LWYXS4HcsYEV3aaJ12DT7Q',
    appId: '1:735861101098:android:com.pocketpilot.app',
    messagingSenderId: '735861101098',
    projectId: 'pocketpilot-c7ef3',
    storageBucket: 'pocketpilot-c7ef3.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDpEidxdLoZ9LWYXS4HcsYEV3aaJ12DT7Q',
    appId: '1:735861101098:ios:pocketpilot',
    messagingSenderId: '735861101098',
    projectId: 'pocketpilot-c7ef3',
    storageBucket: 'pocketpilot-c7ef3.appspot.com',
    iosBundleId: 'com.pocketpilot.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDpEidxdLoZ9LWYXS4HcsYEV3aaJ12DT7Q',
    appId: '1:735861101098:macos:pocketpilot',
    messagingSenderId: '735861101098',
    projectId: 'pocketpilot-c7ef3',
    storageBucket: 'pocketpilot-c7ef3.appspot.com',
    iosBundleId: 'com.pocketpilot.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDpEidxdLoZ9LWYXS4HcsYEV3aaJ12DT7Q',
    appId: '1:735861101098:windows:pocketpilot',
    messagingSenderId: '735861101098',
    projectId: 'pocketpilot-c7ef3',
    authDomain: 'pocketpilot-c7ef3.firebaseapp.com',
    storageBucket: 'pocketpilot-c7ef3.appspot.com',
  );
}
