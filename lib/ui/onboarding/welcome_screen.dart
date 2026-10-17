import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/hm_colors.dart';
import '../common/hm_buttons.dart';
import '../home/home_screen.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFDDE8E2),
                  Color(0xFFF3EFE7),
                  Color(0xFFE6DCCE),
                ],
              ),
            ),
          ),
          // Soft geometric plan motif
          Positioned(
            right: -40,
            top: size.height * 0.12,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: size.width * 0.55,
                height: size.width * 0.55,
                decoration: BoxDecoration(
                  border: Border.all(color: HmColors.spruce.withValues(alpha: 0.25), width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  Text(
                    'HomeMaker',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Design spaces that feel like yours — walls, furniture, and a clear 3D preview.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: HmColors.inkSecondary,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 28),
                  _Bullet(
                    icon: Icons.border_color_outlined,
                    title: 'Draw the plan',
                    body: 'Drag walls on a paper-like canvas. Measurements stay honest.',
                  ),
                  const SizedBox(height: 14),
                  _Bullet(
                    icon: Icons.chair_outlined,
                    title: 'Furnish freely',
                    body: '124 real models from Sweet Home 3D — Free Art, CC-BY, and CC0.',
                  ),
                  const SizedBox(height: 14),
                  _Bullet(
                    icon: Icons.threed_rotation,
                    title: 'Check the space',
                    body: 'Orbit an isometric view before you commit to a layout.',
                  ),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    child: HmPrimaryButton(
                      label: 'Get started',
                      onPressed: () async {
                        await ref.read(planStorageProvider).setSeenWelcome();
                        ref.invalidate(welcomeSeenProvider);
                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          CupertinoPageRoute<void>(builder: (_) => const HomeScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Made for phone and tablet',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: HmColors.spruce.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: HmColors.spruce, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
