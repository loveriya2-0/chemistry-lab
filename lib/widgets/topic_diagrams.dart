import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';

/// A labelled drawing that explains one idea of a note: what it shows,
/// the picture itself, and a one-line takeaway. Tap to zoom.
///
/// Every drawing follows the NCERT figure for the idea; labels come in
/// English and Hindi.
class TopicDiagramCard extends StatelessWidget {
  const TopicDiagramCard({super.key, required this.id});

  final String id;

  static bool exists(String id) => _specs.containsKey(id);

  @override
  Widget build(BuildContext context) {
    final spec = _specs[id];
    if (spec == null) return const SizedBox.shrink();
    final s = context.strings;
    final hi = s.language == AppLanguage.hi;
    final title = hi ? spec.titleHi : spec.title;
    final caption = hi ? spec.captionHi : spec.caption;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.diagramTitle, style: AppText.display(15, color: LabColors.secondary)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink)),
            const SizedBox(height: 10),
            Semantics(
              label: '$title. $caption',
              image: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _zoom(context, spec, hi, title),
                child: _Drawing(spec: spec, hi: hi),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 18, color: LabColors.amber),
                const SizedBox(width: 6),
                Expanded(child: Text(caption, style: const TextStyle(height: 1.45, color: LabColors.ink))),
              ],
            ),
            const SizedBox(height: 4),
            Text(s.diagramZoomHint, style: const TextStyle(fontSize: 11.5, color: LabColors.muted)),
          ],
        ),
      ),
    );
  }

  static void _zoom(BuildContext context, _Spec spec, bool hi, String title) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: Text(title)),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Padding(padding: const EdgeInsets.all(12), child: _Drawing(spec: spec, hi: hi)),
          ),
        ),
      ),
    ));
  }
}

class _Drawing extends StatelessWidget {
  const _Drawing({required this.spec, required this.hi});

  final _Spec spec;
  final bool hi;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFFAFBFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: LabColors.line)),
      padding: const EdgeInsets.all(6),
      child: AspectRatio(
        aspectRatio: spec.size.width / spec.size.height,
        // Labels use the app's text font (Devanagari falls back as elsewhere).
        child: CustomPaint(painter: _DiagramPainter(spec, hi, DefaultTextStyle.of(context).style.fontFamily)),
      ),
    );
  }
}

typedef _Draw = void Function(_Pen p);

class _Spec {
  const _Spec({
    required this.title,
    required this.titleHi,
    required this.caption,
    required this.captionHi,
    required this.size,
    required this.draw,
  });

  final String title;
  final String titleHi;
  final String caption;
  final String captionHi;

  /// Drawing coordinates; scaled to the card's width.
  final Size size;
  final _Draw draw;
}

class _DiagramPainter extends CustomPainter {
  _DiagramPainter(this.spec, this.hi, this.fontFamily);

  final _Spec spec;
  final bool hi;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / spec.size.width);
    spec.draw(_Pen(canvas, hi, spec.size, fontFamily));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiagramPainter old) => old.spec != spec || old.hi != hi || old.fontFamily != fontFamily;
}

/// Small drawing kit shared by every diagram.
class _Pen {
  _Pen(this.c, this.hi, this.size, this.fontFamily);

  final Canvas c;
  final bool hi;
  final Size size;
  final String? fontFamily;

  String t(String en, String hindi) => hi ? hindi : en;

  Paint stroke(Color color, [double width = 1.6]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint fill(Color color) => Paint()..color = color;

  /// Text centred on [at] (or starting at it with [align] left / ending at
  /// it with right), kept inside the drawing.
  void text(
    String s,
    Offset at, {
    double size = 10,
    Color color = LabColors.ink,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.center,
    double maxWidth = 160,
    bool middle = true,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: fontFamily, fontSize: size, color: color, fontWeight: weight, height: 1.2)),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    var x = switch (align) {
      TextAlign.left => at.dx,
      TextAlign.right => at.dx - tp.width,
      _ => at.dx - tp.width / 2,
    };
    x = x.clamp(2.0, math.max(2.0, this.size.width - tp.width - 2));
    final y = middle ? at.dy - tp.height / 2 : at.dy;
    tp.paint(c, Offset(x, y));
  }

  void line(Offset a, Offset b, Color color, [double width = 1.6]) => c.drawLine(a, b, stroke(color, width));

  void dashed(Offset a, Offset b, Color color, {double width = 1.2, double dash = 4, double gap = 3}) =>
      dashedPath(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), color, width: width, dash: dash, gap: gap);

  void dashedPath(Path path, Color color, {double width = 1.4, double dash = 5, double gap = 4}) {
    final paint = stroke(color, width);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  /// A line with an arrowhead at [b]; [both] adds one at [a] too.
  void arrow(Offset a, Offset b, Color color, {double width = 1.6, bool both = false, double head = 7}) {
    line(a, b, color, width);
    void tip(Offset from, Offset to) {
      final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
      final path = Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(to.dx - head * math.cos(angle - 0.45), to.dy - head * math.sin(angle - 0.45))
        ..lineTo(to.dx - head * math.cos(angle + 0.45), to.dy - head * math.sin(angle + 0.45))
        ..close();
      c.drawPath(path, fill(color));
    }

    tip(a, b);
    if (both) tip(b, a);
  }

  void circle(Offset at, double r, {Color? fillColor, Color? border, double width = 1.4}) {
    if (fillColor != null) c.drawCircle(at, r, fill(fillColor));
    if (border != null) c.drawCircle(at, r, stroke(border, width));
  }

  void rrect(Rect r, double radius, {Color? fillColor, Color? border, double width = 1.4}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    if (fillColor != null) c.drawRRect(rr, fill(fillColor));
    if (border != null) c.drawRRect(rr, stroke(border, width));
  }

  /// A ball labelled with one letter, as in "A + B → AB".
  void atomBall(Offset at, String letter, Color color, {double r = 10}) {
    circle(at, r, fillColor: color, border: Colors.white, width: 1.5);
    text(letter, at, size: r * 1.05, color: Colors.white, weight: FontWeight.w800);
  }

  /// Electrons spaced evenly on a shell, starting at [start] radians.
  /// [skip] leaves gaps at those slot indexes; [highlight] colours slots.
  void electrons(Offset centre, double r, int slots, {int? count, double start = 0, Set<int> highlight = const {}, Color color = LabColors.primary}) {
    final n = count ?? slots;
    for (var i = 0; i < n; i++) {
      final a = start + 2 * math.pi * i / slots;
      final at = centre + Offset(math.cos(a) * r, math.sin(a) * r);
      circle(at, 3.6, fillColor: highlight.contains(i) ? LabColors.danger : color, border: Colors.white, width: 1);
    }
  }
}

const _red = Color(0xFFDC2626);
const _blue = Color(0xFF2563EB);
const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);
const _purple = Color(0xFF7C3AED);
const _grey = Color(0xFF94A3B8);

