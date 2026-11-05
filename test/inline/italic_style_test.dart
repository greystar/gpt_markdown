import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _bodyStyle = TextStyle(
  color: Colors.white,
  fontSize: 18,
  fontFamily: 'Roboto',
);

Future<void> _pump(
  WidgetTester tester, {
  String text = 'before *emphasis* after',
  GptMarkdownStyleSheet? widgetSheet,
  GptMarkdownStyleSheet? themeSheet,
  bool inheritedTheme = false,
}) async {
  final theme = GptMarkdownThemeData(
    brightness: Brightness.light,
    styleSheet: themeSheet,
  );
  Widget child = GptMarkdown(
    text,
    style: _bodyStyle,
    styleSheet: widgetSheet,
    isStreaming: false,
  );
  if (inheritedTheme) {
    child = GptMarkdownTheme(gptThemeData: theme, child: child);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: inheritedTheme ? [] : [theme]),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

TextStyle _styleOf(WidgetTester tester, String text) {
  final matches = <TextSpan>[];
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      if (span.text == text) matches.add(span);
      span.children?.forEach(visit);
    }
  }

  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    visit(rich.text);
  }
  return matches.single.style!;
}

void main() {
  group('italic style sheet contract', () {
    const theme = GptMarkdownStyleSheet(
      italic: TextStyle(color: Colors.grey, fontSize: 20),
    );
    const widget = GptMarkdownStyleSheet(
      italic: TextStyle(color: Colors.red, letterSpacing: 2),
    );

    test('merges text properties with widget precedence', () {
      final merged = widget.merge(theme).italic!;
      expect(merged.color, Colors.red);
      expect(merged.fontSize, 20);
      expect(merged.letterSpacing, 2);
      expect(widget.merge(null), widget);
      expect(widget.merge(const GptMarkdownStyleSheet()), widget);
      expect(const GptMarkdownStyleSheet().merge(theme), theme);
    });

    test('inherit false replaces the theme style', () {
      const replacement = TextStyle(inherit: false, color: Colors.red);
      final merged = const GptMarkdownStyleSheet(
        italic: replacement,
      ).merge(theme);
      expect(merged.italic, replacement);
      expect(merged.italic!.fontSize, isNull);
    });

    test('copy, equality and hash include italic', () {
      expect(theme.copyWith(), theme);
      expect(theme.copyWith(italic: widget.italic), widget);
      expect(theme, isNot(widget));
      expect(theme, isNot(const GptMarkdownStyleSheet()));
      final copy = GptMarkdownStyleSheet(italic: theme.italic);
      expect(copy, theme);
      expect(copy.hashCode, theme.hashCode);
      expect({theme, copy, widget}, hasLength(2));
    });

    test('interpolates italic including null endpoints', () {
      const a = GptMarkdownStyleSheet(
        italic: TextStyle(color: Colors.red, fontSize: 20),
      );
      const b = GptMarkdownStyleSheet(
        italic: TextStyle(color: Colors.blue, fontSize: 30),
      );
      final start = GptMarkdownStyleSheet.lerp(a, b, 0)!.italic!;
      final end = GptMarkdownStyleSheet.lerp(a, b, 1)!.italic!;
      expect(start.color!.toARGB32(), Colors.red.toARGB32());
      expect(start.fontSize, 20);
      expect(end.color!.toARGB32(), Colors.blue.toARGB32());
      expect(end.fontSize, 30);
      final middle = GptMarkdownStyleSheet.lerp(a, b, 0.5)!.italic!;
      expect(middle.fontSize, 25);
      expect(middle.color, Color.lerp(Colors.red, Colors.blue, 0.5));
      expect(
        GptMarkdownStyleSheet.lerp(null, b, 0.5)!.italic,
        TextStyle.lerp(null, b.italic, 0.5),
      );
      expect(
        GptMarkdownStyleSheet.lerp(a, null, 0.5)!.italic,
        TextStyle.lerp(a.italic, null, 0.5),
      );
      expect(GptMarkdownStyleSheet.lerp(null, null, 0.5), isNull);
    });
  });

  testWidgets('unset style preserves default emphasis and surrounding text', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      _styleOf(tester, 'emphasis'),
      _styleOf(tester, 'before ').copyWith(fontStyle: FontStyle.italic),
    );
    expect(_styleOf(tester, ' after'), _styleOf(tester, 'before '));
  });

  testWidgets('colour override keeps italic and surrounding font properties', (
    tester,
  ) async {
    await _pump(
      tester,
      widgetSheet: const GptMarkdownStyleSheet(
        italic: TextStyle(color: Colors.grey),
      ),
    );
    final italic = _styleOf(tester, 'emphasis');
    expect(italic.color, Colors.grey);
    expect(italic.fontStyle, FontStyle.italic);
    expect(italic.fontSize, 18);
    expect(italic.fontFamily, 'Roboto');
    for (final text in ['before ', ' after']) {
      expect(_styleOf(tester, text).color, Colors.white);
      expect(_styleOf(tester, text).fontStyle, isNot(FontStyle.italic));
    }
  });

  testWidgets('widget properties override theme properties individually', (
    tester,
  ) async {
    await _pump(
      tester,
      themeSheet: const GptMarkdownStyleSheet(
        italic: TextStyle(color: Colors.grey, fontSize: 24),
      ),
      widgetSheet: const GptMarkdownStyleSheet(italic: TextStyle(fontSize: 28)),
    );
    final italic = _styleOf(tester, 'emphasis');
    expect(italic.color, Colors.grey);
    expect(italic.fontSize, 28);
    expect(italic.fontStyle, FontStyle.italic);
  });

  testWidgets('normal fontStyle cancels italic', (tester) async {
    await _pump(
      tester,
      widgetSheet: const GptMarkdownStyleSheet(
        italic: TextStyle(color: Colors.grey, fontStyle: FontStyle.normal),
      ),
    );
    expect(_styleOf(tester, 'emphasis').fontStyle, FontStyle.normal);
    expect(_styleOf(tester, 'emphasis').color, Colors.grey);
  });

  testWidgets('inherit false replaces the surrounding style', (tester) async {
    const replacement = TextStyle(
      inherit: false,
      color: Colors.grey,
      fontSize: 22,
      fontStyle: FontStyle.normal,
    );
    await _pump(
      tester,
      widgetSheet: const GptMarkdownStyleSheet(italic: replacement),
    );
    expect(_styleOf(tester, 'emphasis'), replacement);
  });

  for (final syntax in [
    '*emphasis*',
    '_emphasis_',
    '<i>emphasis</i>',
    '<em>emphasis</em>',
    '<cite>emphasis</cite>',
    '<var>emphasis</var>',
  ]) {
    testWidgets('styles $syntax', (tester) async {
      await _pump(
        tester,
        text: syntax,
        widgetSheet: const GptMarkdownStyleSheet(
          italic: TextStyle(color: Colors.grey),
        ),
      );
      expect(_styleOf(tester, 'emphasis').color, Colors.grey);
      expect(_styleOf(tester, 'emphasis').fontStyle, FontStyle.italic);
    });
  }

  for (final prefix in ['## ', '> ']) {
    testWidgets('preserves surrounding style inside $prefix', (tester) async {
      await _pump(
        tester,
        text: '${prefix}before *emphasis* after',
        widgetSheet: const GptMarkdownStyleSheet(
          italic: TextStyle(color: Colors.grey),
        ),
      );
      final surrounding = _styleOf(tester, 'before ');
      expect(
        _styleOf(tester, 'emphasis'),
        surrounding.copyWith(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    });
  }

  for (final source in ['widget', 'extension', 'inherited theme']) {
    testWidgets('$source changes refresh cached spans with unchanged text', (
      tester,
    ) async {
      final useWidget = source == 'widget';
      for (final color in [Colors.red, Colors.blue, null]) {
        final sheet = color == null
            ? null
            : GptMarkdownStyleSheet(italic: TextStyle(color: color));
        await _pump(
          tester,
          widgetSheet: useWidget ? sheet : null,
          themeSheet: useWidget ? null : sheet,
          inheritedTheme: source == 'inherited theme',
        );
        expect(_styleOf(tester, 'emphasis').color, color ?? Colors.white);
        expect(_styleOf(tester, 'emphasis').fontStyle, FontStyle.italic);
      }
    });
  }
}
