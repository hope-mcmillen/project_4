import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/topic_pack.dart';

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            // These are short, bounded pages. Keep every form field mounted so
            // validation includes players that are currently off screen.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.purple,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class TopicBoard extends StatelessWidget {
  const TopicBoard({
    super.key,
    required this.topic,
    this.selected,
    this.onSelect,
  });
  final TopicPack topic;
  final String? selected;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) => InfoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(topic.name),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final word in topic.words)
                  SizedBox(
                    width: width,
                    child: onSelect == null
                        ? Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              word,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Semantics(
                            selected: selected == word,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                                backgroundColor: selected == word
                                    ? AppColors.lime
                                    : AppColors.paper,
                              ),
                              onPressed: () => onSelect!(word),
                              child: Text(word, textAlign: TextAlign.center),
                            ),
                          ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

/// A code-drawn mascot keeps the starter lightweight and scales to any screen.
class ChameleonMascot extends StatelessWidget {
  const ChameleonMascot({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'A green chameleon with a curled tail',
    child: const SizedBox(
      height: 165,
      width: 280,
      child: CustomPaint(painter: _MascotPainter()),
    ),
  );
}

class _MascotPainter extends CustomPainter {
  const _MascotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 280, size.height / 165);
    final green = Paint()..color = AppColors.lime;
    final dark = Paint()..color = AppColors.ink;
    canvas.drawLine(
      const Offset(30, 142),
      const Offset(248, 142),
      Paint()
        ..color = const Color(0xFF998DD0)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final body = Path()
      ..moveTo(79, 95)
      ..cubicTo(85, 21, 173, 17, 203, 80)
      ..lineTo(231, 96)
      ..quadraticBezierTo(220, 116, 184, 108)
      ..quadraticBezierTo(130, 138, 79, 95);
    canvas.drawPath(body, green);
    final tail = Path()
      ..moveTo(96, 95)
      ..cubicTo(66, 69, 21, 96, 41, 125)
      ..cubicTo(58, 146, 86, 118, 65, 107);
    canvas.drawPath(
      tail,
      Paint()
        ..color = AppColors.lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
    for (final x in [117.0, 174.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 108)
          ..lineTo(x - 9, 141)
          ..lineTo(x + 7, 141),
        Paint()
          ..color = AppColors.lime
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawCircle(const Offset(190, 81), 15, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(194, 80), 6, dark);
    canvas.drawCircle(const Offset(196, 78), 2, Paint()..color = Colors.white);
    canvas.drawPath(
      Path()
        ..moveTo(201, 103)
        ..quadraticBezierTo(213, 107, 222, 101),
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    for (final spot in [
      const Offset(113, 72),
      const Offset(140, 59),
      const Offset(157, 86),
    ]) {
      canvas.drawCircle(spot, 8, Paint()..color = const Color(0xFFA5C958));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