final _specs = <String, _Spec>{
  'ph-scale': _Spec(
    title: 'The pH scale (0 to 14)',
    titleHi: 'pH स्केल (0 से 14)',
    caption: 'Below 7 is acidic, 7 is neutral, above 7 is basic. The lower the pH, the more H⁺ ions; each step is ten times stronger.',
    captionHi: '7 से कम अम्लीय, 7 उदासीन, 7 से अधिक क्षारकीय। pH जितना कम, H⁺ आयन उतने अधिक; हर एक इकाई दस गुना अंतर है।',
    size: const Size(340, 200),
    draw: _phScale,
  ),
  'reaction-types': _Spec(
    title: 'Four types of chemical reactions',
    titleHi: 'रासायनिक अभिक्रियाओं के चार प्रकार',
    caption: 'Watch the partners: they join (combination), split (decomposition), one is pushed out (displacement), or two pairs swap (double displacement).',
    captionHi: 'साथियों को देखें: जुड़ते हैं (संयोजन), टूटते हैं (वियोजन), एक को हटाया जाता है (विस्थापन), या दो जोड़े अदला-बदली करते हैं (द्विविस्थापन)।',
    size: const Size(340, 276),
    draw: _reactionTypes,
  ),
  'activity-series': _Spec(
    title: 'Activity (reactivity) series of metals',
    titleHi: 'धातुओं की सक्रियता श्रेणी',
    caption: 'A metal higher in the series displaces a metal below it from its salt solution, e.g. Zn displaces Cu from CuSO₄.',
    captionHi: 'श्रेणी में ऊपर वाली धातु नीचे वाली धातु को उसके लवण के विलयन से विस्थापित करती है, जैसे Zn, CuSO₄ से Cu को।',
    size: const Size(340, 290),
    draw: _activitySeries,
  ),
  'ionic-bond-nacl': _Spec(
    title: 'Ionic bond: formation of sodium chloride',
    titleHi: 'आयनिक आबंध: सोडियम क्लोराइड का बनना',
    caption: 'Na gives its one outer electron to Cl. Both get a complete outer shell (octet); the opposite ions Na⁺ and Cl⁻ attract each other.',
    captionHi: 'Na अपना एक बाहरी इलेक्ट्रॉन Cl को देता है। दोनों का बाहरी कोश पूरा (अष्टक) हो जाता है; विपरीत आवेश वाले Na⁺ और Cl⁻ एक-दूसरे को आकर्षित करते हैं।',
    size: const Size(340, 300),
    draw: _ionicBond,
  ),
  'covalent-methane': _Spec(
    title: 'Covalent bonds in methane (CH₄)',
    titleHi: 'मेथेन (CH₄) में सहसंयोजी आबंध',
    caption: 'Carbon shares one electron pair with each of four hydrogen atoms. Each shared pair is one single covalent bond (one line).',
    captionHi: 'कार्बन चारों हाइड्रोजन परमाणुओं में से हर एक के साथ एक इलेक्ट्रॉन-युग्म साझा करता है। हर साझा युग्म एक एकल सहसंयोजी आबंध (एक रेखा) है।',
    size: const Size(340, 210),
    draw: _methane,
  ),
  'bohr-sodium': _Spec(
    title: "Bohr's model: electrons in shells (sodium)",
    titleHi: 'बोर मॉडल: कोशों में इलेक्ट्रॉन (सोडियम)',
    caption: 'Electrons move in fixed shells K, L, M… around the nucleus. A shell holds at most 2n² electrons and fills from the inside out.',
    captionHi: 'इलेक्ट्रॉन नाभिक के चारों ओर निश्चित कोशों K, L, M… में घूमते हैं। एक कोश में अधिकतम 2n² इलेक्ट्रॉन होते हैं और भराव अंदर से बाहर होता है।',
    size: const Size(340, 210),
    draw: _bohr,
  ),
  'gold-foil': _Spec(
    title: "Rutherford's α-particle scattering experiment",
    titleHi: 'रदरफ़ोर्ड का α-कण प्रकीर्णन प्रयोग',
    caption: 'Most of the atom is empty space. Its positive charge and nearly all its mass are packed into a tiny nucleus at the centre.',
    captionHi: 'परमाणु का अधिकांश भाग खाली है। इसका धन आवेश और लगभग पूरा द्रव्यमान केंद्र के एक बहुत छोटे नाभिक में होता है।',
    size: const Size(340, 200),
    draw: _goldFoil,
  ),
  'tyndall-effect': _Spec(
    title: 'Tyndall effect',
    titleHi: 'टिंडल प्रभाव',
    caption: 'Colloid particles are big enough to scatter light, so the beam’s path shows. Particles in a true solution are too small to do this.',
    captionHi: 'कोलॉइड के कण प्रकाश को प्रकीर्णित करने लायक बड़े होते हैं, इसलिए किरण का पथ दिखता है। वास्तविक विलयन के कण इतने छोटे होते हैं कि ऐसा नहीं होता।',
    size: const Size(340, 190),
    draw: _tyndall,
  ),
  'paper-chromatography': _Spec(
    title: 'Separating the colours in ink by paper chromatography',
    titleHi: 'पेपर क्रोमैटोग्राफ़ी से स्याही के रंग अलग करना',
    caption: 'The solvent rises up the paper and carries the colours. The colour that dissolves more in the solvent travels higher.',
    captionHi: 'विलायक कागज़ पर ऊपर चढ़ता है और रंगों को साथ ले जाता है। जो रंग विलायक में अधिक घुलता है, वह अधिक ऊपर जाता है।',
    size: const Size(340, 210),
    draw: _chromatography,
  ),
  'periodic-trends': _Spec(
    title: 'Blocks and periodic trends',
    titleHi: 'ब्लॉक और आवर्ती प्रवृत्तियाँ',
    caption: 'Across a period the nuclear charge grows and pulls electrons closer; down a group a new shell is added each time.',
    captionHi: 'आवर्त में आगे बढ़ने पर नाभिकीय आवेश बढ़ता है और इलेक्ट्रॉनों को पास खींचता है; वर्ग में नीचे जाने पर हर बार एक नया कोश जुड़ता है।',
    size: const Size(340, 250),
    draw: _periodicTrends,
  ),
  'vsepr-shapes': _Spec(
    title: 'Shapes of molecules (VSEPR) and hybridisation',
    titleHi: 'अणुओं की आकृतियाँ (VSEPR) और संकरण',
    caption: 'Electron pairs around the central atom push each other as far apart as possible, which fixes the shape and bond angle.',
    captionHi: 'केंद्रीय परमाणु के चारों ओर के इलेक्ट्रॉन-युग्म एक-दूसरे को यथासंभव दूर धकेलते हैं, इसी से आकृति और आबंध कोण तय होते हैं।',
    size: const Size(340, 330),
    draw: _vsepr,
  ),
  'daniell-cell': _Spec(
    title: 'Daniell cell (a galvanic cell)',
    titleHi: 'डेनियल सेल (एक गैल्वेनी सेल)',
    caption: 'Zinc is oxidised at the anode and Cu²⁺ is reduced at the cathode. Electrons flow through the wire from Zn to Cu; the salt bridge completes the circuit. E°cell = 1.1 V.',
    captionHi: 'ऐनोड पर जिंक का ऑक्सीकरण और कैथोड पर Cu²⁺ का अपचयन होता है। इलेक्ट्रॉन तार से Zn से Cu की ओर बहते हैं; लवण सेतु परिपथ पूरा करता है। E°सेल = 1.1 V।',
    size: const Size(340, 270),
    draw: _daniell,
  ),
  'activation-energy': _Spec(
    title: 'Activation energy and the effect of a catalyst',
    titleHi: 'सक्रियण ऊर्जा और उत्प्रेरक का प्रभाव',
    caption: 'Reactants must climb the energy barrier Ea to react. A catalyst gives a lower barrier, so the reaction goes faster; ΔH does not change.',
    captionHi: 'अभिक्रिया के लिए अभिकारकों को ऊर्जा अवरोध Ea पार करना होता है। उत्प्रेरक कम ऊँचा अवरोध देता है, इसलिए अभिक्रिया तेज़ होती है; ΔH नहीं बदलता।',
    size: const Size(340, 230),
    draw: _activationEnergy,
  ),
  'soap-micelle': _Spec(
    title: 'How soap cleans: a micelle',
    titleHi: 'साबुन कैसे साफ़ करता है: मिसेल',
    caption: 'The long carbon tails dissolve in the oily dirt and the ionic heads stay in water. The dirt is trapped inside the micelle and washed away.',
    captionHi: 'लंबी कार्बन पूँछें तैलीय मैल में घुल जाती हैं और आयनिक सिरे पानी में रहते हैं। मैल मिसेल के अंदर फँसकर पानी के साथ बह जाता है।',
    size: const Size(340, 220),
    draw: _micelle,
  ),
  'dynamic-equilibrium': _Spec(
    title: 'Reaching chemical equilibrium',
    titleHi: 'रासायनिक साम्यावस्था तक पहुँचना',
    caption: 'At equilibrium the reaction has not stopped: forward and backward reactions go on at the same rate, so concentrations stay constant.',
    captionHi: 'साम्यावस्था पर अभिक्रिया रुकती नहीं: अग्र और पश्च अभिक्रियाएँ समान दर से चलती रहती हैं, इसलिए सांद्रताएँ स्थिर रहती हैं।',
    size: const Size(340, 210),
    draw: _equilibrium,
  ),
};

