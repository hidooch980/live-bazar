import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/home_widget_service.dart';

enum WidgetPreviewSize {
  small(1, 'کوچک'),
  medium(3, 'متوسط'),
  large(6, 'بزرگ');

  const WidgetPreviewSize(this.capacity, this.labelFa);
  final int capacity;
  final String labelFa;

  /// The widget sizes that show the asset at [index] of the user's list.
  static List<WidgetPreviewSize> showing(int index) => [
    for (final s in values)
      if (index < s.capacity) s,
  ];
}

/// Vazirmatn has no ▲ ▼ ★ ▬ ₮; on a phone the system font fills them in.
/// Naming a fallback lets tests (which have no system fonts) load one.
const symbolFallback = <String>['MolidoSymbols'];

const _up = Color(0xFF4ADE80);
const _down = Color(0xFFF87171);

const toneColors = <String, List<Color>>{
  'green': [Color(0xFF6EE7B7), Color(0xFF059669)],
  'gold': [Color(0xFFFDE68A), Color(0xFFC8960C)],
  'teal': [Color(0xFF5EEAD4), Color(0xFF0D9488)],
  'blue': [Color(0xFF93C5FD), Color(0xFF2563EB)],
  'orange': [Color(0xFFFDBA74), Color(0xFFEA580C)],
  'purple': [Color(0xFFC4B5FD), Color(0xFF7C3AED)],
  'silver': [Color(0xFFF3F4F6), Color(0xFF9CA3AF)],
};

/// In-app preview of the home-screen widget, drawn from the SAME rows the
/// Android widget receives (and so from real quotes only). Flutter can
/// blur for real here; the Android widget approximates the glass.
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.rows,
    required this.size,
    required this.updated,
    this.live = false,
  });

  final List<WidgetRow> rows;
  final WidgetPreviewSize size;
  final String updated;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final shown = rows.take(size.capacity).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.30),
                  Colors.white.withValues(alpha: 0.12),
                ],
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Vazirmatn',
                fontFamilyFallback: symbolFallback,
                shadows: [Shadow(color: Color(0x66000000), blurRadius: 3)],
              ),
              child: switch (size) {
                WidgetPreviewSize.small => _small(shown),
                WidgetPreviewSize.medium => _medium(shown),
                WidgetPreviewSize.large => _large(shown),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _small(List<WidgetRow> r) {
    final row = r.isEmpty ? null : r.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (row != null) _Icon(row, 30),
            const Spacer(),
            const _Brand(short: true),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          row?.label ?? 'بازار مولیدو',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        if (row != null) _Value(row, 24),
        const Spacer(),
        if (row != null)
          Row(
            children: [
              Expanded(child: _Spark(row, 26)),
              const SizedBox(width: 6),
              _Pill(row),
            ],
          ),
        const SizedBox(height: 4),
        _Updated(updated),
      ],
    );
  }

  Widget _medium(List<WidgetRow> r) => Column(
    children: [
      Row(children: [const _Brand(), const Spacer(), _Updated(updated)]),
      const SizedBox(height: 8),
      Expanded(
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              Expanded(
                child: i < r.length
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Icon(r[i], 22),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  r[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _Value(r[i], 15, stacked: true),
                          ),
                          const Spacer(),
                          _Spark(r[i], 20),
                          const SizedBox(height: 3),
                          _Pill(r[i]),
                        ],
                      )
                    : const SizedBox(),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _large(List<WidgetRow> r) => Column(
    children: [
      Row(
        children: [
          const _Brand(),
          const Spacer(),
          if (live) const _LiveBadge(),
        ],
      ),
      const SizedBox(height: 6),
      for (var i = 0; i < r.length; i++) ...[
        if (i > 0)
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
        Expanded(
          child: Row(
            children: [
              _Icon(r[i], 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      r[i].subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 64, child: _Spark(r[i], 22)),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Value(r[i], 15),
                  const SizedBox(height: 2),
                  _Pill(r[i]),
                ],
              ),
            ],
          ),
        ),
      ],
      if (r.length < 6) Spacer(flex: 6 - r.length),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(child: _Updated(updated)),
          Text(
            'قیمت‌ها به تومان',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    ],
  );
}

class _Brand extends StatelessWidget {
  const _Brand({this.short = false});
  final bool short;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
            colors: [Color(0xFFFDE68A), Color(0xFFC8960C)],
          ),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        short ? 'مولیدو' : 'بازار مولیدو',
        style: TextStyle(
          fontSize: short ? 10 : 12,
          fontWeight: short ? FontWeight.w400 : FontWeight.w700,
        ),
      ),
    ],
  );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0x3322C55E),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0x5522C55E)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 3, backgroundColor: _up),
        SizedBox(width: 4),
        Text(
          'زنده',
          style: TextStyle(
            fontSize: 9,
            color: _up,
            fontWeight: FontWeight.w700,
            shadows: [],
          ),
        ),
      ],
    ),
  );
}

class _Icon extends StatelessWidget {
  const _Icon(this.row, this.size);
  final WidgetRow row;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: toneColors[row.tone] ?? toneColors['purple']!,
      ),
    ),
    child: Text(
      row.glyph,
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontSize: size * 0.46,
        fontWeight: FontWeight.w800,
        shadows: const [],
      ),
    ),
  );
}

class _Value extends StatelessWidget {
  const _Value(this.row, this.fontSize, {this.stacked = false});
  final WidgetRow row;
  final double fontSize;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final value = Text(
      row.value,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: row.stale ? Colors.white70 : Colors.white,
      ),
    );
    final unit = Text(
      row.unit,
      style: TextStyle(
        fontSize: fontSize * 0.5,
        color: Colors.white.withValues(alpha: 0.78),
      ),
    );
    return stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [value, unit],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [value, const SizedBox(width: 3), unit],
          );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.row);
  final WidgetRow row;

  @override
  Widget build(BuildContext context) {
    if (row.change.isEmpty) return const SizedBox(height: 16);
    final up = row.direction >= 0;
    final c = up ? _up : _down;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        row.change,
        style: TextStyle(
          fontSize: 9,
          color: c,
          fontWeight: FontWeight.w700,
          shadows: const [],
        ),
      ),
    );
  }
}

class _Updated extends StatelessWidget {
  const _Updated(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.8)),
  );
}

class _Spark extends StatelessWidget {
  const _Spark(this.row, this.height);
  final WidgetRow row;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pts = [for (final s in row.spark.split(',')) ?double.tryParse(s)];
    if (pts.length < 2) return SizedBox(height: height);
    final rising = row.direction != 0
        ? row.direction > 0
        : pts.last >= pts.first;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: SparklinePainter(pts, rising ? _up : _down)),
    );
  }
}

/// Mirrors the native bitmap: time runs left → right, fill fades down.
class SparklinePainter extends CustomPainter {
  SparklinePainter(this.points, this.color);
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 2.0;
    final step = (size.width - 2 * pad) / (points.length - 1);
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final x = pad + i * step;
      final y = pad + (1 - points[i].clamp(0, 1)) * (size.height - 2 * pad);
      i == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
    }
    final fill = Path.from(line)
      ..lineTo(pad + (points.length - 1) * step, size.height)
      ..lineTo(pad, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.33), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter old) =>
      old.points != points || old.color != color;
}

/// The colourful «wallpaper» the preview floats on, like the mockup.
class WallpaperBackdrop extends StatelessWidget {
  const WallpaperBackdrop({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C5CFF), Color(0xFFB04FD6), Color(0xFFF0607E)],
      ),
    ),
    child: child,
  );
}
