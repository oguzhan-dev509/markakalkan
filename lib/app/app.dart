import 'package:flutter/material.dart';
import 'package:markakalkan/app/initial_route_resolver.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/home/presentation/markakalkan_home_page.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/presentation/counterfeit_twin_public_detail_page.dart';

class MarkaKalkanApp extends StatelessWidget {
  const MarkaKalkanApp({super.key});

  Widget _initialPage() {
    final counterfeitTwinSlug = resolveInitialCounterfeitTwinSlug(Uri.base);
    if (counterfeitTwinSlug != null) {
      return CounterfeitTwinPublicDetailPage(slug: counterfeitTwinSlug);
    }

    return const MarkaKalkanHomePage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MarkaKalkan',
      theme: MarkaKalkanTheme.light,
      home: _initialPage(),
    );
  }
}