// ---------------------------------------------------------------------------
// The drawings. Coordinates are in each spec's [size].

void _phScale(_Pen p) {
  const left = 20.0, right = 320.0, top = 60.0, bottom = 84.0;
  double x(double ph) => left + (right - left) * ph / 14;
  final bar = Rect.fromLTRB(left, top, right, bottom);
  p.c.drawRRect(
    RRect.fromRectAndRadius(bar, const Radius.circular(6)),
    Paint()
      ..shader = ui.Gradient.linear(bar.centerLeft, bar.centerRight, const [
        Color(0xFFD7263D),
        Color(0xFFF46036),
        Color(0xFFF2C14E),
        Color(0xFF2E9F45),
        Color(0xFF1B98E0),
        Color(0xFF3D348B),
        Color(0xFF5B2A86),
      ], const [0, 0.17, 0.33, 0.5, 0.67, 0.84, 1]),
  );
  for (var i = 0; i <= 14; i++) {
    p.line(Offset(x(i.toDouble()), bottom), Offset(x(i.toDouble()), bottom + 4), LabColors.muted, 1);
    p.text('$i', Offset(x(i.toDouble()), bottom + 11), size: 9, color: LabColors.muted, weight: FontWeight.w700);
  }
  void mark(double ph, String label, {required bool above}) {
    final at = Offset(x(ph), (top + bottom) / 2);
    p.circle(at, 4.5, fillColor: Colors.white, border: LabColors.ink, width: 1.5);
    if (above) {
      p.line(Offset(at.dx, top - 2), Offset(at.dx, top - 14), LabColors.ink, 1);
      p.text(label, Offset(at.dx, top - 30), size: 8.5, maxWidth: 62, weight: FontWeight.w600);
    } else {
      p.line(Offset(at.dx, bottom + 18), Offset(at.dx, bottom + 26), LabColors.ink, 1);
      p.text(label, Offset(at.dx, bottom + 42), size: 8.5, maxWidth: 62, weight: FontWeight.w600);
    }
  }

  mark(1.2, p.t('Gastric juice ~1.2', 'जठर रस ~1.2'), above: true);
  mark(7, p.t('Pure water 7', 'शुद्ध जल 7'), above: true);
  mark(10, p.t('Milk of magnesia ~10', 'मिल्क ऑफ़ मैग्नीशिया ~10'), above: true);
  mark(2.2, p.t('Lemon juice ~2.2', 'नींबू का रस ~2.2'), above: false);
  mark(7.4, p.t('Blood ~7.4', 'रक्त ~7.4'), above: false);
  mark(14, p.t('NaOH solution ~14', 'NaOH विलयन ~14'), above: false);

  p.arrow(const Offset(150, 178), const Offset(22, 178), _red, width: 2);
  p.text(p.t('More acidic (more H⁺)', 'अधिक अम्लीय (अधिक H⁺)'), const Offset(22, 192), size: 9, color: _red, weight: FontWeight.w700, align: TextAlign.left);
  p.arrow(const Offset(190, 178), const Offset(318, 178), const Color(0xFF3D348B), width: 2);
  p.text(p.t('More basic (more OH⁻)', 'अधिक क्षारकीय (अधिक OH⁻)'), const Offset(318, 192),
      size: 9, color: const Color(0xFF3D348B), weight: FontWeight.w700, align: TextAlign.right);
  p.text(p.t('Neutral', 'उदासीन'), const Offset(170, 178), size: 9, color: _green, weight: FontWeight.w800);
}

void _reactionTypes(_Pen p) {
  const colors = {'A': _red, 'B': _blue, 'C': _green, 'D': _amber};
  // Molecules as letter groups; '+' and '→' between them.
  void row(double top, String name, List<String> tokens, String example) {
    p.text(name, Offset(10, top), size: 10.5, weight: FontWeight.w800, color: LabColors.primary, align: TextAlign.left, maxWidth: 320, middle: false);
    const r = 9.0, gap = 9.0;
    double widthOf(String tok) => switch (tok) {
          '+' || '→' => 14,
          _ => tok.length * 2 * r,
        };
    final total = tokens.fold<double>(0, (w, tok) => w + widthOf(tok)) + gap * (tokens.length - 1);
    var x = (p.size.width - total) / 2;
    final y = top + 30;
    for (final tok in tokens) {
      if (tok == '+' || tok == '→') {
        p.text(tok, Offset(x + 7, y), size: 15, weight: FontWeight.w800, color: LabColors.muted);
      } else {
        for (var i = 0; i < tok.length; i++) {
          p.atomBall(Offset(x + r + i * 2 * r, y), tok[i], colors[tok[i]]!, r: r);
        }
      }
      x += widthOf(tok) + gap;
    }
    p.text(example, Offset(p.size.width / 2, top + 52), size: 9.5, color: LabColors.muted, weight: FontWeight.w600, maxWidth: 330);
  }

  row(4, p.t('Combination: two or more substances join', 'संयोजन: दो या अधिक पदार्थ जुड़ते हैं'), ['A', '+', 'B', '→', 'AB'], 'CaO + H₂O → Ca(OH)₂');
  row(72, p.t('Decomposition: one substance breaks up', 'वियोजन: एक पदार्थ टूटता है'), ['AB', '→', 'A', '+', 'B'], 'CaCO₃ →(heat) CaO + CO₂');
  row(140, p.t('Displacement: a more reactive element pushes one out', 'विस्थापन: अधिक सक्रिय तत्व दूसरे को हटाता है'), ['A', '+', 'BC', '→', 'AC', '+', 'B'],
      'Fe + CuSO₄ → FeSO₄ + Cu');
  row(208, p.t('Double displacement: ions are exchanged', 'द्विविस्थापन: आयनों की अदला-बदली'), ['AB', '+', 'CD', '→', 'AD', '+', 'CB'],
      'Na₂SO₄ + BaCl₂ → BaSO₄↓ + 2NaCl');
}

