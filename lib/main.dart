import 'package:flutter/material.dart';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/services.dart';

class Cooler {
  String id;
  String nickname;
  String mode;
  String? bleRemoteId;

  Cooler({required this.id, required this.nickname, required this.mode, this.bleRemoteId});

  Map<String, dynamic> toJson() =>
      {"id": id, "nickname": nickname, "mode": mode, "bleRemoteId": bleRemoteId};

  factory Cooler.fromJson(Map<String, dynamic> j) => Cooler(
        id: j["id"],
        nickname: j["nickname"],
        mode: j["mode"],
        bleRemoteId: j["bleRemoteId"],
      );
}

const String kAppVersion = "2.0.0";

class CyberColors {
  static const Color bg = Color(0xFF08080B);
  static const Color bgDeep = Color(0xFF000000);
  static const Color panel = Color(0xFF14141A);
  static const Color panelLight = Color(0xFF22222C);
  static const Color glass = Color(0xFF15151C);

  static const Color rog = Color(0xFFFF1A3C);
  static const Color ember = Color(0xFFFF7A1A);
  static const Color cyan = Color(0xFF00F0FF);
  static const Color magenta = Color(0xFFFF2BD6);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color amber = Color(0xFFFFC145);
  static const Color danger = Color(0xFFFF3860);
  static const Color success = Color(0xFF39FF88);
  static const Color textDim = Color(0xFF9A9AA8);

  static List<Color> shine(Color c) => [
        Color.lerp(c, Colors.white, 0.35) ?? c,
        c,
        Color.lerp(c, Colors.black, 0.25) ?? c,
      ];
}

const String kAccentPrefKey = 'accent_color';
int? gSavedAccent;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    gSavedAccent = prefs.getInt(kAccentPrefKey);
  } catch (_) {}
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PROJECT V2',
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: CyberColors.bg,
        colorScheme: ColorScheme.dark(
          primary: CyberColors.rog,
          secondary: CyberColors.ember,
          surface: CyberColors.panel,
        ),
        splashColor: CyberColors.rog.withOpacity(0.14),
        highlightColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: SplashScreen(),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double scroll;
  final Color color;
  _GridPainter({required this.scroll, required this.color});

  @override
  void paint(Canvas canvas, Size size) {

    final paint = Paint()
      ..color = color.withOpacity(0.075)
      ..strokeWidth = 1.3;
    const spacing = 28.0;
    final offset = (scroll * spacing) % spacing;
    final h = size.height;
    for (double x = -h - spacing + offset; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, h), Offset(x + h, 0), paint);
    }
    final vignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.15,
        colors: [Colors.transparent, CyberColors.bgDeep.withOpacity(0.7)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => true;
}

class _ScanlinePainter extends CustomPainter {
  final double t;
  final Color color;
  _ScanlinePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * t;
    final rect = Rect.fromLTWH(0, y - 60, size.width, 120);
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, color.withOpacity(0.08), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, sweepPaint);

    final linePaint = Paint()..color = Colors.white.withOpacity(0.015);
    for (double ly = 0; ly < size.height; ly += 3) {
      canvas.drawLine(Offset(0, ly), Offset(size.width, ly), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => true;
}

class CyberBackdrop extends StatelessWidget {
  final double gridScroll;
  final double scanT;
  final Color color;
  const CyberBackdrop({Key? key, required this.gridScroll, required this.scanT, this.color = CyberColors.rog})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.3,
              colors: [Color(0xFF0B1220), CyberColors.bgDeep],
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter(scroll: gridScroll, color: color)),
        CustomPaint(painter: _ScanlinePainter(t: scanT, color: color)),
      ],
    );
  }
}

const double kPanelRadius = 28.0;

class _LedBorderPainter extends CustomPainter {
  final double t;
  final Color color;
  final double radius;
  _LedBorderPainter({required this.t, required this.color, required this.radius});

  void _seg(Canvas c, PathMetric m, double a, double b, Paint p) {
    final len = m.length;
    if (b <= 0) {
      c.drawPath(m.extractPath(a + len, b + len), p);
    } else if (a < 0) {
      c.drawPath(m.extractPath(a + len, len), p);
      c.drawPath(m.extractPath(0, b), p);
    } else {
      c.drawPath(m.extractPath(a, b), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 4 || size.height < 4) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.8), Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withOpacity(0.24),
    );

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final m = metrics.first;
    final len = m.length;

    const heads = 2;
    const steps = 9;
    final tail = len * 0.17;

    for (int h = 0; h < heads; h++) {
      final headPos = ((t + h / heads) % 1.0) * len;
      for (int i = 0; i < steps; i++) {
        final a = headPos - tail * (i + 1) / steps;
        final b = headPos - tail * i / steps;
        final k = 1.0 - i / steps;
        final core = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.2
          ..color = Color.lerp(color, Colors.white, 0.55 * k * k)!.withOpacity(0.25 + 0.75 * k);
        if (i < 4) {
          final glow = Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 6.5
            ..color = color.withOpacity(0.16 * k);
          _seg(canvas, m, a, b, glow);
        }
        _seg(canvas, m, a, b, core);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LedBorderPainter old) =>
      old.t != t || old.color != color || old.radius != radius;
}

class CyberPanel extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final EdgeInsetsGeometry padding;
  final double opacity;

  final bool animate;
  const CyberPanel({
    Key? key,
    required this.child,
    this.glowColor = CyberColors.rog,
    this.padding = const EdgeInsets.all(14),
    this.opacity = 0.55,
    this.animate = false,
  }) : super(key: key);

  @override
  State<CyberPanel> createState() => _CyberPanelState();
}

class _CyberPanelState extends State<CyberPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animate ? 3200 : 4600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = min(1.0, widget.opacity + 0.35);

    final body = Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CyberColors.panelLight.withOpacity(a),
            CyberColors.glass.withOpacity(a),
          ],
        ),
        borderRadius: BorderRadius.circular(kPanelRadius),
        boxShadow: [
          BoxShadow(color: widget.glowColor.withOpacity(0.10), blurRadius: 22, spreadRadius: -6),
          const BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: widget.child,
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        child: body,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _LedBorderPainter(
              t: _ctrl.value,
              color: widget.glowColor,
              radius: kPanelRadius,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _LedLinePainter extends CustomPainter {
  final Animation<double> anim;
  final Color color;
  _LedLinePainter({required this.anim, required this.color}) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    if (w <= 0) return;
    final cy = size.height / 2;
    canvas.drawLine(
      Offset(0, cy),
      Offset(w, cy),
      Paint()
        ..color = color.withOpacity(0.16)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
    const gap = 9.0;
    final n = (w / gap).floor();
    if (n < 2) return;
    final head = anim.value * (n + 1);
    for (int i = 0; i <= n; i++) {
      final x = i * gap + (w - n * gap) / 2;
      final d = (head - i) % (n + 1);
      final k = max(0.0, 1.0 - d / 8.0);
      canvas.drawCircle(Offset(x, cy), 1.1, Paint()..color = color.withOpacity(0.28));
      if (k > 0) {
        canvas.drawCircle(Offset(x, cy), 2.0 + 3.0 * k, Paint()..color = color.withOpacity(0.20 * k));
        canvas.drawCircle(
          Offset(x, cy),
          1.5 + 0.9 * k,
          Paint()..color = Color.lerp(color, Colors.white, 0.6 * k)!.withOpacity(0.35 + 0.65 * k),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LedLinePainter old) => old.color != color;
}

class LedLine extends StatefulWidget {
  final Color color;
  final double height;
  final int periodMs;
  const LedLine({Key? key, required this.color, this.height = 10, this.periodMs = 2200})
      : super(key: key);

  @override
  State<LedLine> createState() => _LedLineState();
}

class _LedLineState extends State<LedLine> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: widget.periodMs))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _LedLinePainter(anim: _ctrl, color: widget.color),
      ),
    );
  }
}

const List<Map<String, dynamic>> kLedModeCatalog = [
  {"id": "static", "label": "Warna Diam", "icon": Icons.circle},
  {"id": "rainbow_static", "label": "Pelangi Diam", "icon": Icons.gradient},
  {"id": "rainbow_chase", "label": "Pelangi Jalan", "icon": Icons.arrow_forward},
  {"id": "chase", "label": "Kejar Warna", "icon": Icons.double_arrow},
  {"id": "theater", "label": "Teater", "icon": Icons.view_column},
  {"id": "theater_rainbow", "label": "Teater Pelangi", "icon": Icons.view_column},
  {"id": "breathe", "label": "Bernapas", "icon": Icons.favorite_border},
  {"id": "breathe_rainbow", "label": "Napas Pelangi", "icon": Icons.favorite},
  {"id": "disco", "label": "Disko", "icon": Icons.celebration},
  {"id": "bounce", "label": "Pantul Pelangi", "icon": Icons.swap_horiz},
  {"id": "bounce_solid", "label": "Pantul Warna", "icon": Icons.swap_horiz},
  {"id": "fire", "label": "Api", "icon": Icons.local_fire_department},
  {"id": "comet", "label": "Komet", "icon": Icons.star},
  {"id": "sparkle", "label": "Kerlip", "icon": Icons.auto_awesome},
  {"id": "wave", "label": "Gelombang", "icon": Icons.waves},
  {"id": "colorwipe", "label": "Sapuan Warna", "icon": Icons.brush},
  {"id": "strobe", "label": "Strobo", "icon": Icons.flash_on},
  {"id": "police", "label": "Polisi", "icon": Icons.local_police},
  {"id": "meteor", "label": "Meteor", "icon": Icons.rocket_launch},
  {"id": "gradient", "label": "Gradasi", "icon": Icons.gradient},
];

