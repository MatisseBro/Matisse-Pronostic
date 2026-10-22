import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/viewmodels/auth_view_model.dart';

void main() {
  testWidgets('affiche la connexion quand l’utilisateur est déconnecté',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Matimatch'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
  });
}