void _activitySeries(_Pen p) {
  final metals = [
    ('K', p.t('Potassium', 'पोटैशियम')),
    ('Na', p.t('Sodium', 'सोडियम')),
    ('Ca', p.t('Calcium', 'कैल्शियम')),
    ('Mg', p.t('Magnesium', 'मैग्नीशियम')),
    ('Al', p.t('Aluminium', 'ऐलुमिनियम')),
    ('Zn', p.t('Zinc', 'जिंक (जस्ता)')),
    ('Fe', p.t('Iron', 'आयरन (लोहा)')),
    ('Pb', p.t('Lead', 'लेड (सीसा)')),
    ('[H]', p.t('Hydrogen', 'हाइड्रोजन')),
    ('Cu', p.t('Copper', 'कॉपर (ताँबा)')),
    ('Hg', p.t('Mercury', 'मरकरी (पारा)')),
    ('Ag', p.t('Silver', 'सिल्वर (चाँदी)')),
    ('Au', p.t('Gold', 'गोल्ड (सोना)')),
  ];
  const top = 26.0, step = 20.0, left = 90.0, w = 118.0;
  p.text(p.t('Most reactive', 'सबसे अधिक सक्रिय'), const Offset(left + w / 2, 10), size: 9.5, weight: FontWeight.w800, color: _red);
  for (final (i, (sym, name)) in metals.indexed) {
    final y = top + i * step;
    final isH = sym == '[H]';
    final color = isH ? _grey : Color.lerp(_red, const Color(0xFFB8860B), i / (metals.length - 1))!;
    p.rrect(Rect.fromLTWH(left, y, w, step - 4), 8, fillColor: isH ? Colors.white : color.withValues(alpha: 0.14), border: color, width: isH ? 1 : 1.2);
    p.text(sym, Offset(left + 16, y + (step - 4) / 2), size: 10, weight: FontWeight.w800, color: color);
    p.text(name, Offset(left + 34, y + (step - 4) / 2), size: 9, align: TextAlign.left, maxWidth: 82);
  }
  final end = top + metals.length * step - 4;
  p.text(p.t('Least reactive', 'सबसे कम सक्रिय'), Offset(left + w / 2, end + 10), size: 9.5, weight: FontWeight.w800, color: const Color(0xFFB8860B));
  // Reactivity arrow on the left.
  p.arrow(const Offset(70, top), Offset(70, end), LabColors.muted, width: 2);
  p.c.save();
  p.c.translate(54, (top + end) / 2);
  p.c.rotate(-math.pi / 2);
  p.text(p.t('Reactivity decreases', 'सक्रियता घटती है'), Offset.zero, size: 10, weight: FontWeight.w700, color: LabColors.muted, maxWidth: 200);
  p.c.restore();
  // Brackets on the right: above / below hydrogen.
  void bracket(int from, int to, String label, Color color) {
    final y1 = top + from * step, y2 = top + to * step + step - 4;
    const x = left + w + 8;
    p.line(Offset(x, y1), Offset(x + 6, y1), color, 1.4);
    p.line(Offset(x + 6, y1), Offset(x + 6, y2), color, 1.4);
    p.line(Offset(x, y2), Offset(x + 6, y2), color, 1.4);
    p.text(label, Offset(x + 12, (y1 + y2) / 2), size: 9, color: color, weight: FontWeight.w700, align: TextAlign.left, maxWidth: 106);
  }

  bracket(0, 7, p.t('Above hydrogen: give H₂ gas with dilute acids', 'हाइड्रोजन से ऊपर: तनु अम्लों से H₂ गैस देती हैं'), _red);
  bracket(9, 12, p.t('Below hydrogen: do not give H₂ with dilute acids', 'हाइड्रोजन से नीचे: तनु अम्लों से H₂ नहीं देतीं'), const Color(0xFFB8860B));
}

void _atom(_Pen p, Offset at, String symbol, List<int> shells, {Set<int> gainedOuter = const {}, int? emptySlot, double first = 18, double step = 13, double start = 0}) {
  for (var i = 0; i < shells.length; i++) {
    p.circle(at, first + i * step, border: _grey, width: 1);
  }
  p.circle(at, 11, fillColor: LabColors.primarySoft, border: LabColors.primary);
  p.text(symbol, at, size: 9.5, weight: FontWeight.w800, color: LabColors.primary);
  for (var i = 0; i < shells.length; i++) {
    final outer = i == shells.length - 1;
    final slots = i == 0 ? 2 : 8;
    final r = first + i * step;
    if (outer && emptySlot != null) {
      // Seven of eight slots filled, the gap facing the incoming electron.
      for (var k = 0; k < slots; k++) {
        if (k == emptySlot) continue;
        final a = start + 2 * math.pi * k / slots;
        p.circle(at + Offset(math.cos(a) * r, math.sin(a) * r), 3.6, fillColor: LabColors.primary, border: Colors.white, width: 1);
      }
    } else {
      p.electrons(at, r, shells[i] == 1 ? 1 : slots, count: shells[i], start: i == 0 ? math.pi / 2 : start, highlight: outer ? gainedOuter : const {});
    }
  }
}

void _ionicBond(_Pen p) {
  const na = Offset(80, 74), cl = Offset(250, 74);
  _atom(p, na, 'Na', [2, 8, 1]);
  _atom(p, cl, 'Cl', [2, 8, 7], emptySlot: 4);
  // The transferred electron: from Na's outer shell (right) to Cl's gap (left).
  final path = Path()
    ..moveTo(na.dx + 44, na.dy - 4)
    ..quadraticBezierTo(165, 10, cl.dx - 44, cl.dy - 6);
  p.c.drawPath(path, p.stroke(LabColors.danger, 1.6));
  p.arrow(Offset(cl.dx - 50, cl.dy - 14), Offset(cl.dx - 45, cl.dy - 6), LabColors.danger, head: 7);
  p.text(p.t('1 electron transferred', '1 इलेक्ट्रॉन स्थानांतरित'), const Offset(165, 30), size: 9, color: LabColors.danger, weight: FontWeight.w700);
  p.text('Na (2, 8, 1)', Offset(na.dx, 134), size: 10, weight: FontWeight.w700);
  p.text('Cl (2, 8, 7)', Offset(cl.dx, 134), size: 10, weight: FontWeight.w700);

  p.arrow(const Offset(165, 128), const Offset(165, 158), LabColors.muted, width: 2);

  const naIon = Offset(80, 222), clIon = Offset(250, 222);
  p.text('[', Offset(naIon.dx - 44, naIon.dy), size: 52, color: LabColors.muted, weight: FontWeight.w300);
  p.text(']⁺', Offset(naIon.dx + 50, naIon.dy), size: 52, color: LabColors.muted, weight: FontWeight.w300);
  _atom(p, naIon, 'Na', [2, 8]);
  p.text('[', Offset(clIon.dx - 60, clIon.dy), size: 60, color: LabColors.muted, weight: FontWeight.w300);
  p.text(']⁻', Offset(clIon.dx + 66, clIon.dy), size: 60, color: LabColors.muted, weight: FontWeight.w300);
  _atom(p, clIon, 'Cl', [2, 8, 8], gainedOuter: {4});
  p.text('Na⁺ (2, 8)', Offset(naIon.dx, 284), size: 10, weight: FontWeight.w700);
  p.text('Cl⁻ (2, 8, 8)', Offset(clIon.dx, 284), size: 10, weight: FontWeight.w700);
  p.arrow(const Offset(142, 222), const Offset(182, 222), _purple, both: true, width: 1.6);
  p.text(p.t('attraction', 'आकर्षण'), const Offset(162, 234), size: 8.5, color: _purple, weight: FontWeight.w700);
}