const List<Map<String, dynamic>> kCustomStyles = [
  {"id": "static", "label": "Diam", "icon": Icons.circle},
  {"id": "chase", "label": "Kejar", "icon": Icons.double_arrow},
  {"id": "theater", "label": "Teater", "icon": Icons.view_column},
  {"id": "breathe", "label": "Bernapas", "icon": Icons.favorite},
  {"id": "comet", "label": "Komet", "icon": Icons.star},
  {"id": "wave", "label": "Gelombang", "icon": Icons.waves},
  {"id": "meteor", "label": "Meteor", "icon": Icons.rocket_launch},
  {"id": "sparkle", "label": "Kerlip", "icon": Icons.auto_awesome},
];

String ledModeLabel(String id) {
  if (id == "off") return "Mati";
  if (id == "custom") return "Custom";
  final found = kLedModeCatalog.firstWhere((m) => m["id"] == id,
      orElse: () => {"label": id});
  return found["label"] as String;
}

IconData ledModeIcon(String id) {
  if (id == "off") return Icons.power_settings_new;
  if (id == "custom") return Icons.palette;
  final found = kLedModeCatalog.firstWhere((m) => m["id"] == id,
      orElse: () => {"icon": Icons.lightbulb});
  return found["icon"] as IconData;
}

class AuraColorWheel extends StatefulWidget {
  final Color initialColor;
  final Color themeColor;
  final double size;
  final ValueChanged<Color> onChanged;
  const AuraColorWheel({
    Key? key,
    required this.initialColor,
    required this.onChanged,
    required this.themeColor,
    this.size = 220,
  }) : super(key: key);

  @override
  State<AuraColorWheel> createState() => _AuraColorWheelState();
}

class _AuraColorWheelState extends State<AuraColorWheel> {
  late double _hue;
  late double _sat;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _sat = hsv.saturation <= 0.15 ? 1.0 : hsv.saturation;
  }

  void _updateFromLocal(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    double deg = atan2(dy, dx) * 180 / pi;
    deg = (deg + 360) % 360;
    setState(() => _hue = deg);
    widget.onChanged(HSVColor.fromAHSV(1, _hue, _sat, 1).toColor());
  }

  @override
  Widget build(BuildContext context) {
    final color = HSVColor.fromAHSV(1, _hue, _sat, 1).toColor();
    final theme = widget.themeColor;
    final knobRadius = widget.size * 0.405;
    return GestureDetector(
      onPanStart: (d) => _updateFromLocal(d.localPosition),
      onPanUpdate: (d) => _updateFromLocal(d.localPosition),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [

            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    for (int i = 0; i <= 12; i++)
                      HSVColor.fromAHSV(1, i * 30.0, 1, 1).toColor(),
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.55), blurRadius: 30, spreadRadius: 1),
                ],
              ),
            ),

            Container(
              width: widget.size * 0.64,
              height: widget.size * 0.64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CyberColors.bgDeep,
                border: Border.all(color: theme.withOpacity(0.85), width: 2),
                boxShadow: [
                  BoxShadow(color: theme.withOpacity(0.35), blurRadius: 18, spreadRadius: -2),
                ],
              ),
            ),

            Vp3dLogo(size: widget.size * 0.22, color: theme),

            Transform.translate(
              offset: Offset(cos(_hue * pi / 180) * knobRadius, sin(_hue * pi / 180) * knobRadius),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: color, width: 3),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.85), blurRadius: 12, spreadRadius: 1)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget cyberSlider({
  required String label,
  required IconData icon,
  required double value,
  required Color color,
  required ValueChanged<double> onChanged,
  ValueChanged<double>? onChangeEnd,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
          Spacer(),
          Text("${value.round()}%",
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: color,
          inactiveTrackColor: Colors.white12,
          thumbColor: Colors.white,
          overlayColor: color.withOpacity(0.2),
          trackHeight: 3,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
        ),
        child: Slider(
          value: value.clamp(0, 100),
          min: 0,
          max: 100,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    ],
  );
}

class CustomLedSheet extends StatefulWidget {
  final Color initialColor;
  final String initialStyle;
  final double initialSpeed;
  final double initialBrightness;
  final bool initialForward;
  final Color accentColor;
  final void Function(Color color, String style, double speed, double brightness, bool forward) onApply;

  const CustomLedSheet({
    Key? key,
    required this.initialColor,
    required this.initialStyle,
    required this.initialSpeed,
    required this.initialBrightness,
    required this.initialForward,
    required this.accentColor,
    required this.onApply,
  }) : super(key: key);

  @override
  State<CustomLedSheet> createState() => _CustomLedSheetState();
}

class _CustomLedSheetState extends State<CustomLedSheet> {
  late Color color;
  late String style;
  late double speed;
  late double brightness;
  late bool forward;

  Color get theme => widget.accentColor;

  @override
  void initState() {
    super.initState();
    color = widget.initialColor;
    style = widget.initialStyle;
    speed = widget.initialSpeed;
    brightness = widget.initialBrightness;
    forward = widget.initialForward;
  }

