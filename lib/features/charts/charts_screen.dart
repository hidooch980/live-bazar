import 'package:flutter/material.dart';

/// CHARTS screen (§27, §18).
///
/// V1 honesty rule: no fabricated history. Real historical storage begins
/// once the app accumulates local observations (§19); until then the UI
/// explicitly reports that history is unavailable.
class ChartsScreen extends StatelessWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('چارت')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.show_chart,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'داده تاریخی در دسترس نیست',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'با کارکرد اپلیکیشن، داده‌های واقعی به صورت محلی جمع‌آوری و تجمیع می‌شوند؛ از آن پس چارت‌های ۱ساعته تا ۱ساله نمایش داده می‌شوند. هیچ داده تاریخی ساختگی تولید نمی‌شود.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