void _methane(_Pen p) {
  // Electron-dot structure on the left.
  const c = Offset(100, 100);
  const d = 58.0;
  for (final dir in const [Offset(0, -1), Offset(1, 0), Offset(0, 1), Offset(-1, 0)]) {
    final h = c + dir * d;
    p.circle(h, 13, fillColor: const Color(0xFFFFF4E5), border: _amber, width: 1);
    p.text('H', h, size: 11, weight: FontWeight.w800, color: _amber);
    // The shared pair, side by side across the bond.
    final mid = c + dir * (d * 0.5);
    final side = Offset(-dir.dy, dir.dx) * 4.5;
    p.circle(mid + side, 3.4, fillColor: LabColors.primary);
    p.text('×', mid - side, size: 11, weight: FontWeight.w900, color: LabColors.danger);
  }
  p.circle(c, 15, fillColor: LabColors.primarySoft, border: LabColors.primary);
  p.text('C', c, size: 12, weight: FontWeight.w800, color: LabColors.primary);
  p.text(p.t('Electron-dot structure', 'इलेक्ट्रॉन-बिंदु संरचना'), const Offset(100, 192), size: 9.5, weight: FontWeight.w700, color: LabColors.muted);

  // Structural formula on the right.
  const s = Offset(262, 92);
  const l = 34.0;
  for (final dir in const [Offset(0, -1), Offset(1, 0), Offset(0, 1), Offset(-1, 0)]) {
    p.line(s + dir * 10, s + dir * (l - 9), LabColors.ink, 2);
    p.text('H', s + dir * l, size: 13, weight: FontWeight.w700);
  }
  p.text('C', s, size: 14, weight: FontWeight.w800, color: LabColors.primary);
  p.text(p.t('Structural formula', 'संरचना सूत्र'), Offset(s.dx, 160), size: 9.5, weight: FontWeight.w700, color: LabColors.muted);
  // Legend.
  p.circle(const Offset(204, 182), 3.4, fillColor: LabColors.primary);
  p.text(p.t('electron of C', 'C का इलेक्ट्रॉन'), const Offset(211, 182), size: 9, align: TextAlign.left);
  p.text('×', const Offset(204, 198), size: 11, weight: FontWeight.w900, color: LabColors.danger);
  p.text(p.t('electron of H', 'H का इलेक्ट्रॉन'), const Offset(211, 198), size: 9, align: TextAlign.left);
}

void _bohr(_Pen p) {
  const n = Offset(105, 105);
  const radii = [30.0, 54.0, 78.0];
  const names = ['K (n = 1)', 'L (n = 2)', 'M (n = 3)'];
  for (final (i, r) in radii.indexed) {
    p.circle(n, r, border: _grey, width: 1.1);
    p.text(names[i], Offset(n.dx, n.dy - r - 7), size: 8, color: LabColors.muted, weight: FontWeight.w700);
  }
  p.circle(n, 16, fillColor: const Color(0xFFFDE68A), border: _amber);
  p.text('11p\n12n', n, size: 7.5, weight: FontWeight.w800, color: LabColors.amber);
  p.electrons(n, radii[0], 2, start: 0);
  p.electrons(n, radii[1], 8, start: math.pi / 8);
  p.electrons(n, radii[2], 1, start: math.pi / 4);

  const x = 205.0;
  p.text(p.t('Sodium (Na)', 'सोडियम (Na)'), const Offset(x, 30), size: 12, weight: FontWeight.w800, align: TextAlign.left);
  p.text(p.t('Atomic number Z = 11', 'परमाणु संख्या Z = 11'), const Offset(x, 50), size: 9.5, align: TextAlign.left);
  final rows = [('K', 2, 2), ('L', 8, 8), ('M', 1, 18)];
  for (final (i, (shell, have, max)) in rows.indexed) {
    p.text(p.t('$shell shell: $have  (max $max)', '$shell कोश: $have  (अधिकतम $max)'), Offset(x, 76 + i * 18.0), size: 9.5, align: TextAlign.left);
  }
  p.rrect(const Rect.fromLTWH(x - 4, 132, 128, 22), 6, fillColor: LabColors.primarySoft);
  p.text(p.t('Distribution: 2, 8, 1', 'वितरण: 2, 8, 1'), const Offset(x + 60, 143), size: 10, weight: FontWeight.w800, color: LabColors.primary);
  p.text(p.t('Max electrons in a shell = 2n²', 'एक कोश में अधिकतम इलेक्ट्रॉन = 2n²'), const Offset(x, 172), size: 9, color: LabColors.muted, align: TextAlign.left, maxWidth: 130);
}

void _goldFoil(_Pen p) {
  // Source.
  p.rrect(const Rect.fromLTWH(6, 82, 48, 36), 6, fillColor: const Color(0xFFE2E8F0), border: _grey);
  p.text(p.t('α source', 'α स्रोत'), const Offset(30, 100), size: 9, weight: FontWeight.w700);
  // Foil: a thin band of atoms, each with a tiny nucleus.
  const foilX = 170.0;
  p.rrect(const Rect.fromLTWH(foilX - 8, 20, 16, 160), 4, fillColor: const Color(0xFFFFF4C2), border: const Color(0xFFD4AF37), width: 1);
  for (var y = 30.0; y < 180; y += 18) {
    p.circle(Offset(foilX, y), 7, border: const Color(0xFFE8D48B), width: 0.8);
    p.circle(Offset(foilX, y), 1.6, fillColor: _red);
  }
  p.text(p.t('Gold foil', 'स्वर्ण पन्नी'), const Offset(foilX, 192), size: 9, weight: FontWeight.w700, color: const Color(0xFF9A7B12));
  // Straight-through paths.
  for (final y in const [60.0, 80.0, 120.0, 140.0]) {
    p.line(Offset(56, y.clamp(88, 112)), Offset(foilX - 10, y), _blue, 1.1);
    p.arrow(Offset(foilX + 10, y), Offset(300, y), _blue, width: 1.1, head: 5);
  }
  // Slightly deflected.
  p.line(const Offset(56, 100), const Offset(foilX, 102), _purple, 1.2);
  p.arrow(const Offset(foilX, 102), const Offset(292, 156), _purple, width: 1.2, head: 5);
  // Bounces back.
  p.line(const Offset(56, 96), Offset(foilX - 1, 93), _red, 1.2);
  p.arrow(Offset(foilX - 1, 93), const Offset(70, 40), _red, width: 1.2, head: 5);

  p.text(p.t('Most pass straight through', 'अधिकांश सीधे निकल जाते हैं'), const Offset(305, 70), size: 9, color: _blue, weight: FontWeight.w700, align: TextAlign.right, maxWidth: 120);
  p.text(p.t('Some are deflected', 'कुछ विक्षेपित होते हैं'), const Offset(300, 172), size: 9, color: _purple, weight: FontWeight.w700, align: TextAlign.right, maxWidth: 120);
  p.text(p.t('Very few bounce back', 'बहुत कम वापस लौटते हैं'), const Offset(20, 24), size: 9, color: _red, weight: FontWeight.w700, align: TextAlign.left, maxWidth: 130);
}

void _tyndall(_Pen p) {
  // Torch.
  p.rrect(const Rect.fromLTWH(4, 84, 34, 18), 4, fillColor: const Color(0xFF334155));
  p.c.drawPath(Path()..moveTo(38, 80)..lineTo(48, 76)..lineTo(48, 110)..lineTo(38, 106)..close(), p.fill(const Color(0xFF475569)));
  p.text(p.t('Torch', 'टॉर्च'), const Offset(24, 120), size: 9, weight: FontWeight.w700);

  void beaker(double left, Color liquid, String title, String note, {required bool scatter}) {
    final glass = Rect.fromLTWH(left, 50, 80, 86);
    p.c.drawRect(Rect.fromLTWH(left, 66, 80, 70), p.fill(liquid));
    if (scatter) {
      // The beam's path lights up inside the colloid.
      p.c.drawPath(
        Path()..moveTo(left, 86)..lineTo(left + 80, 82)..lineTo(left + 80, 106)..lineTo(left, 100)..close(),
        p.fill(const Color(0xFFFFE066).withValues(alpha: 0.85)),
      );
      final rnd = math.Random(3);
      for (var i = 0; i < 26; i++) {
        p.circle(Offset(left + 4 + rnd.nextDouble() * 72, 85 + rnd.nextDouble() * 18), 1.3, fillColor: const Color(0xFFB45309));
      }
    }
    p.c.drawPath(
      Path()..moveTo(glass.left, glass.top)..lineTo(glass.left, glass.bottom)..lineTo(glass.right, glass.bottom)..lineTo(glass.right, glass.top),
      p.stroke(_grey, 1.8),
    );
    p.text(title, Offset(glass.center.dx, 150), size: 9, weight: FontWeight.w800, maxWidth: 110);
    p.text(note, Offset(glass.center.dx, 174), size: 8.5, color: scatter ? _green : LabColors.muted, weight: FontWeight.w700, maxWidth: 120);
  }

  // Faint beam in the air between and through the true solution.
  p.c.drawPath(Path()..moveTo(48, 86)..lineTo(330, 80)..lineTo(330, 108)..lineTo(48, 100)..close(), p.fill(const Color(0xFFFFE066).withValues(alpha: 0.14)));
  beaker(90, const Color(0xFFDBEAFE), p.t('True solution (salt in water)', 'वास्तविक विलयन (नमक + पानी)'), p.t('Beam not seen', 'किरण-पथ नहीं दिखता'), scatter: false);
  beaker(226, const Color(0xFFF1F5F9), p.t('Colloid (milk in water)', 'कोलॉइड (दूध + पानी)'), p.t('Beam path visible', 'किरण-पथ दिखता है'), scatter: true);
}

