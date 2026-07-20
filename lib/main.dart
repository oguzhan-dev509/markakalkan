import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/app.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';
import 'package:markakalkan/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppCheckBootstrap.instance.initialize();

  runApp(const MarkaKalkanApp());
}