  Widget _dirChip(String label, IconData icon, bool value) {
    final selected = forward == value;
    return Expanded(
      child: _TapScale(
        onTap: () => setState(() => forward = value),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? theme.withOpacity(0.25) : Colors.black26,
            border: Border.all(color: selected ? theme : Colors.white12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? theme : Colors.white54),
              SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: CyberColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: theme.withOpacity(0.4)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            SizedBox(height: 14),
            Text("MODE CUSTOM",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            SizedBox(height: 4),
            Text("Atur warna, gerakan, arah, kecepatan & kecerahan sendiri",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            SizedBox(height: 18),
            AuraColorWheel(
              initialColor: color,
              themeColor: theme,
              size: 210,
              onChanged: (c) => setState(() => color = c),
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Gaya Gerakan", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCustomStyles.map((s) {
                final id = s["id"] as String;
                final sel = style == id;
                return _TapScale(
                  onTap: () => setState(() => style = id),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? theme.withOpacity(0.25) : Colors.black26,
                      border: Border.all(color: sel ? theme : Colors.white12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s["icon"] as IconData, size: 14, color: sel ? theme : Colors.white54),
                        SizedBox(width: 6),
                        Text(s["label"] as String,
                            style: TextStyle(
                                color: sel ? Colors.white : Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 18),
            Row(children: [
              Icon(Icons.explore, size: 14, color: Colors.white38),
              SizedBox(width: 6),
              Text("Arah Gerakan", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
            SizedBox(height: 8),
            Row(children: [
              _dirChip("Maju", Icons.arrow_forward, true),
              SizedBox(width: 10),
              _dirChip("Mundur", Icons.arrow_back, false),
            ]),
            SizedBox(height: 18),
            cyberSlider(
              label: "Kecepatan",
              icon: Icons.speed,
              value: speed,
              color: theme,
              onChanged: (v) => setState(() => speed = v),
            ),
            SizedBox(height: 6),
            cyberSlider(
              label: "Kecerahan",
              icon: Icons.brightness_6,
              value: brightness,
              color: theme,
              onChanged: (v) => setState(() => brightness = v),
            ),
            SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: _TapScale(
                onTap: () {
                  widget.onApply(color, style, speed, brightness, forward);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme, Color.lerp(theme, Colors.white, 0.25) ?? theme]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: theme.withOpacity(0.5), blurRadius: 16)],
                  ),
                  child: Text("TERAPKAN KE PERANGKAT",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Vp3dLogo extends StatefulWidget {
  final double size;
  final Color color;
  final bool sway;
  const Vp3dLogo({Key? key, this.size = 40, this.color = CyberColors.rog, this.sway = true})
      : super(key: key);

  @override
  State<Vp3dLogo> createState() => _Vp3dLogoState();
}

class _Vp3dLogoState extends State<Vp3dLogo> with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.sway) {
      _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Widget _buildFace() {
    final fs = widget.size * 0.92;
    const layers = 10;
    final step = widget.size * 0.028;
    TextStyle style(Color c, {List<Shadow>? shadows}) => TextStyle(
          fontSize: fs,
          height: 1.0,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -fs * 0.05,
          color: c,
          shadows: shadows,
        );

    final children = <Widget>[];

    for (int i = layers; i >= 1; i--) {
      final f = 1.0 - i / layers;
      final c = Color.lerp(Colors.black, widget.color, 0.30 + 0.45 * f) ?? widget.color;
      children.add(Transform.translate(
        offset: Offset(i * step * 0.55, i * step * 0.85),
        child: Text(
          'VP',
          style: style(c,
              shadows: i == layers
                  ? [Shadow(color: widget.color.withOpacity(0.65), blurRadius: widget.size * 0.35)]
                  : null),
        ),
      ));
    }

    children.add(ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color.lerp(widget.color, Colors.white, 0.35) ?? widget.color],
      ).createShader(r),
      child: Text('VP', style: style(Colors.white)),
    ));

    return SizedBox(
      width: widget.size * 1.35,
      height: widget.size * 1.1,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final face = _buildFace();
    if (_ctrl == null) {
      return RepaintBoundary(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-0.12)
            ..rotateY(-0.25),
          child: face,
        ),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl!,
        child: face,
        builder: (context, child) {
          final angle = (_ctrl!.value - 0.5) * 0.7;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(-0.12)
              ..rotateY(angle),
            child: child,
          );
        },
      ),
    );
  }
}

class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color glowColor;
  final double pressedScale;
  const _TapScale({
    Key? key,
    required this.child,
    this.onTap,
    this.glowColor = CyberColors.rog,
    this.pressedScale = 0.965,
  }) : super(key: key);

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  double _scale = 1.0;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;
    setState(() {
      _pressed = value;
      _scale = value ? widget.pressedScale : 1.0;
    });
  }

  void _handleTap() {
    _setPressed(false);
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: widget.glowColor.withOpacity(0.28),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const _Reveal({
    Key? key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 560),
  }) : super(key: key);

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: Transform.scale(
              scale: 0.98 + (0.02 * t),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _SplashParticle {
  final double x;
  final double speed;
  final double size;
  final double phase;
  final double drift;
  final bool magenta;

  _SplashParticle({
    required this.x,
    required this.speed,
    required this.size,
    required this.phase,
    required this.drift,
    required this.magenta,
  });
}

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {

  late final AnimationController _mainCtrl;

  late final AnimationController _loopCtrl;
  late final List<_SplashParticle> _particles;

  @override
  void initState() {
    super.initState();

    final rnd = Random(7);
    _particles = List.generate(56, (i) {
      return _SplashParticle(
        x: rnd.nextDouble(),
        speed: 0.35 + rnd.nextDouble() * 0.9,
        size: 1.2 + rnd.nextDouble() * 2.6,
        phase: rnd.nextDouble(),
        drift: rnd.nextDouble() * 18 - 9,
        magenta: rnd.nextBool(),
      );
    });

    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    _loopCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))..repeat();

    _mainCtrl.forward();
    _mainCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), _goToApp);
      }
    });
  }

  void _goToApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, anim, __) => ControllerPage(),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 1.06, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _loopCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color neon = gSavedAccent != null ? Color(gSavedAccent!) : CyberColors.rog;
    const Color neon2 = CyberColors.ember;

    return Scaffold(
      backgroundColor: CyberColors.bgDeep,
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainCtrl, _loopCtrl]),
        builder: (context, _) {
          final t = _mainCtrl.value.clamp(0.0, 1.0);
          final loop = _loopCtrl.value;

          double stage(double begin, double end, {Curve curve = Curves.linear}) {
            return curve.transform(Interval(begin, end, curve: Curves.linear).transform(t)).clamp(0.0, 1.0);
          }

          final ringIntro = stage(0.0, 0.45, curve: Curves.easeOutExpo);
          final logoScale = stage(0.05, 0.55, curve: Curves.elasticOut);
          final logoFade = stage(0.0, 0.30);
          final titleT = stage(0.35, 0.70, curve: Curves.easeOutCubic);
          final subtitleT = stage(0.50, 0.80, curve: Curves.easeOutCubic);
          final barT = stage(0.05, 0.97, curve: Curves.easeInOutSine);
          final flashT = stage(0.94, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              CyberBackdrop(gridScroll: loop, scanT: loop, color: neon),

              CustomPaint(
                painter: _SplashParticlePainter(particles: _particles, loop: loop, colorA: neon, colorB: neon2),
                size: Size.infinite,
              ),

              Center(
                child: CustomPaint(
                  painter: _RingPainter(loopValue: loop, intro: ringIntro, color: neon),
                  size: const Size(320, 320),
                ),
              ),

              Center(
                child: Transform.rotate(
                  angle: loop * 2 * pi,
                  child: Opacity(
                    opacity: (0.30 * ringIntro).clamp(0.0, 0.30),
                    child: CustomPaint(
                      painter: _HexPainter(color: neon2),
                      size: const Size(210, 210),
                    ),
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: logoFade,
                      child: Transform.scale(
                        scale: 0.4 + 0.6 * logoScale,
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [neon.withOpacity(0.9), neon2.withOpacity(0.75)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: neon.withOpacity(0.5 + 0.25 * sin(loop * 2 * pi).abs()),
                                blurRadius: 46,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: neon2.withOpacity(0.25),
                                blurRadius: 60,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Vp3dLogo(size: 60, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Opacity(
                      opacity: titleT,
                      child: Transform.translate(
                        offset: Offset(0, (1 - titleT) * 18),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: const Offset(-1.4, 0),
                              child: Text(
                                'COOLER CONTROLLER',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  color: neon2.withOpacity(0.45),
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(1.4, 0),
                              child: Text(
                                'COOLER CONTROLLER',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  color: neon.withOpacity(0.45),
                                ),
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) {
                                final sweep = (loop * 2.4) % 2.4 - 0.7;
                                return LinearGradient(
                                  colors: const [Colors.white, Color(0xFFFFC2CB), Colors.white],
                                  stops: [
                                    (sweep - 0.25).clamp(0.0, 1.0),
                                    sweep.clamp(0.0, 1.0),
                                    (sweep + 0.25).clamp(0.0, 1.0),
                                  ],
                                ).createShader(bounds);
                              },
                              child: const Text(
                                'COOLER CONTROLLER',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: subtitleT,
                      child: Text(
                        'GAMING COOLER ENGINE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 4,
                          color: neon.withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Opacity(
                      opacity: barT > 0 ? 1 : 0,
                      child: Column(
                        children: [
                          Container(
                            width: 190,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: barT,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(colors: [neon, neon2]),
                                    boxShadow: [BoxShadow(color: neon.withOpacity(0.7), blurRadius: 8)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'BOOTING ${(barT * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 26,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: subtitleT,
                  child: Center(
                    child: Text(
                      'v$kAppVersion',
                      style: const TextStyle(color: Colors.white30, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                ),
              ),

              if (flashT > 0)
                IgnorePointer(
                  child: Opacity(
                    opacity: (flashT * 0.85).clamp(0.0, 0.85),
                    child: Container(color: Colors.white),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashParticlePainter extends CustomPainter {
  final List<_SplashParticle> particles;
  final double loop;
  final Color colorA;
  final Color colorB;
  _SplashParticlePainter({required this.particles, required this.loop, required this.colorA, required this.colorB});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final progress = (loop + p.phase) % 1.0;
      final y = size.height * (1 - progress);
      final x = p.x * size.width + sin((progress + p.phase) * 2 * pi) * p.drift;
      final opacity = sin(progress * pi).clamp(0.0, 1.0);
      paint.color = (p.magenta ? colorB : colorA).withOpacity(0.55 * opacity);
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashParticlePainter oldDelegate) => true;
}

class _RingPainter extends CustomPainter {
  final double loopValue;
  final double intro;
  final Color color;
  _RingPainter({required this.loopValue, required this.intro, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    for (int i = 0; i < 3; i++) {
      final progress = (loopValue + i / 3) % 1.0;
      final radius = maxRadius * progress * intro;
      final opacity = ((1 - progress) * 0.5 * intro).clamp(0.0, 0.5);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => true;
}

class _HexPainter extends CustomPainter {
  final Color color;
  _HexPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 2;
      final point = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexPainter oldDelegate) => false;
}

class ControllerPage extends StatefulWidget {
  @override
  _ControllerPageState createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> with TickerProviderStateMixin {

  List<Cooler> pairedCoolers = [];
  Cooler? activeCooler;

  String get connectionMode => activeCooler?.mode ?? "WiFi";

  Color accentColor = gSavedAccent != null ? Color(gSavedAccent!) : CyberColors.rog;
  final List<Color> colorPalette = [
    CyberColors.rog,
    CyberColors.ember,
    CyberColors.cyan,
    CyberColors.magenta,
    CyberColors.violet,
    CyberColors.success,
    CyberColors.amber,
    CyberColors.danger,
    Colors.blueAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
    Colors.orangeAccent,
  ];

  late final AnimationController _bgCtrl;
  late final AnimationController _pulseCtrl;

  MqttServerClient? mqttClient;
  final String broker = "broker.emqx.io";

  String get cmdTopic => "cooler/${activeCooler?.id}/command";
  String get statusTopic => "cooler/${activeCooler?.id}/status";

  BluetoothDevice? bleDevice;
  bool isScanning = false;
  List<ScanResult> scanResults = [];
  bool bleConnected = false;

  double setVolt = 5.0;
  String ledMode = "off";
  String lastLedEffect = "rainbow_chase";
  double ledSpeed = 50;
  double ledBrightness = 80;
  bool ledForward = true;
  String customStyle = "chase";
  Color ledCustomColor = CyberColors.cyan;
  String uptime = "00:00:00";
  String status = "🔴 Offline";

  List<Map<String, dynamic>> wifiList = [];
  bool isScanningWifi = false;
  String selectedSSID = "";
  TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _initApp();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveAccent(Color c) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kAccentPrefKey, c.value);
      gSavedAccent = c.value;
    } catch (_) {}
  }

  Future<void> _initApp() async {

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    await _loadPairedCoolers();

    if (activeCooler != null) {
      _connectActiveCooler();
    }
  }

  Future<void> _loadPairedCoolers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('paired_coolers');
    final lastActiveId = prefs.getString('active_cooler_id');
    if (raw != null) {
      List<dynamic> list = jsonDecode(raw);
      setState(() {
        pairedCoolers = list.map((e) => Cooler.fromJson(e)).toList();
        if (pairedCoolers.isNotEmpty) {
          activeCooler = pairedCoolers.firstWhere(
            (c) => c.id == lastActiveId,
            orElse: () => pairedCoolers.first,
          );
        }
      });
    }
  }

  Future<void> _savePairedCoolers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'paired_coolers', jsonEncode(pairedCoolers.map((c) => c.toJson()).toList()));
    if (activeCooler != null) {
      await prefs.setString('active_cooler_id', activeCooler!.id);
    }
  }

  void _connectActiveCooler() {
    if (activeCooler == null) return;
    if (activeCooler!.mode == "WiFi") {
      connectMQTT();
    } else {
      _connectBleById(activeCooler!.bleRemoteId);
    }
  }

  Future<void> _connectBleById(String? remoteId) async {
    if (remoteId == null) return;
    try {
      final device = BluetoothDevice.fromId(remoteId);
      await connectBLE(device);
    } catch (e) {
      _showSnack("⚠️ Gagal konek ulang ke ${activeCooler?.nickname}, coba scan ulang");
    }
  }

  void switchActiveCooler(Cooler cooler) {

    if (activeCooler?.mode == "Bluetooth" && bleDevice != null) {
      bleDevice!.disconnect();
    }
    if (activeCooler?.mode == "WiFi" && _mqttConnected) {
      mqttClient?.disconnect();
    }
    setState(() {
      activeCooler = cooler;
      status = "🔴 Offline";
      bleConnected = false;
    });
    _savePairedCoolers();
    _connectActiveCooler();
  }

  void removeCooler(Cooler cooler) {
    setState(() {
      pairedCoolers.removeWhere((c) => c.id == cooler.id);
      if (activeCooler?.id == cooler.id) {
        activeCooler = pairedCoolers.isNotEmpty ? pairedCoolers.first : null;
        status = "🔴 Offline";
      }
    });
    _savePairedCoolers();
    if (activeCooler != null) _connectActiveCooler();
  }

  void addCooler(Cooler cooler) {
    setState(() {
      pairedCoolers.removeWhere((c) => c.id == cooler.id);
      pairedCoolers.add(cooler);
      activeCooler = cooler;
      status = "🔴 Offline";
    });
    _savePairedCoolers();
    _connectActiveCooler();
  }

  void connectMQTT() async {
    if (activeCooler == null) {
      _showSnack("⚠️ Pilih atau tambah cooler dulu");
      return;
    }

    final clientId = 'flutter_${activeCooler!.id}_${DateTime.now().millisecondsSinceEpoch}';
    mqttClient = MqttServerClient(broker, clientId);
    mqttClient!.port = 1883;
    mqttClient!.keepAlivePeriod = 20;
    mqttClient!.onConnected = () {
      setState(() => status = "🟢 Online");
      mqttClient!.subscribe(statusTopic, MqttQos.atLeastOnce);
    };
    mqttClient!.onDisconnected = () => setState(() => status = "🔴 Offline");
    mqttClient!.updates!.listen((msgs) {
      final msg = msgs[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
      try {
        var data = jsonDecode(payload);

        if (data['deviceId'] != null && data['deviceId'] != activeCooler?.id) return;
        setState(() {
          setVolt = (data['setVoltage'] ?? setVolt).toDouble();
          uptime = data['uptime'] ?? "00:00:00";
          _applyIncomingLedState(data);
        });
      } catch (e) {}
    });
    try {
      await mqttClient!.connect();
    } catch (e) {
      setState(() => status = "🔴 Offline");
    }
  }

  bool get _mqttConnected =>
      mqttClient != null &&
      mqttClient!.connectionStatus!.state == MqttConnectionState.connected;

  void sendCommandMQTT(double volt) async {
    if (!_mqttConnected) {
      setState(() => status = "🔴 Offline");
      _showSnack("⚠️ Tidak terhubung ke broker MQTT");
      return;
    }
    var builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode({"voltage": volt}));
    mqttClient!.publishMessage(cmdTopic, MqttQos.atLeastOnce, builder.payload!);
    setState(() {
      setVolt = volt;
    });
  }

  void sendLedCommandMQTT(Map<String, dynamic> payload) async {
    if (!_mqttConnected) {
      setState(() => status = "🔴 Offline");
      _showSnack("⚠️ Tidak terhubung ke broker MQTT");
      return;
    }
    var builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    mqttClient!.publishMessage(cmdTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  void scanBLE() async {
    setState(() {
      isScanning = true;
      scanResults.clear();
    });
    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
    FlutterBluePlus.onScanResults.listen((results) {
      setState(() {

        scanResults =
            results.where((r) => r.device.name.contains("ESP32-Cooler-")).toList();
      });
    });
    await Future.delayed(Duration(seconds: 6));
    setState(() {
      isScanning = false;
    });
  }

  String extractDeviceId(String bleName) {
    final parts = bleName.split("ESP32-Cooler-");
    return parts.length > 1 ? parts[1].trim() : bleName;
  }

  Future<void> connectBLE(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        bleDevice = device;
        bleConnected = true;
        status = "🟢 Online";
      });
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              String payload = utf8.decode(value);
              try {
                var data = jsonDecode(payload);
                if (data['deviceId'] != null && data['deviceId'] != activeCooler?.id) return;
                setState(() {
                  setVolt = (data['setVoltage'] ?? setVolt).toDouble();
                  uptime = data['uptime'] ?? "00:00:00";
                  _applyIncomingLedState(data);
                });
              } catch (e) {}
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        bleConnected = false;
        status = "🔴 Offline";
      });
    }
  }

  void sendCommandBLE(double volt) async {
    if (!bleConnected || bleDevice == null) {
      setState(() => status = "🔴 Offline");
      _showSnack("⚠️ Belum terhubung ke perangkat Bluetooth");
      return;
    }
    try {
      List<BluetoothService> services = await bleDevice!.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
            await characteristic.write(utf8.encode(jsonEncode({"voltage": volt})));
            setState(() {
              setVolt = volt;
            });
            return;
          }
        }
      }
    } catch (e) {
      _showSnack("❌ Gagal mengirim perintah ke perangkat");
    }
  }

  void sendLedCommandBLE(Map<String, dynamic> payload) async {
    if (!bleConnected || bleDevice == null) {
      setState(() => status = "🔴 Offline");
      _showSnack("⚠️ Belum terhubung ke perangkat Bluetooth");
      return;
    }
    try {
      List<BluetoothService> services = await bleDevice!.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
            await characteristic.write(utf8.encode(jsonEncode(payload)));
            return;
          }
        }
      }
    } catch (e) {
      _showSnack("❌ Gagal mengirim perintah ke perangkat");
    }
  }

  void sendLed(String mode, {double? speed, double? brightness, Color? color, bool? forward, String? style}) {
    if (activeCooler == null) {
      _showSnack("⚠️ Pilih atau tambah cooler dulu");
      return;
    }
    final sp = speed ?? ledSpeed;
    final br = brightness ?? ledBrightness;
    final col = color ?? ledCustomColor;
    final fwd = forward ?? ledForward;
    final st = style ?? customStyle;

    if (mode != "off") lastLedEffect = mode;

    final hex = col.value.toRadixString(16).padLeft(8, '0').substring(2);
    final payload = <String, dynamic>{
      "ledMode": mode,
      "speed": sp.round(),
      "brightness": br.round(),
      "color": "#$hex",
      "direction": fwd ? 1 : -1,
      if (mode == "custom") "customStyle": st,
    };

    setState(() {
      ledMode = mode;
      ledSpeed = sp;
      ledBrightness = br;
      ledCustomColor = col;
      ledForward = fwd;
      customStyle = st;
    });

    if (connectionMode == "WiFi") {
      sendLedCommandMQTT(payload);
    } else {
      sendLedCommandBLE(payload);
    }
  }

  void _applyIncomingLedState(Map data) {
    ledMode = data['ledMode'] ?? ledMode;
    if (data['speed'] != null) ledSpeed = (data['speed'] as num).toDouble();
    if (data['brightness'] != null) ledBrightness = (data['brightness'] as num).toDouble();
    if (data['direction'] != null) ledForward = (data['direction'] as num) >= 0;
    if (data['customStyle'] != null) customStyle = data['customStyle'];
    if (data['color'] != null) {
      try {
        final hex = (data['color'] as String).replaceAll('#', '');
        ledCustomColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    if (ledMode != "off") lastLedEffect = ledMode;
  }

  void sendVoltage(double volt) {
    if (activeCooler == null) {
      _showSnack("⚠️ Pilih atau tambah cooler dulu");
      return;
    }
    volt = double.parse(volt.toStringAsFixed(1));
    if (connectionMode == "WiFi") {
      sendCommandMQTT(volt);
    } else {
      sendCommandBLE(volt);
    }
  }

  Future<void> scanWiFi() async {
    setState(() {
      isScanningWifi = true;
      wifiList.clear();
    });
    try {
      var response =
          await http.get(Uri.parse("http://192.168.4.1/scanwifi")).timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        if (response.body.contains("scanning")) {
          await Future.delayed(Duration(seconds: 3));
          await scanWiFi();
          return;
        }
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          wifiList = data.map((e) => {"ssid": e['ssid'], "rssi": e['rssi']}).toList();
          isScanningWifi = false;
        });
      }
    } catch (e) {
      setState(() {
        isScanningWifi = false;
      });
      _showSnack("⚠️ Pastikan HP terhubung ke ESP32-Config");
    }
  }

  Future<void> connectWiFi(String ssid, String password) async {
    try {

      var url = Uri.http("192.168.4.1", "/setwifi", {"ssid": ssid, "password": password});
      var response = await http.get(url);
      if (response.statusCode == 200) {
        _showSnack("✅ ESP32 berhasil terhubung ke $ssid");
        Navigator.pop(context);
        await Future.delayed(Duration(seconds: 5));
        connectMQTT();
      } else {
        _showSnack("❌ Gagal terhubung, coba lagi");
      }
    } catch (e) {
      _showSnack("⚠️ Pastikan HP terhubung ke ESP32-Config");
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: CyberColors.panelLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withOpacity(0.4)),
      ),
      content: Text(text, style: const TextStyle(color: Colors.white)),
    ));
  }

  void clearAppCache() {
    setState(() {
      wifiList.clear();
      scanResults.clear();
      selectedSSID = "";
      passwordController.clear();
    });
    Navigator.of(context, rootNavigator: true).pop();
    _showSnack("🧹 Cache aplikasi berhasil dibersihkan");
  }

  void clearEsp32Cache() {
    if (connectionMode == "WiFi") {
      if (_mqttConnected) {
        var builder = MqttClientPayloadBuilder();
        builder.addString(jsonEncode({"action": "clear_cache"}));
        mqttClient!.publishMessage(cmdTopic, MqttQos.atLeastOnce, builder.payload!);
        _showSnack("🧹 Perintah bersihkan cache modul ESP32 terkirim");
      } else {
        _showSnack("⚠️ Tidak terhubung ke ESP32, cache tidak bisa dibersihkan");
      }
    } else {
      if (bleConnected) {
        sendBLERaw({"action": "clear_cache"});
        _showSnack("🧹 Perintah bersihkan cache modul ESP32 terkirim");
      } else {
        _showSnack("⚠️ Tidak terhubung ke ESP32, cache tidak bisa dibersihkan");
      }
    }
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> sendBLERaw(Map<String, dynamic> payload) async {
    if (!bleConnected || bleDevice == null) return;
    try {
      List<BluetoothService> services = await bleDevice!.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
            await characteristic.write(utf8.encode(jsonEncode(payload)));
            return;
          }
        }
      }
    } catch (e) {}
  }

  void showWiFiSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            backgroundColor: CyberColors.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: accentColor.withOpacity(0.4)),
            ),
            title: Row(
              children: [
                Icon(Icons.wifi, color: accentColor),
                SizedBox(width: 8),
                Expanded(
                    child: Text("Hubungkan Internet ESP32",
                        style: TextStyle(color: Colors.white, fontSize: 16))),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text("📶 WiFi di sekitar",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70)),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: accentColor),
                        onPressed: () => scanWiFi(),
                      ),
                    ],
                  ),
                  Expanded(
                    child: isScanningWifi
                        ? Center(child: CircularProgressIndicator(color: accentColor))
                        : wifiList.isEmpty
                            ? Center(
                                child: Text(
                                    "Tidak ada WiFi ditemukan\nPastikan HP terhubung ke ESP32-Config",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white54)))
                            : ListView.builder(
                                itemCount: wifiList.length,
                                itemBuilder: (ctx, index) {
                                  var wifi = wifiList[index];
                                  bool isSelected = selectedSSID == wifi['ssid'];
                                  return Card(
                                    color: isSelected ? accentColor.withOpacity(0.15) : CyberColors.panelLight,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: isSelected ? accentColor : Colors.transparent, width: 1.4),
                                    ),
                                    child: ListTile(
                                      leading: Icon(Icons.wifi, color: accentColor),
                                      title: Text(wifi['ssid'], style: TextStyle(color: Colors.white)),
                                      trailing:
                                          Text("${wifi['rssi']}dBm", style: TextStyle(color: Colors.grey)),
                                      onTap: () {
                                        setStateDialog(() {
                                          selectedSSID = wifi['ssid'];
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                  if (selectedSSID.isNotEmpty) ...[
                    Divider(color: Colors.white24),
                    TextField(
                      controller: passwordController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Password WiFi",
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: accentColor)),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (passwordController.text.isNotEmpty) {
                            connectWiFi(selectedSSID, passwordController.text);
                          } else {
                            _showSnack("Masukkan password!");
                          }
                        },
                        child: Text("🔗 Hubungkan"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Tutup", style: TextStyle(color: accentColor)),
              ),
            ],
          );
        },
      ),
    );
  }

  void showAboutChangelogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: accentColor.withOpacity(0.4)),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: accentColor),
            SizedBox(width: 8),
            Text("About", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: DefaultTextStyle(
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Cooler Controller App",
                    style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Version: $kAppVersion"),
                Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LedLine(color: accentColor)),
                Text("Developer", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Nama: Apri Ansyah"),
                Text("Telegram Dev: t.me/bujanginm"),
                Text("Group Telegram:"),
                Text("https://t.me/forumdiskusitele/371474"),
                Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LedLine(color: accentColor)),
                Text("Tujuan Aplikasi", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                    "Aplikasi ini dibuat hanya untuk tujuan edukasi/pembelajaran, mengenai cara kerja fan cooler apabila dikontrol menggunakan aplikasi."),
                Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LedLine(color: accentColor)),
                Text("Cara Penggunaan (Dari Awal sampai Selesai)",
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text("A. Persiapan Awal",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 2),
                Text(
                    "1. Pastikan modul ESP32-C3 sudah terpasang & menyala (lampu indikator hidup).\n"
                    "2. Buka aplikasi ini, lalu izinkan permission Bluetooth & Lokasi saat diminta (wajib supaya fitur scan Bluetooth berfungsi)."),
                SizedBox(height: 8),
                Text("B. Menghubungkan ESP32 ke WiFi Rumah (sekali saja)",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 2),
                Text(
                    "3. Kalau ESP32 belum pernah disetel WiFi, dia otomatis memancarkan hotspot bernama \"ESP32-Config\" (password: 12345678). Sambungkan WiFi HP ke hotspot itu dulu.\n"
                    "4. Di aplikasi, buka menu ☰ (kanan atas / drawer) → \"Setup WiFi ESP32\".\n"
                    "5. Tekan ikon refresh untuk scan WiFi sekitar, pilih nama WiFi rumah dari daftar, masukkan passwordnya, lalu tekan \"🔗 Hubungkan\".\n"
                    "6. Tunggu notifikasi berhasil terhubung. ESP32 akan restart & tersambung ke WiFi rumah, status akan berubah jadi \"🟢 Online\"."),
                SizedBox(height: 8),
                Text("C. Menambahkan Cooler ke Aplikasi",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 2),
                Text(
                    "7. Buka menu ☰ → \"Tambah Cooler Baru\".\n"
                    "8. Isi nama cooler (bebas, mis. \"Cooler Kamar\").\n"
                    "9. Pilih salah satu cara pairing:\n"
                    "   • Scan Bluetooth: tunggu daftar perangkat muncul, ketuk perangkat yang sesuai.\n"
                    "   • Manual (WiFi): masukkan ID Perangkat (dilihat di layar Setup WiFi ESP32 / serial monitor), lalu tekan \"Tambah\".\n"
                    "10. Cooler yang baru ditambahkan otomatis jadi cooler aktif (bisa dicek/diganti lewat menu ☰)."),
                SizedBox(height: 8),
                Text("D. Mengatur Voltase Kipas",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 2),
                Text(
                    "11. Pastikan status di atas menunjukkan \"🟢 Online\" (cooler sudah terhubung).\n"
                    "12. Di halaman utama, pilih salah satu preset tegangan: 5V / 9V / 12V / 15V.\n"
                    "13. Tekan tombol \"Pilih\" pada preset yang diinginkan — tombol akan berubah jadi \"Terpilih\" dan kipas akan menyesuaikan tegangan.\n"
                    "14. Selesai — kipas kini berjalan sesuai voltase yang dipilih."),
                SizedBox(height: 8),
                Text("E. Fitur Tambahan (opsional)",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 2),
                Text(
                    "• Ganti warna tema aplikasi lewat menu ☰ → \"Tampilan\".\n"
                    "• \"Bersihkan Cache Aplikasi\" untuk menghapus data scan WiFi/Bluetooth sementara.\n"
                    "• \"Bersihkan Cache Modul ESP32\" untuk kirim perintah reset cache ke ESP32.\n"
                    "• Bisa menambahkan & berpindah antar beberapa cooler lewat menu ☰."),
                Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LedLine(color: accentColor)),
                Text("Status", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Aplikasi ini FREE dan TIDAK untuk diperjualbelikan."),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Tutup", style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }

  void _confirmClear(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: accentColor.withOpacity(0.4)),
        ),
        title: Text(title, style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Batal", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.black),
            child: Text("Ya, Bersihkan"),
          ),
        ],
      ),
    );
  }

  void showAddCoolerDialog() {
    final nicknameController = TextEditingController();
    final manualIdController = TextEditingController();
    int tab = 0;
    scanBLE();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: CyberColors.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: accentColor.withOpacity(0.4)),
            ),
            title: Text("Tambah Cooler Baru", style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nicknameController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Nama cooler (mis. Cooler Kamar)",
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            shape: StadiumBorder(),
                            label: Text("Scan Bluetooth"),
                            selected: tab == 0,
                            selectedColor: accentColor.withOpacity(0.3),
                            onSelected: (_) => setDialogState(() => tab = 0),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            shape: StadiumBorder(),
                            label: Text("Manual (WiFi)"),
                            selected: tab == 1,
                            selectedColor: accentColor.withOpacity(0.3),
                            onSelected: (_) => setDialogState(() => tab = 1),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    if (tab == 0) ...[
                      if (isScanning)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
                            SizedBox(width: 10),
                            Text("Mencari cooler di sekitar...", style: TextStyle(color: Colors.white54)),
                          ]),
                        ),
                      if (!isScanning && scanResults.isEmpty)
                        Text("Tidak ada cooler ditemukan. Pastikan Bluetooth aktif & cooler menyala.",
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ...scanResults.map((r) {
                        final id = extractDeviceId(r.device.name);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.bluetooth, color: accentColor),
                          title: Text(r.device.name, style: TextStyle(color: Colors.white)),
                          subtitle: Text("ID: $id", style: TextStyle(color: Colors.white38, fontSize: 11)),
                          onTap: () async {
                            String nickname =
                                nicknameController.text.trim().isEmpty ? r.device.name : nicknameController.text.trim();
                            Navigator.pop(ctx);
                            final cooler = Cooler(
                                id: id, nickname: nickname, mode: "Bluetooth", bleRemoteId: r.device.remoteId.str);
                            addCooler(cooler);
                            await connectBLE(r.device);
                          },
                        );
                      }).toList(),
                      TextButton.icon(
                        onPressed: () => setDialogState(() => scanBLE()),
                        icon: Icon(Icons.refresh, color: accentColor, size: 18),
                        label: Text("Scan ulang", style: TextStyle(color: accentColor)),
                      ),
                    ] else ...[
                      Text(
                        "Buka menu \"Setup WiFi ESP32\" atau layar konfigurasi cooler (192.168.4.1) untuk melihat ID Perangkat-nya, lalu masukkan di sini.",
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: manualIdController,
                        style: TextStyle(color: Colors.white, letterSpacing: 2),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: "ID Perangkat (mis. A1B2C3)",
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white24)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Batal", style: TextStyle(color: Colors.white54)),
              ),
              if (tab == 1)
                TextButton(
                  onPressed: () {
                    final id = manualIdController.text.trim().toUpperCase();
                    if (id.isEmpty) {
                      _showSnack("Masukkan ID Perangkat dulu!");
                      return;
                    }
                    String nickname =
                        nicknameController.text.trim().isEmpty ? "Cooler $id" : nicknameController.text.trim();
                    Navigator.pop(ctx);
                    addCooler(Cooler(id: id, nickname: nickname, mode: "WiFi"));
                  },
                  child: Text("Tambah", style: TextStyle(color: accentColor)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: CyberColors.bgDeep,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 28, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [CyberColors.panel, CyberColors.bgDeep],
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
                border: Border.all(color: accentColor.withOpacity(0.35), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Vp3dLogo(size: 48, color: accentColor),
                  SizedBox(height: 14),
                  Text("COOLER CONTROLLER",
                      style: TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: status == "🟢 Online" ? CyberColors.success : CyberColors.danger,
                          boxShadow: [
                            BoxShadow(
                                color: (status == "🟢 Online" ? CyberColors.success : CyberColors.danger)
                                    .withOpacity(0.7),
                                blurRadius: 6)
                          ],
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                          activeCooler != null
                              ? "${activeCooler!.nickname} • ${status.replaceAll(RegExp(r'[🟢🔴]\s*'), '')}"
                              : status.replaceAll(RegExp(r'[🟢🔴]\s*'), ''),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: status == "🟢 Online" ? CyberColors.success : CyberColors.danger)),
                    ],
                  ),
                ],
              ),
            ),
            ...pairedCoolers.map((cooler) {
              bool selected = activeCooler?.id == cooler.id;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? accentColor.withOpacity(0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: selected ? accentColor.withOpacity(0.7) : Colors.transparent, width: 1.2),
                ),
                child: ListTile(
                  leading: Icon(cooler.mode == "WiFi" ? Icons.wifi : Icons.bluetooth,
                      color: selected ? accentColor : Colors.white70),
                  title: Text(cooler.nickname,
                      style: TextStyle(
                          color: Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text("ID: ${cooler.id} • ${cooler.mode}",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) Icon(Icons.check_circle, color: accentColor, size: 20),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                        onPressed: () {
                          Navigator.pop(context);
                          removeCooler(cooler);
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (!selected) switchActiveCooler(cooler);
                  },
                ),
              );
            }).toList(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(Icons.add),
                  label: Text("Tambah Cooler Baru"),
                  onPressed: () {
                    Navigator.pop(context);
                    showAddCoolerDialog();
                  },
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.settings_ethernet, color: Colors.white70),
              title: Text("Setup WiFi ESP32", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                showWiFiSetupDialog();
              },
            ),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: LedLine(color: accentColor)),
            _drawerSectionTitle("Tampilan"),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: colorPalette.map((c) {
                  bool selected = accentColor.value == c.value;
                  return GestureDetector(
                    onTap: () {
                      setState(() => accentColor = c);
                      _saveAccent(c);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
                        boxShadow: selected
                            ? [BoxShadow(color: c.withOpacity(0.7), blurRadius: 12, spreadRadius: 1)]
                            : [],
                      ),
                      child: selected ? Icon(Icons.check, size: 16, color: Colors.black) : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: LedLine(color: accentColor)),
            _drawerSectionTitle("Perawatan"),
            ListTile(
              leading: Icon(Icons.cleaning_services, color: Colors.white70),
              title: Text("Bersihkan Cache Aplikasi", style: TextStyle(color: Colors.white)),
              subtitle: Text("Hapus data sementara di aplikasi", style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () => _confirmClear(
                  "Bersihkan Cache Aplikasi",
                  "Data pencarian WiFi/Bluetooth sementara akan dihapus. Lanjutkan?",
                  clearAppCache),
            ),
            ListTile(
              leading: Icon(Icons.memory, color: Colors.white70),
              title: Text("Bersihkan Cache Modul ESP32", style: TextStyle(color: Colors.white)),
              subtitle:
                  Text("Kirim perintah reset cache ke modul ESP32", style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () => _confirmClear(
                  "Bersihkan Cache Modul ESP32",
                  "Perintah pembersihan cache akan dikirim ke modul ESP32 melalui koneksi $connectionMode. Lanjutkan?",
                  clearEsp32Cache),
            ),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: LedLine(color: accentColor)),
            _drawerSectionTitle("Lainnya"),
            ListTile(
              leading: Icon(Icons.info_outline, color: Colors.white70),
              title: Text("Tentang", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                showAboutChangelogDialog(context);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _drawerSectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(text.toUpperCase(),
          style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool online = status == "🟢 Online";
    return Scaffold(
      backgroundColor: CyberColors.bg,
      drawer: _buildDrawer(),
      appBar: _buildAppBar(online),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (context, _) =>
                  CyberBackdrop(gridScroll: _bgCtrl.value, scanT: _bgCtrl.value, color: accentColor),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 380;
                double maxWidth = constraints.maxWidth > 520 ? 500 : constraints.maxWidth;
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: 14),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Reveal(
                            delay: const Duration(milliseconds: 40),
                            child: _modeBanner(),
                          ),
                          SizedBox(height: 16),
                          _Reveal(
                            delay: const Duration(milliseconds: 100),
                            child: _timerCard(),
                          ),
                          SizedBox(height: 16),
                          _Reveal(
                            delay: const Duration(milliseconds: 160),
                            child: _voltageDisplayCard(online),
                          ),
                          SizedBox(height: 20),
                          _Reveal(
                            delay: const Duration(milliseconds: 220),
                            child: _sectionLabel("KONTROL VOLTASE  //  5V - 15V"),
                          ),
                          SizedBox(height: 10),
                          _Reveal(
                            delay: const Duration(milliseconds: 260),
                            child: _presetList(),
                          ),
                          SizedBox(height: 10),
                          _Reveal(
                            delay: const Duration(milliseconds: 300),
                            child: _ledToggleCard(),
                          ),
                          SizedBox(height: 22),
                          _Reveal(
                            delay: const Duration(milliseconds: 350),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _actionBtn('Refresh', Icons.refresh_rounded, () {
                                    if (activeCooler == null) {
                                      _showSnack("Pilih atau tambah cooler dulu");
                                      return;
                                    }
                                    _connectActiveCooler();
                                  }),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _actionBtn('Setup WiFi', Icons.wifi_rounded, showWiFiSetupDialog),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool online) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leadingWidth: 58,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CyberColors.panel.withOpacity(0.98),
              const Color(0xFF101018).withOpacity(0.94),
              accentColor.withOpacity(0.08),
            ],
          ),
          border: Border(
            bottom: BorderSide(color: accentColor.withOpacity(0.18)),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(8),
        child: LedLine(color: accentColor, height: 10, periodMs: 1800),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Vp3dLogo(size: 31, color: accentColor),
          SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PROJECT V2",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                final glow = online ? _pulseCtrl.value : 0.0;
                final color = online ? CyberColors.success : CyberColors.danger;
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.14), Colors.black26],
                    ),
                    border: Border.all(color: color.withOpacity(0.7)),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: online
                        ? [BoxShadow(color: color.withOpacity(0.25 + 0.25 * glow), blurRadius: 10 + 6 * glow)]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      SizedBox(width: 6),
                      Text(online ? "ONLINE" : "OFFLINE",
                          style: TextStyle(
                              fontSize: 10, color: color, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Transform(
          transform: Matrix4.skewX(-0.35),
          child: Container(
            width: 6,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accentColor, accentColor.withOpacity(0.3)],
              ),
              boxShadow: [BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 6)],
            ),
          ),
        ),
        SizedBox(width: 10),
        Text(text,
            style: TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        SizedBox(width: 10),
        Expanded(child: LedLine(color: accentColor, height: 10, periodMs: 2600)),
      ],
    );
  }

  Widget _modeBanner() {
    return CyberPanel(
      glowColor: accentColor,
      animate: true,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.15),
            ),
            child: Icon(connectionMode == "WiFi" ? Icons.wifi_rounded : Icons.bluetooth, color: accentColor, size: 16),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "MODE KONEKSI  //  ${connectionMode.toUpperCase()}",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  activeCooler?.nickname ?? "BELUM ADA PERANGKAT AKTIF",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _timerCard() {
    return CyberPanel(
      glowColor: accentColor,
      animate: true,
      padding: EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor.withOpacity(0.15)),
            child: Icon(Icons.timer_outlined, color: accentColor, size: 18),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SYSTEM UPTIME  //  TELEMETRY",
                style: TextStyle(fontSize: 8, color: Colors.white38, letterSpacing: 1.4),
              ),
              Text(uptime,
                  style: TextStyle(
                      fontSize: 26,
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      shadows: [Shadow(color: accentColor.withOpacity(0.6), blurRadius: 10)])),
            ],
          ),
          SizedBox(width: 16),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
              boxShadow: [BoxShadow(color: accentColor.withOpacity(0.8), blurRadius: 10)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledDot(Color c, double glow) {
    return Container(
      width: 22,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: c,
        boxShadow:
            glow > 0 ? [BoxShadow(color: c.withOpacity(0.75 * glow), blurRadius: 8 * glow, spreadRadius: 1 * glow)] : [],
      ),
    );
  }

  Color _previewScale(Color color, double amount) {
    final level = amount.clamp(0.0, 1.0);
    return Color.fromARGB(
      255,
      (color.red * level).round(),
      (color.green * level).round(),
      (color.blue * level).round(),
    );
  }

  Color _previewRainbow(double hue) =>
      HSVColor.fromAHSV(1, hue % 360, 0.88, 1).toColor();

  List<Color> _previewLedColors(double t) {
    const dots = 10;
    final speed = 0.35 + (ledSpeed / 100) * 1.65;
    final brightness = (ledBrightness / 100).clamp(0.0, 1.0);
    final base = ledCustomColor;
    final activeMode = ledMode == "custom" ? customStyle : ledMode;
    final direction = ledForward ? 1.0 : -1.0;
    final moving = t * speed * dots * direction;
    final wrappedHead = (moving % dots + dots) % dots;
    final dim = (Color color, [double level = 1.0]) =>
        _previewScale(color, brightness * level);
    final off = List<Color>.filled(dots, const Color(0xFF292B35));

    if (ledMode == "off") return off;

    switch (activeMode) {
      case "static":
        return List<Color>.filled(dots, dim(base));

      case "rainbow_static":
        return List.generate(dots, (i) => dim(_previewRainbow(i * 36.0)));

      case "rainbow_chase":
        return List.generate(
          dots,
          (i) => dim(_previewRainbow(t * speed * direction * 360 + i * 36)),
        );

      case "chase":
        return List.generate(dots, (i) {
          final distance = direction > 0
              ? (wrappedHead - i + dots) % dots
              : (i - wrappedHead + dots) % dots;
          final intensity = (1.0 - distance / 4.5).clamp(0.0, 1.0);
          return dim(base, intensity);
        });

      case "theater":
      case "theater_rainbow":
        final theaterPhase = (t * speed * 9).floor();
        return List.generate(dots, (i) {
          final theaterOn = ((i + theaterPhase) % 3) == 0;
          if (!theaterOn) return off[i];
          return dim(activeMode == "theater_rainbow"
              ? _previewRainbow(i * 36.0 + theaterPhase * 18)
              : base);
        });

      case "breathe":
      case "breathe_rainbow":
        final pulse = 0.12 + 0.88 * ((sin(t * speed * 2 * pi) + 1) / 2);
        return List.generate(
          dots,
          (i) => dim(
            activeMode == "breathe_rainbow"
                ? _previewRainbow(t * speed * 360 + i * 28)
                : base,
            pulse,
          ),
        );

      case "disco":
        final beat = (t * speed * 18).floor();
        return List.generate(
          dots,
          (i) => dim(_previewRainbow((i * 47 + beat * 83) % 360)),
        );

      case "bounce":
      case "bounce_solid":
        final cycle = (t * speed * (dots - 1) * 2) % ((dots - 1) * 2);
        final rawHead = cycle <= dots - 1 ? cycle : 2 * (dots - 1) - cycle;
        final head = direction > 0 ? rawHead : dots - 1 - rawHead;
        return List.generate(dots, (i) {
          final distance = (head - i).abs();
          final intensity = (1.0 - distance / 4.0).clamp(0.0, 1.0);
          return dim(
            activeMode == "bounce"
                ? _previewRainbow(t * speed * 360 + i * 18)
                : base,
            intensity,
          );
        });

      case "fire":
        return List.generate(dots, (i) {
          final flicker = (sin(t * speed * 21 + i * 2.7) + 1) / 2;
          final red = 185 + (70 * flicker).round();
          final green = 22 + (125 * flicker).round();
          final blue = (18 * flicker).round();
          return dim(Color.fromARGB(255, red, green, blue), 0.65 + flicker * 0.35);
        });

      case "comet":
        return List.generate(dots, (i) {
          final distance = direction > 0
              ? (wrappedHead - i + dots) % dots
              : (i - wrappedHead + dots) % dots;
          final intensity = (1.0 - distance / 7.0).clamp(0.0, 1.0);
          return dim(
            _previewRainbow(t * speed * 360 + distance * 14),
            intensity,
          );
        });

      case "sparkle":
        final spark = (t * speed * 13).floor() % dots;
        final secondSpark = (spark + 4) % dots;
        return List.generate(dots, (i) {
          final isSpark = i == spark || (i == secondSpark && (spark % 2 == 0));
          return dim(isSpark ? Colors.white : base, isSpark ? 1 : 0.48);
        });

      case "wave":
        return List.generate(dots, (i) {
          final level = 0.12 +
              0.88 * ((sin(i * 0.72 + t * speed * direction * 2 * pi) + 1) / 2);
          return dim(base, level);
        });

      case "colorwipe":
        final cycle = (t * speed * 2) % 2;
        final progress = cycle <= 1 ? cycle : 2 - cycle;
        return List.generate(dots, (i) {
          final position = direction > 0 ? i / (dots - 1) : (dots - 1 - i) / (dots - 1);
          return position <= progress ? dim(base) : off[i];
        });

      case "strobe":
        final strobeIsOn = (t * speed * 14).floor().isEven;
        return List<Color>.filled(dots, strobeIsOn ? dim(base) : off.first);

      case "police":
        final policePhase = (t * speed * 8).floor().isEven;
        return List.generate(dots, (i) {
          final redSide = (i + (policePhase ? 0 : 1)) % 2 == 0;
          return dim(redSide ? CyberColors.rog : CyberColors.cyan);
        });

      case "meteor":
        return List.generate(dots, (i) {
          final distance = direction > 0
              ? (wrappedHead - i + dots) % dots
              : (i - wrappedHead + dots) % dots;
          final intensity = (1.0 - distance / 4.0).clamp(0.0, 1.0);
          return dim(base, intensity);
        });

      case "gradient":
        return List.generate(
          dots,
          (i) => dim(Color.lerp(base, Colors.white, i / (dots - 1)) ?? base),
        );

      default:
        return List<Color>.filled(dots, dim(base));
    }
  }

  Widget _ledPreviewStrip() {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) {
        final colors = _previewLedColors(_bgCtrl.value);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: colors
              .map((color) {
                final glow = ((color.red + color.green + color.blue) / 765).clamp(0.0, 1.0);
                return _ledDot(color, glow);
              })
              .toList(),
        );
      },
    );
  }

  Widget _ledDirectionChip(String label, IconData icon, bool value) {
    final selected = ledForward == value;
    return _TapScale(
      glowColor: accentColor,
      onTap: () => sendLed(ledMode, forward: value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accentColor.withOpacity(0.25) : Colors.black26,
          border: Border.all(color: selected ? accentColor : Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: selected ? accentColor : Colors.white54),
          SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  void _openLedModeMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.82),
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + MediaQuery.of(ctx).padding.bottom),
          decoration: BoxDecoration(
            color: CyberColors.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: accentColor.withOpacity(0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
              SizedBox(height: 12),
              Row(children: [
                Icon(Icons.auto_awesome, color: accentColor, size: 16),
                SizedBox(width: 8),
                Text("PILIH MODE LED",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ]),
              SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    _ledModeListTile("custom", "Custom", Icons.palette, isCustom: true),
                    ...kLedModeCatalog
                        .map((m) => _ledModeListTile(m["id"] as String, m["label"] as String, m["icon"] as IconData)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ledModeListTile(String id, String label, IconData icon, {bool isCustom = false}) {
    final selected = ledMode == id;
    final tileColor = isCustom ? CyberColors.magenta : accentColor;
    return _TapScale(
      glowColor: tileColor,
      onTap: () {
        Navigator.pop(context);
        if (isCustom) {
          _openCustomLedBuilder();
        } else {
          sendLed(id);
        }
      },
      child: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (context, _) {
          final shimmer = _bgCtrl.value;
          return Container(
            margin: EdgeInsets.only(bottom: 9),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: selected
                  ? LinearGradient(
                      colors: [tileColor.withOpacity(0.38), tileColor.withOpacity(0.10)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withOpacity(0.03),
                        tileColor.withOpacity(0.10),
                        Colors.white.withOpacity(0.03),
                      ],
                      stops: [
                        ((shimmer - 0.22) % 1.0).clamp(0.0, 1.0),
                        shimmer,
                        ((shimmer + 0.22) % 1.0).clamp(0.0, 1.0),
                      ],
                    ),
              border: Border.all(color: selected ? tileColor : Colors.white12, width: selected ? 1.3 : 1),
              boxShadow: selected
                  ? [BoxShadow(color: tileColor.withOpacity(0.45), blurRadius: 16, spreadRadius: 0.5)]
                  : [BoxShadow(color: tileColor.withOpacity(0.08), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [tileColor.withOpacity(selected ? 0.95 : 0.55), tileColor.withOpacity(0.05)],
                    ),
                    boxShadow: [BoxShadow(color: tileColor.withOpacity(selected ? 0.65 : 0.3), blurRadius: 10)],
                  ),
                  child: Icon(icon, size: 16, color: selected ? Colors.white : tileColor),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.play_arrow_rounded, color: tileColor, size: 20)
                else
                  Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openCustomLedBuilder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomLedSheet(
        initialColor: ledCustomColor,
        initialStyle: customStyle,
        initialSpeed: ledSpeed,
        initialBrightness: ledBrightness,
        initialForward: ledForward,
        accentColor: accentColor,
        onApply: (color, style, speed, brightness, forward) {
          sendLed("custom", color: color, style: style, speed: speed, brightness: brightness, forward: forward);
        },
      ),
    );
  }

  Widget _ledToggleCard() {
    return CyberPanel(
      glowColor: accentColor,
      animate: true,
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor.withOpacity(0.15)),
                child: Icon(Icons.auto_awesome, color: accentColor, size: 14),
              ),
              SizedBox(width: 8),
              Text("LIGHTING MATRIX",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Spacer(),
              Text("20 MODE + CUSTOM",
                  style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
            ],
          ),
          SizedBox(height: 12),
          _ledPreviewStrip(),
          SizedBox(height: 14),
          Row(
            children: [

              _TapScale(
                onTap: () => sendLed(ledMode == "off" ? lastLedEffect : "off"),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    gradient: ledMode != "off"
                        ? LinearGradient(colors: [accentColor, Color.lerp(accentColor, Colors.white, 0.2) ?? accentColor])
                        : null,
                    color: ledMode != "off" ? null : Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ledMode != "off" ? accentColor : Colors.white12),
                    boxShadow: ledMode != "off" ? [BoxShadow(color: accentColor.withOpacity(0.45), blurRadius: 12)] : [],
                  ),
                  child: Icon(Icons.power_settings_new, color: ledMode != "off" ? Colors.black : Colors.white54, size: 20),
                ),
              ),
              SizedBox(width: 10),

              Expanded(
                child: _TapScale(
                  onTap: _openLedModeMenu,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Icon(ledModeIcon(ledMode), color: accentColor, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("MODE AKTIF", style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1)),
                              Text(ledModeLabel(ledMode),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_right, color: Colors.white38, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          cyberSlider(
            label: "Kecepatan",
            icon: Icons.speed,
            value: ledSpeed,
            color: accentColor,
            onChanged: (v) => setState(() => ledSpeed = v),
            onChangeEnd: (v) => sendLed(ledMode, speed: v),
          ),
          SizedBox(height: 8),
          cyberSlider(
            label: "Kecerahan",
            icon: Icons.brightness_6,
            value: ledBrightness,
            color: accentColor,
            onChanged: (v) => setState(() => ledBrightness = v),
            onChangeEnd: (v) => sendLed(ledMode, brightness: v),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.explore, size: 14, color: Colors.white38),
              SizedBox(width: 6),
              Text("Arah Gerakan", style: TextStyle(color: Colors.white54, fontSize: 12)),
              Spacer(),
              _ledDirectionChip("Maju", Icons.arrow_forward, true),
              SizedBox(width: 8),
              _ledDirectionChip("Mundur", Icons.arrow_back, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _voltageDisplayCard(bool online) {
    final frac = ((setVolt - 5.0) / (15.0 - 5.0)).clamp(0.0, 1.0);
    return CyberPanel(
      glowColor: accentColor,
      animate: true,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 22),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: accentColor.withOpacity(0.8), blurRadius: 9)],
                ),
              ),
              SizedBox(width: 8),
              Text(
                "POWER CORE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (online ? CyberColors.success : Colors.white24).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (online ? CyberColors.success : Colors.white24).withOpacity(0.65),
                  ),
                ),
                child: Text(
                  online ? "LIVE TELEMETRY" : "LOCAL PRESET",
                  style: TextStyle(
                    color: online ? CyberColors.success : Colors.white54,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "ACTIVE VOLTAGE OUTPUT",
              style: TextStyle(
                color: Colors.white30,
                fontSize: 8,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: 208,
            height: 208,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseCtrl, _bgCtrl]),
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [

                    Transform.rotate(
                      angle: _bgCtrl.value * 2 * pi,
                      child: Opacity(
                        opacity: 0.16,
                        child: CustomPaint(painter: _HexPainter(color: accentColor), size: const Size(160, 160)),
                      ),
                    ),
                    CustomPaint(
                      painter: _GaugePainter(
                          value: frac, color: accentColor, pulse: _pulseCtrl.value, run: (_bgCtrl.value * 3) % 1.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 380),
                              switchInCurve: Curves.easeOutBack,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                              child: Text(
                                setVolt.toStringAsFixed(1),
                                key: ValueKey(setVolt),
                                style: TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.0,
                                  shadows: [Shadow(color: accentColor.withOpacity(0.85), blurRadius: 24)],
                                ),
                              ),
                            ),
                            Text('VOLT',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 5)),
                            const SizedBox(height: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                              decoration: BoxDecoration(
                                color: (online ? CyberColors.success : Colors.white24).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: online ? CyberColors.success : Colors.white24),
                              ),
                              child: Text(online ? 'LIVE' : 'TERSIMPAN',
                                  style: TextStyle(
                                      fontSize: 9,
                                      letterSpacing: 1.4,
                                      fontWeight: FontWeight.bold,
                                      color: online ? CyberColors.success : Colors.white54)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetList() {
    final presets = [
      {"v": 5.0, "c": CyberColors.amber},
      {"v": 9.0, "c": Colors.blueAccent},
      {"v": 12.0, "c": CyberColors.danger},
      {"v": 15.0, "c": CyberColors.violet},
    ];
    return Row(
      children: presets.map((p) {
        double v = p["v"] as double;
        Color c = p["c"] as Color;
        bool selected = setVolt == v;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: _TapScale(
              glowColor: c,
              onTap: () => sendVoltage(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [c.withOpacity(0.34), c.withOpacity(0.08)],
                        )
                      : null,
                  color: selected ? null : Colors.black26,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: selected ? c : Colors.white12, width: selected ? 1.8 : 1),
                  boxShadow: selected
                      ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 20, spreadRadius: -2)]
                      : [],
                ),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      padding: EdgeInsets.all(selected ? 7 : 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? c.withOpacity(0.22) : Colors.transparent,
                      ),
                      child: Icon(Icons.bolt, color: c, size: selected ? 24 : 20),
                    ),
                    SizedBox(height: 7),
                    Text('${v.toStringAsFixed(0)}V',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                    SizedBox(height: 2),
                    Text(selected ? "TERPILIH" : "PILIH",
                        style: TextStyle(
                            fontSize: 9,
                            color: selected ? c : Colors.white38,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            letterSpacing: 0.6)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap) {
    return _TapScale(
      glowColor: accentColor,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.16),
              Colors.black.withOpacity(0.42),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withOpacity(0.65)),
          boxShadow: [
            BoxShadow(color: accentColor.withOpacity(0.18), blurRadius: 16, spreadRadius: -2),
            const BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.15),
              ),
              child: Icon(icon, size: 15, color: accentColor),
            ),
            SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final double pulse;
  final double run;

  _GaugePainter({required this.value, required this.color, required this.pulse, this.run = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 14;
    const startAngle = pi * 0.75;
    const sweepAngle = pi * 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i <= 20; i++) {
      final a = startAngle + sweepAngle * (i / 20);
      final major = i % 5 == 0;

      final d = (run * 21 - i) % 21;
      final k = max(0.0, 1.0 - d / 6.0);
      final len = (major ? 13 : 8) + 3.0 * k;
      final inner = Offset(center.dx + (radius - len) * cos(a), center.dy + (radius - len) * sin(a));
      final outer = Offset(center.dx + (radius - 3) * cos(a), center.dy + (radius - 3) * sin(a));
      final tickPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.6 + 1.2 * k
        ..color = Color.lerp(Colors.white.withOpacity(major ? 0.22 : 0.10), color, k) ?? color;
      canvas.drawLine(inner, outer, tickPaint);
    }

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.06);
    canvas.drawArc(rect, startAngle, sweepAngle, false, bgPaint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.14 + 0.12 * pulse);
    canvas.drawArc(rect, startAngle, sweepAngle * value.clamp(0.0, 1.0), false, glowPaint);

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweepAngle,
        transform: GradientRotation(startAngle),
        colors: [
          color.withOpacity(0.45),
          color,
          Color.lerp(color, Colors.white, 0.6) ?? color,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweepAngle * value.clamp(0.0, 1.0), false, fgPaint);

    final endAngle = startAngle + sweepAngle * value.clamp(0.0, 1.0);
    final dotCenter = Offset(center.dx + radius * cos(endAngle), center.dy + radius * sin(endAngle));
    if (value > 0.01) {
      canvas.drawCircle(dotCenter, 10 + 3 * pulse, Paint()..color = color.withOpacity(0.28 + 0.18 * pulse));
      canvas.drawCircle(dotCenter, 5.4, Paint()..color = Colors.white);
      canvas.drawCircle(
          dotCenter,
          5.4,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.pulse != pulse ||
      oldDelegate.run != run ||
      oldDelegate.color != color;
}

