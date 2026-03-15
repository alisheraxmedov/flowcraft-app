import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/overlays/node_toolbar_widget.dart';

void main() {
  testWidgets('NodeToolbarWidget renders and taps', (tester) async {
    bool deleted = false;
    bool duplicated = false;
    bool renamed = false;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(children: [
      NodeToolbarWidget(
        position: const Offset(100, 100),
        onDelete: () => deleted = true,
        onDuplicate: () => duplicated = true,
        onRename: () => renamed = true,
      )
    ]))));
    
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.tap(find.text('Copy'));
    await tester.pump();
    await tester.tap(find.text('Rename'));
    await tester.pump();
    
    expect(deleted, isTrue);
    expect(duplicated, isTrue);
    expect(renamed, isTrue);
  });
}
