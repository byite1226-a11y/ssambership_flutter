import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class SsambershipApp extends StatelessWidget {
  const SsambershipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '쌤버십',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