void _chromatography(_Pen p) {
  // Jar.
  p.c.drawPath(Path()..moveTo(90, 20)..lineTo(90, 196)..lineTo(200, 196)..lineTo(200, 20), p.stroke(_grey, 2));
  p.c.drawRect(const Rect.fromLTWH(91, 172, 108, 23), p.fill(const Color(0xFFBFDBFE)));
  // Paper strip with the wet part tinted.
  const strip = Rect.fromLTWH(128, 14, 34, 172);
  p.c.drawRect(strip, p.fill(Colors.white));
  p.c.drawRect(const Rect.fromLTWH(128, 44, 34, 142), p.fill(const Color(0xFFE0F2FE)));
  p.c.drawRect(strip, p.stroke(_grey, 1));
  p.line(const Offset(110, 14), const Offset(180, 14), LabColors.ink, 2);
  // Solvent front and start line.
  p.dashed(const Offset(124, 44), const Offset(166, 44), _blue, width: 1.2);
  p.line(const Offset(130, 160), const Offset(160, 160), LabColors.muted, 1);
  p.circle(const Offset(145, 160), 3, fillColor: const Color(0xFF1F2937).withValues(alpha: 0.35));
  // Separated colours.
  p.circle(const Offset(145, 128), 6, fillColor: const Color(0xFFFACC15));
  p.circle(const Offset(145, 96), 6, fillColor: const Color(0xFF3B82F6));
  p.circle(const Offset(145, 64), 6, fillColor: const Color(0xFFEF4444));

  p.text(p.t('Solvent front', 'विलायक अग्र'), const Offset(212, 44), size: 9, color: _blue, weight: FontWeight.w700, align: TextAlign.left);
  p.text(p.t('Colours of the ink separate', 'स्याही के रंग अलग हो जाते हैं'), const Offset(212, 96), size: 9, weight: FontWeight.w700, align: TextAlign.left, maxWidth: 120);
  p.arrow(const Offset(208, 96), const Offset(156, 96), LabColors.muted, width: 1, head: 5);
  p.text(p.t('Start line with ink spot (pencil)', 'आरंभ रेखा पर स्याही का बिंदु (पेंसिल से)'), const Offset(212, 158), size: 9, align: TextAlign.left, maxWidth: 120);
  p.arrow(const Offset(208, 160), const Offset(164, 160), LabColors.muted, width: 1, head: 5);
  p.text(p.t('Solvent (water)', 'विलायक (जल)'), const Offset(84, 184), size: 9, color: _blue, weight: FontWeight.w700, align: TextAlign.right);
  p.arrow(const Offset(30, 150), const Offset(30, 60), _blue, width: 1.6);
  p.c.save();
  p.c.translate(18, 105);
  p.c.rotate(-math.pi / 2);
  p.text(p.t('solvent rises', 'विलायक चढ़ता है'), Offset.zero, size: 9, color: _blue, weight: FontWeight.w700);
  p.c.restore();
}

void _periodicTrends(_Pen p) {
  const cell = 14.0, left = 44.0, top = 68.0;
  Color blockOf(int group) => group <= 2
      ? _blue
      : group <= 12
          ? _amber
          : _green;
  for (var period = 1; period <= 7; period++) {
    for (var group = 1; group <= 18; group++) {
      final exists = period == 1 ? (group == 1 || group == 18) : period <= 3 ? (group <= 2 || group >= 13) : true;
      if (!exists) continue;
      final r = Rect.fromLTWH(left + (group - 1) * cell, top + (period - 1) * cell, cell - 1.5, cell - 1.5);
      p.rrect(r, 2, fillColor: blockOf(group).withValues(alpha: 0.25), border: blockOf(group).withValues(alpha: 0.6), width: 0.6);
    }
  }
  const right = left + 18 * cell, bottom = top + 7 * cell;
  // Across a period.
  p.arrow(const Offset(left, top - 10), const Offset(right, top - 10), LabColors.primary, width: 2);
  p.text(p.t('Across a period (left → right)', 'आवर्त में (बाएँ → दाएँ)'), const Offset((left + right) / 2, 10), size: 9.5, weight: FontWeight.w800, color: LabColors.primary, maxWidth: 300);
  p.text(
    p.t('Atomic radius ↓   Ionisation enthalpy ↑   Electronegativity ↑', 'परमाणु त्रिज्या ↓   आयनन एन्थैल्पी ↑   विद्युत-ऋणात्मकता ↑'),
    const Offset((left + right) / 2, 32),
    size: 8.5,
    maxWidth: 320,
    weight: FontWeight.w600,
  );
  // Down a group.
  p.arrow(const Offset(left - 12, top), const Offset(left - 12, bottom), _red, width: 2);
  p.text(p.t('Down a group (top → bottom)', 'वर्ग में (ऊपर → नीचे)'), Offset((left + right) / 2, bottom + 14), size: 9.5, weight: FontWeight.w800, color: _red, maxWidth: 300);
  p.text(
    p.t('Atomic radius ↑   Ionisation enthalpy ↓   Electronegativity ↓', 'परमाणु त्रिज्या ↑   आयनन एन्थैल्पी ↓   विद्युत-ऋणात्मकता ↓'),
    Offset((left + right) / 2, bottom + 32),
    size: 8.5,
    maxWidth: 320,
    weight: FontWeight.w600,
  );
  // Legend.
  final legend = [(_blue, p.t('s-block', 's-ब्लॉक')), (_amber, p.t('d-block', 'd-ब्लॉक')), (_green, p.t('p-block', 'p-ब्लॉक'))];
  for (final (i, (color, name)) in legend.indexed) {
    final x = 70.0 + i * 80;
    p.rrect(Rect.fromLTWH(x, bottom + 50, 12, 12), 2, fillColor: color.withValues(alpha: 0.3), border: color, width: 0.8);
    p.text(name, Offset(x + 17, bottom + 56), size: 9, align: TextAlign.left, weight: FontWeight.w700);
  }
  p.text(p.t('(f-block sits below the table; trends are general, with some exceptions)', '(f-ब्लॉक सारणी के नीचे होता है; प्रवृत्तियाँ सामान्य हैं, कुछ अपवाद हैं)'),
      Offset(p.size.width / 2, bottom + 76), size: 8, color: LabColors.muted, maxWidth: 320);
}

