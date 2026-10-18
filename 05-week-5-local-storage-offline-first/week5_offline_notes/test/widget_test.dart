import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:week5_offline_notes/data/local/note.dart';
import 'package:week5_offline_notes/data/note_providers.dart';
import 'package:week5_offline_notes/main.dart';

class _FakeNotesNotifier extends NotesNotifier {
  @override
  Future<List<Note>> build() async => [];
}

void main() {
  testWidgets('Smoke test: NotesPage renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesProvider.overrideWith(_FakeNotesNotifier.new),
          dirtyCountProvider.overrideWith((ref) => 0),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.text('Catatan Offline'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
