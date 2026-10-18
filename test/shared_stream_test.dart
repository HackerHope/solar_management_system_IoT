import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:solar_iot_project/services/shared_stream.dart";

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  test("stream returns the same instance every time (so StreamBuilder does not resubscribe)", () {
    final shared = SharedStream<int>(() => const Stream<int>.empty());
    expect(identical(shared.stream, shared.stream), isTrue);
  });

  test("the upstream factory runs once however many listeners there are", () async {
    var calls = 0;
    final src = StreamController<int>.broadcast();
    final shared = SharedStream<int>(() {
      calls++;
      return src.stream;
    });
    final a = shared.stream.listen((_) {});
    final b = shared.stream.listen((_) {});
    await pump();
    expect(calls, 1);
    await a.cancel();
    await b.cancel();
    shared.dispose();
    await src.close();
  });

  test("a late listener immediately receives the latest value, then live updates", () async {
    final src = StreamController<int>.broadcast();
    final shared = SharedStream<int>(() => src.stream);
    final a = <int>[];
    final subA = shared.stream.listen(a.add);
    src.add(1);
    src.add(2);
    await pump();

    final b = <int>[];
    final subB = shared.stream.listen(b.add);
    await pump();
    expect(a, [1, 2]);
    expect(b, [2]);

    src.add(3);
    await pump();
    expect(a, [1, 2, 3]);
    expect(b, [2, 3]);

    await subA.cancel();
    await subB.cancel();
    shared.dispose();
    await src.close();
  });

  test("errors reach listeners and the stream keeps working", () async {
    final src = StreamController<int>.broadcast();
    final shared = SharedStream<int>(() => src.stream);
    final values = <int>[];
    final errors = <Object>[];
    final sub = shared.stream.listen(values.add, onError: errors.add);
    src.addError("boom");
    src.add(5);
    await pump();
    expect(errors, ["boom"]);
    expect(values, [5]);
    await sub.cancel();
    shared.dispose();
    await src.close();
  });

  test("keeps the connection during the grace period, then closes it and forgets the value", () async {
    var calls = 0;
    var cancelled = false;
    final src = StreamController<int>.broadcast(onCancel: () => cancelled = true);
    final shared = SharedStream<int>(() {
      calls++;
      return src.stream;
    }, grace: const Duration(milliseconds: 30));

    final sub = shared.stream.listen((_) {});
    src.add(1);
    await pump();
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(shared.isConnected, isTrue); // still within grace
    expect(cancelled, isFalse);

    // coming back within grace: no new upstream, cached value replayed
    final again = <int>[];
    final sub2 = shared.stream.listen(again.add);
    await pump();
    expect(calls, 1);
    expect(again, [1]);
    await sub2.cancel();

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(shared.isConnected, isFalse);
    expect(cancelled, isTrue);

    // a new listener starts a fresh connection and gets no stale replay
    final fresh = <int>[];
    final sub3 = shared.stream.listen(fresh.add);
    await pump();
    expect(calls, 2);
    expect(fresh, isEmpty);
    await sub3.cancel();
    shared.dispose();
    await src.close();
  });

  test("dispose closes listeners", () async {
    final src = StreamController<int>.broadcast();
    final shared = SharedStream<int>(() => src.stream);
    var done = false;
    shared.stream.listen((_) {}, onDone: () => done = true);
    await pump();
    shared.dispose();
    await pump();
    expect(done, isTrue);
    await src.close();
  });

  group("the flicker bug", () {
    testWidgets("with a shared stream a rebuild keeps the data on screen", (tester) async {
      final src = StreamController<int>.broadcast();
      final shared = SharedStream<int>(() => src.stream, grace: const Duration(milliseconds: 10));
      Widget app() => MaterialApp(
            home: StreamBuilder<int>(
              stream: shared.stream,
              builder: (c, s) => Text(s.hasData ? "value ${s.data}" : "no data"),
            ),
          );

      await tester.pumpWidget(app());
      src.add(1);
      await tester.pump();
      expect(find.text("value 1"), findsOneWidget);

      await tester.pumpWidget(app()); // parent rebuild
      expect(find.text("value 1"), findsOneWidget); // not blanked

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 30));
      shared.dispose();
      await src.close();
    });

    testWidgets("creating a new stream on every build blanks the data (the old behaviour)", (tester) async {
      final controllers = <StreamController<int>>[];
      Stream<int> fresh() {
        final c = StreamController<int>.broadcast();
        controllers.add(c);
        return c.stream;
      }

      Widget app() => MaterialApp(
            home: Builder(
              builder: (context) => StreamBuilder<int>(
                stream: fresh(), // new stream object each build
                builder: (c, s) => Text(s.hasData ? "value ${s.data}" : "no data"),
              ),
            ),
          );

      await tester.pumpWidget(app());
      controllers.last.add(1);
      await tester.pump();
      expect(find.text("value 1"), findsOneWidget);

      await tester.pumpWidget(app()); // rebuild resubscribes to a new, empty stream
      await tester.pump();
      expect(find.text("no data"), findsOneWidget); // the flicker

      await tester.pumpWidget(const SizedBox());
      for (final c in controllers) {
        await c.close();
      }
    });
  });
}
