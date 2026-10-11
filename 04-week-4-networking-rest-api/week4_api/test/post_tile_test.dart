import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week4_api/data/models/post.dart';
import 'package:week4_api/widgets/post_tile.dart';

void main() {
  testWidgets('PostTile menampilkan id, title, dan body', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PostTile(
          post: Post(userId: 1, id: 3, title: 'Judul', body: 'Isi'),
        ),
      ),
    ));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Judul'), findsOneWidget);
    expect(find.text('Isi'), findsOneWidget);
  });
}