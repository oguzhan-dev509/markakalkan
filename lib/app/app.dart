import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/home/presentation/markakalkan_home_page.dart';

class MarkaKalkanApp extends StatelessWidget {
  const MarkaKalkanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MarkaKalkan',
      theme: MarkaKalkanTheme.light,
      home: const MarkaKalkanHomePage(),
    );
  }
}
