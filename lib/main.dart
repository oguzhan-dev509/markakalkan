import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/app.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';
import 'package:markakalkan/firebase_options.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_lifecycle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppCheckBootstrap.instance.initialize();

  final riskLifecycle = RiskOperationsLifecycleProvider.instance;
  riskLifecycle.observeAuthentication(
    FirebaseAuth.instance.currentUser != null,
  );
  FirebaseAuth.instance.authStateChanges().listen(
    (user) => riskLifecycle.observeAuthentication(user != null),
  );

  runApp(const MarkaKalkanApp());
}
