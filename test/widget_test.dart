import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joga_contra/main.dart';

void main() {
  testWidgets('opens the home screen and navigates to search', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const JogaContraApp());
    await tester.pump();
    expect(find.text('Seu time entra em campo. ⚽'), findsOneWidget);

    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();
    expect(find.text('Tem jogo esperando pelo seu time.'), findsOneWidget);
    expect(find.text('Real Amigos FC'), findsWidgets);
  });

  testWidgets('interest can be confirmed into a scheduled match', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const JogaContraApp());
    await tester.pump();
    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ver detalhes').first,
      280,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(find.text('Ver detalhes').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenho interesse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim, tenho interesse'));
    await tester.pumpAndSettle();
    expect(find.text('Quase tudo pronto!'), findsOneWidget);
  });
}