void _vsepr(_Pen p) {
  void bond(Offset a, Offset b, {String kind = 'line'}) {
    switch (kind) {
      case 'wedge':
        final n = Offset(-(b - a).dy, (b - a).dx) / (b - a).distance * 4;
        p.c.drawPath(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx + n.dx, b.dy + n.dy)..lineTo(b.dx - n.dx, b.dy - n.dy)..close(), p.fill(LabColors.ink));
      case 'dash':
        p.dashed(a, b, LabColors.ink, width: 1.6, dash: 3, gap: 2.5);
      default:
        p.line(a, b, LabColors.ink, 2);
    }
  }

  void shape(Offset c, List<(Offset, String)> arms, String centre, String outer, String name, String example, String angle, String hybrid) {
    for (final (dir, kind) in arms) {
      bond(c, c + dir * 30, kind: kind);
      p.circle(c + dir * 34, 6.5, fillColor: const Color(0xFFDCFCE7), border: _green, width: 1);
      p.text(outer, c + dir * 34, size: 6.5, weight: FontWeight.w800, color: _green);
    }
    p.circle(c, 9, fillColor: LabColors.primarySoft, border: LabColors.primary);
    p.text(centre, c, size: 7.5, weight: FontWeight.w800, color: LabColors.primary);
    p.text(name, Offset(c.dx, c.dy + 52), size: 9.5, weight: FontWeight.w800, maxWidth: 108);
    p.text(example, Offset(c.dx, c.dy + 67), size: 9, color: LabColors.muted, weight: FontWeight.w600, maxWidth: 108);
    p.text('$angle · $hybrid', Offset(c.dx, c.dy + 81), size: 9, color: LabColors.secondary, weight: FontWeight.w700, maxWidth: 108);
  }

  Offset dir(double deg) => Offset(math.cos(deg * math.pi / 180), -math.sin(deg * math.pi / 180));
  shape(const Offset(57, 62), [(dir(0), 'line'), (dir(180), 'line')], 'Be', 'Cl', p.t('Linear', 'रैखिक'), 'BeCl₂', '180°', 'sp');
  shape(const Offset(170, 62), [(dir(90), 'line'), (dir(210), 'line'), (dir(330), 'line')], 'B', 'F', p.t('Trigonal planar', 'त्रिकोणीय समतलीय'), 'BF₃', '120°', 'sp²');
  shape(const Offset(283, 62), [(dir(90), 'line'), (dir(200), 'line'), (dir(305), 'wedge'), (dir(335), 'dash')], 'C', 'H', p.t('Tetrahedral', 'चतुष्फलकीय'), 'CH₄',
      '109.5°', 'sp³');
  shape(const Offset(110, 222), [(dir(90), 'line'), (dir(270), 'line'), (dir(180), 'line'), (dir(330), 'wedge'), (dir(20), 'dash')], 'P', 'Cl',
      p.t('Trigonal bipyramidal', 'त्रिकोणीय द्विपिरामिडी'), 'PCl₅', '120°, 90°', 'sp³d');
  shape(const Offset(230, 222), [(dir(90), 'line'), (dir(270), 'line'), (dir(180), 'line'), (dir(0), 'line'), (dir(215), 'wedge'), (dir(35), 'dash')], 'S', 'F',
      p.t('Octahedral', 'अष्टफलकीय'), 'SF₆', '90°', 'sp³d²');
  p.text(p.t('▲ wedge: towards you    - - - dashes: away from you', '▲ वेज: आपकी ओर    - - - डैश: आपसे दूर'), Offset(p.size.width / 2, 322), size: 8.5, color: LabColors.muted, maxWidth: 330);
}

void _daniell(_Pen p) {
  void beaker(double left, Color solution, String label) {
    p.c.drawRect(Rect.fromLTWH(left, 126, 110, 72), p.fill(solution));
    p.c.drawPath(Path()..moveTo(left, 104)..lineTo(left, 198)..lineTo(left + 110, 198)..lineTo(left + 110, 104), p.stroke(_grey, 2));
    p.text(label, Offset(left + 55, 186), size: 9, weight: FontWeight.w700);
  }

  beaker(14, const Color(0xFFE2E8F0), 'ZnSO₄(aq)');
  beaker(216, const Color(0xFF93C5FD), 'CuSO₄(aq)');
  // Electrodes.
  p.rrect(const Rect.fromLTWH(56, 70, 12, 104), 2, fillColor: const Color(0xFF94A3B8), border: const Color(0xFF64748B), width: 1);
  p.rrect(const Rect.fromLTWH(272, 70, 12, 104), 2, fillColor: const Color(0xFFD97745), border: const Color(0xFFB45309), width: 1);
  p.text('Zn', const Offset(46, 84), size: 10, weight: FontWeight.w800, align: TextAlign.right);
  p.text('Cu', const Offset(294, 84), size: 10, weight: FontWeight.w800, align: TextAlign.left);
  // Salt bridge.
  final bridge = Path()
    ..moveTo(104, 160)
    ..lineTo(104, 112)
    ..quadraticBezierTo(104, 94, 122, 94)
    ..lineTo(218, 94)
    ..quadraticBezierTo(236, 94, 236, 112)
    ..lineTo(236, 160);
  p.c.drawPath(bridge, p.stroke(const Color(0xFFCBD5E1), 12));
  p.c.drawPath(bridge, p.stroke(const Color(0xFF94A3B8), 1));
  p.text(p.t('Salt bridge', 'लवण सेतु'), const Offset(170, 84), size: 9, weight: FontWeight.w700, color: LabColors.muted);
  // Wire and voltmeter.
  p.c.drawPath(Path()..moveTo(62, 70)..lineTo(62, 30)..lineTo(154, 30), p.stroke(LabColors.ink, 1.6));
  p.c.drawPath(Path()..moveTo(186, 30)..lineTo(278, 30)..lineTo(278, 70), p.stroke(LabColors.ink, 1.6));
  p.circle(const Offset(170, 30), 16, fillColor: Colors.white, border: LabColors.ink);
  p.text('V', const Offset(170, 30), size: 12, weight: FontWeight.w800);
  p.arrow(const Offset(84, 18), const Offset(136, 18), _blue, width: 1.6, head: 6);
  p.arrow(const Offset(204, 18), const Offset(256, 18), _blue, width: 1.6, head: 6);
  p.text(p.t('e⁻ flow', 'e⁻ प्रवाह'), const Offset(110, 8), size: 8.5, color: _blue, weight: FontWeight.w700);
  p.text(p.t('e⁻ flow', 'e⁻ प्रवाह'), const Offset(230, 8), size: 8.5, color: _blue, weight: FontWeight.w700);
  // Electrode reactions.
  p.text(p.t('Anode (–): oxidation', 'ऐनोड (–): ऑक्सीकरण'), const Offset(69, 214), size: 9.5, weight: FontWeight.w800, color: _red, maxWidth: 140);
  p.text('Zn → Zn²⁺ + 2e⁻', const Offset(69, 232), size: 9.5, weight: FontWeight.w700, maxWidth: 140);
  p.text(p.t('Cathode (+): reduction', 'कैथोड (+): अपचयन'), const Offset(271, 214), size: 9.5, weight: FontWeight.w800, color: _blue, maxWidth: 140);
  p.text('Cu²⁺ + 2e⁻ → Cu', const Offset(271, 232), size: 9.5, weight: FontWeight.w700, maxWidth: 140);
  p.text('Zn(s) + Cu²⁺(aq) → Zn²⁺(aq) + Cu(s)', Offset(p.size.width / 2, 256), size: 9.5, weight: FontWeight.w800, color: LabColors.primary, maxWidth: 330);
}

