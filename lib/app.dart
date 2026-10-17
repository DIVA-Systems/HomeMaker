import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'theme/hm_theme.dart';
import 'ui/home/home_screen.dart';
import 'ui/onboarding/welcome_screen.dart';

class HomeMakerApp extends ConsumerWidget {
  const HomeMakerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final welcome = ref.watch(welcomeSeenProvider);

    return MaterialApp(
      title: 'HomeMaker',
      debugShowCheckedModeBanner: false,
      theme: HmTheme.material(Brightness.light),
      darkTheme: HmTheme.material(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return CupertinoTheme(
          data: HmTheme.cupertino(Theme.of(context).brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: welcome.when(
        loading: () => const Scaffold(
          body: Center(child: CupertinoActivityIndicator()),
        ),
        error: (_, __) => const HomeScreen(),
        data: (seen) => seen ? const HomeScreen() : const WelcomeScreen(),
      ),
    );
  }
}
