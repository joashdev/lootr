import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/more/settings/profile_screen.dart';

void main() {
  testWidgets('saves profile changes without changing ledger currencies', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'demo-user-1',
            displayName: const Value('Sample User'),
          ),
        );
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'local-user-1',
            displayName: const Value('Original Name'),
            email: const Value('user@example.test'),
            locale: const Value('en-PH'),
            timezone: const Value('Asia/Manila'),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'personal-cash',
            ownerUserId: 'local-user-1',
            name: 'Cash',
            accountType: 'cash',
            currencyCode: const Value('PHP'),
            balance: const Value(125.50),
          ),
        );

    Widget buildApp() => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    final nameField = find.widgetWithText(TextFormField, 'Display name');
    expect(find.text('Original Name'), findsOneWidget);
    expect(find.text('user@example.test'), findsOneWidget);
    await tester.enterText(nameField, '  Updated Name  ');
    await tester.tap(find.byKey(const ValueKey('profile-currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Profile saved.'), findsOneWidget);

    final people = await db.select(db.users).get();
    final personal = people.singleWhere((row) => row.id == 'local-user-1');
    expect(personal.displayName, 'Updated Name');
    expect(personal.currencyCode, 'USD');
    expect(personal.timezone, 'Asia/Manila');
    expect(personal.locale, 'en-PH');
    expect(personal.email, 'user@example.test');
    expect(
      people.singleWhere((row) => row.id == 'demo-user-1').displayName,
      'Sample User',
    );
    final account = await db.select(db.accounts).getSingle();
    expect(account.currencyCode, 'PHP');
    expect(account.balance, 125.50);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('Updated Name'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('Asia/Manila'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
