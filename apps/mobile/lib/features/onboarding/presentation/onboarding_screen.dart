import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/data/auth_repository.dart';

class _OnboardingStep {
  const _OnboardingStep({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

const _steps = [
  _OnboardingStep(
    icon: Icons.calculate_outlined,
    title: 'Dozens of calculators, one app',
    body: 'EMI, SIP, GST, BMI, and more — all in one place, all free to start.',
  ),
  _OnboardingStep(
    icon: Icons.bolt_outlined,
    title: 'Coins keep it fair',
    body: 'Use coins to unlock extra runs on premium calculators. Earn more by '
        'watching a short ad, or go Premium for unlimited access.',
  ),
  _OnboardingStep(
    icon: Icons.build_circle_outlined,
    title: 'Build your own formula',
    body: "Not on the list? Build a custom calculator with your own formula, "
        "no coding required.",
  ),
];

/// Three-step first-run onboarding shown once, right after a user's first
/// sign-in (see [OnboardingGate]). Marks `onboardingComplete: true` on the
/// user's Firestore doc when finished or skipped.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final repository = context.read<AuthRepository>();
    final uid = repository.currentUser?.uid;
    if (uid == null) return;
    setState(() => _submitting = true);
    try {
      await repository.markOnboardingComplete(uid);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _page == _steps.length - 1;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _submitting ? null : _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(step.icon, size: 96, color: colorScheme.primary),
                        const SizedBox(height: 24),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                  width: index == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _page ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          if (isLastPage) {
                            _finish();
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLastPage ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