void _activationEnergy(_Pen p) {
  const origin = Offset(36, 196);
  p.arrow(origin, const Offset(36, 14), LabColors.ink, width: 1.4, head: 6);
  p.arrow(origin, const Offset(330, 196), LabColors.ink, width: 1.4, head: 6);
  p.c.save();
  p.c.translate(16, 105);
  p.c.rotate(-math.pi / 2);
  p.text(p.t('Potential energy', 'स्थितिज ऊर्जा'), Offset.zero, size: 9, weight: FontWeight.w700, color: LabColors.muted, maxWidth: 200);
  p.c.restore();
  p.text(p.t('Reaction coordinate →', 'अभिक्रिया की प्रगति →'), const Offset(190, 212), size: 9, weight: FontWeight.w700, color: LabColors.muted);

  const react = 130.0, prod = 166.0, peak = 40.0, peakCat = 86.0;
  final curve = Path()
    ..moveTo(44, react)
    ..lineTo(90, react)
    ..cubicTo(130, react, 145, peak, 172, peak)
    ..cubicTo(199, peak, 215, prod, 252, prod)
    ..lineTo(320, prod);
  p.c.drawPath(curve, p.stroke(LabColors.primary, 2.4));
  p.dashedPath(
    Path()
      ..moveTo(90, react)
      ..cubicTo(128, react, 146, peakCat, 172, peakCat)
      ..cubicTo(198, peakCat, 214, prod, 252, prod),
    _green,
    width: 2.2,
  );
  p.text(p.t('Reactants', 'अभिकारक'), const Offset(66, react - 12), size: 9, weight: FontWeight.w800);
  p.text(p.t('Products', 'उत्पाद'), const Offset(286, prod + 12), size: 9, weight: FontWeight.w800);
  p.text(p.t('Activated complex', 'सक्रियित संकुल'), const Offset(176, peak - 14), size: 9, weight: FontWeight.w700, color: LabColors.primary);
  // Ea without and with catalyst.
  p.dashed(const Offset(100, peak), const Offset(166, peak), _grey);
  p.dashed(const Offset(124, peakCat), const Offset(166, peakCat), _grey);
  p.arrow(const Offset(104, react), const Offset(104, peak + 2), LabColors.primary, both: true, width: 1.4, head: 5);
  p.text('Ea', const Offset(94, 84), size: 10, weight: FontWeight.w800, color: LabColors.primary, align: TextAlign.right);
  p.arrow(const Offset(128, react), const Offset(128, peakCat + 2), _green, both: true, width: 1.4, head: 5);
  p.text(p.t('Ea (catalyst)', 'Ea (उत्प्रेरक)'), const Offset(176, 114), size: 8.5, weight: FontWeight.w800, color: _green);
  // ΔH.
  p.dashed(const Offset(90, react), const Offset(318, react), _grey);
  p.arrow(const Offset(306, react), const Offset(306, prod - 1), _red, width: 1.4, head: 5);
  p.text(p.t('ΔH < 0 (exothermic)', 'ΔH < 0 (ऊष्माक्षेपी)'), const Offset(300, react - 10), size: 8.5, weight: FontWeight.w800, color: _red, align: TextAlign.right);
  // Legend.
  p.line(const Offset(210, 18), const Offset(232, 18), LabColors.primary, 2.4);
  p.text(p.t('without catalyst', 'उत्प्रेरक के बिना'), const Offset(238, 18), size: 8.5, align: TextAlign.left);
  p.dashed(const Offset(210, 34), const Offset(232, 34), _green, width: 2.2);
  p.text(p.t('with catalyst', 'उत्प्रेरक के साथ'), const Offset(238, 34), size: 8.5, align: TextAlign.left);
}

void _micelle(_Pen p) {
  p.rrect(const Rect.fromLTWH(4, 4, 228, 212), 12, fillColor: const Color(0xFFE0F2FE));
  p.text(p.t('Water', 'पानी'), const Offset(30, 18), size: 9, color: _blue, weight: FontWeight.w800);
  const c = Offset(118, 112);
  p.circle(c, 38, fillColor: const Color(0xFFFDE68A), border: const Color(0xFFD97706), width: 1);
  p.text(p.t('Oily dirt', 'तैलीय मैल'), c, size: 9, weight: FontWeight.w800, color: LabColors.amber);
  const count = 14;
  for (var i = 0; i < count; i++) {
    final a = 2 * math.pi * i / count;
    final u = Offset(math.cos(a), math.sin(a));
    final n = Offset(-u.dy, u.dx);
    // Zig-zag carbon tail from inside the oil out to the head.
    final tail = Path()..moveTo(c.dx + u.dx * 22, c.dy + u.dy * 22);
    for (var k = 1; k <= 8; k++) {
      final r = 22 + k * 5.0;
      final o = c + u * r + n * (k.isOdd ? 3 : -3);
      tail.lineTo(o.dx, o.dy);
    }
    p.c.drawPath(tail, p.stroke(const Color(0xFF475569), 1.3));
    final head = c + u * 68;
    p.circle(head, 6.5, fillColor: _red, border: Colors.white, width: 1);
    p.text('–', head, size: 9, weight: FontWeight.w900, color: Colors.white);
  }
  // Legend.
  p.circle(const Offset(250, 56), 6.5, fillColor: _red);
  p.text('–', const Offset(250, 56), size: 9, weight: FontWeight.w900, color: Colors.white);
  p.text(p.t('Ionic head: likes water (hydrophilic)', 'आयनिक सिरा: पानी पसंद (जलरागी)'), const Offset(262, 56), size: 8.5, align: TextAlign.left, maxWidth: 76, weight: FontWeight.w600);
  final zig = Path()..moveTo(242, 120);
  for (var k = 1; k <= 4; k++) {
    zig.lineTo(242 + k * 4.0, 120 + (k.isOdd ? -3 : 3));
  }
  p.c.drawPath(zig, p.stroke(const Color(0xFF475569), 1.3));
  p.text(p.t('Carbon tail: likes oil (hydrophobic)', 'कार्बन पूँछ: तेल पसंद (जलविरागी)'), const Offset(262, 120), size: 8.5, align: TextAlign.left, maxWidth: 76, weight: FontWeight.w600);
  p.text(p.t('Micelle', 'मिसेल'), const Offset(118, 204), size: 10, weight: FontWeight.w800, color: LabColors.primary);
}

void _equilibrium(_Pen p) {
  const origin = Offset(36, 180);
  p.arrow(origin, const Offset(36, 12), LabColors.ink, width: 1.4, head: 6);
  p.arrow(origin, const Offset(330, 180), LabColors.ink, width: 1.4, head: 6);
  p.c.save();
  p.c.translate(16, 96);
  p.c.rotate(-math.pi / 2);
  p.text(p.t('Concentration', 'सांद्रता'), Offset.zero, size: 9, weight: FontWeight.w700, color: LabColors.muted, maxWidth: 200);
  p.c.restore();
  p.text(p.t('Time →', 'समय →'), const Offset(300, 194), size: 9, weight: FontWeight.w700, color: LabColors.muted);

  const teq = 190.0;
  p.c.drawRect(const Rect.fromLTRB(teq, 14, 326, 179), p.fill(_green.withValues(alpha: 0.07)));
  p.dashed(const Offset(teq, 20), const Offset(teq, 180), _green, width: 1.4);
  p.text(p.t('Equilibrium reached', 'साम्यावस्था स्थापित'), const Offset(teq, 194), size: 9, weight: FontWeight.w800, color: _green);
  p.c.drawPath(
    Path()
      ..moveTo(38, 30)
      ..cubicTo(90, 90, 140, 104, teq, 106)
      ..lineTo(326, 106),
    p.stroke(_red, 2.4),
  );
  p.c.drawPath(
    Path()
      ..moveTo(38, 178)
      ..cubicTo(90, 150, 140, 134, teq, 132)
      ..lineTo(326, 132),
    p.stroke(_blue, 2.4),
  );
  p.text(p.t('Reactants', 'अभिकारक'), const Offset(84, 52), size: 9, weight: FontWeight.w800, color: _red, align: TextAlign.left);
  p.text(p.t('Products', 'उत्पाद'), const Offset(88, 170), size: 9, weight: FontWeight.w800, color: _blue, align: TextAlign.left);
  p.text(p.t('Forward rate = backward rate; concentrations constant', 'अग्र दर = पश्च दर; सांद्रताएँ स्थिर'), const Offset(258, 50), size: 8.5, weight: FontWeight.w700, color: _green, maxWidth: 124);
}
