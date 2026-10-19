import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_spliter/main.dart';
import 'package:pdf_spliter/models/split_range.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'Launch screen and HomeScreen render Plexus Labs & Systems LTD branding and 245-256 demo',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SlicePdfStudioApp());

    // Verify Launch Screen shows ownership recognition
    expect(find.text('SlicePDF Studio'), findsOneWidget);
    expect(find.text('Plexus Labs & Systems LTD'), findsOneWidget);

    // Advance past the 2100ms splash timer to HomeScreen
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();

    expect(find.text('Select PDF File'), findsOneWidget);
    expect(find.text('Try 300-Page Demo (p. 245–256)'), findsOneWidget);

    // Open Settings & About page and verify Plexus Labs & Systems LTD branding
    await tester.tap(find.byTooltip('Settings & About'));
    await tester.pumpAndSettle();
    expect(find.text('Built by Plexus Labs & Systems LTD'), findsOneWidget);
  });

  test('SplitRange 245 to 256 computes exact 12 pages and handles exclusions',
      () {
    const range = SplitRange(
      id: 'r1',
      startPage: 245,
      endPage: 256,
      customTitle: 'Chapter 12',
    );

    expect(range.totalSpanCount, 12);
    expect(range.activePageCount, 12);
    expect(range.includedPages.first, 245);
    expect(range.includedPages.last, 256);
    expect(
      range.suggestedFileName('Book.pdf'),
      'Chapter_12_p245-256',
    );

    final withExclusion = range.copyWith(excludedPages: {250});
    expect(withExclusion.activePageCount, 11);
    expect(withExclusion.includedPages.contains(250), isFalse);
  });
}
