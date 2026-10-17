import 'package:bouncr/app.dart';
import 'package:bouncr/domain/app_user.dart';
import 'package:bouncr/domain/ticket.dart';
import 'package:bouncr/ui/tickets/scanner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../fakes.dart';

const guest = AppUser(uid: 'guest', email: 'guest@uni.pl', displayName: 'Guest');

void main() {
  late FakeEventRepository events;
  late FakeTicketRepository tickets;

  setUp(() {
    events = FakeEventRepository([sampleEvent(id: 'e1', ownerId: 'org', capacity: 2, ticketsIssued: 0)]);
    tickets = FakeTicketRepository(events: events, currentUid: () => guest.uid);
  });

  Future<void> openEvent(WidgetTester tester) async {
    await tester.pumpWidget(BouncrApp(
      authRepository: FakeAuthRepository(signedIn: guest),
      eventRepository: events,
      ticketRepository: tickets,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI Club Workshop'));
    await tester.pumpAndSettle();
  }

  testWidgets('RSVP shows a QR ticket carrying the signed code', (tester) async {
    await openEvent(tester);
    expect(find.byKey(const Key('get_ticket')), findsOneWidget);

    await tester.tap(find.byKey(const Key('get_ticket')));
    await tester.pumpAndSettle();

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(find.text('Show this QR code at the door'), findsOneWidget);
    expect(tickets.tickets.values.single.code, startsWith('BNCR1.e1_guest.'));
    expect(qr, isNotNull);
  });

  testWidgets('the organiser sees the scanner button instead of RSVP', (tester) async {
    await tester.pumpWidget(BouncrApp(
      authRepository: FakeAuthRepository(
          signedIn: const AppUser(uid: 'org', email: 'org@uni.pl')),
      eventRepository: events,
      ticketRepository: tickets,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI Club Workshop'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scan_tickets')), findsOneWidget);
    expect(find.byKey(const Key('get_ticket')), findsNothing);
  });

  testWidgets('"Tickets" filter lists my tickets', (tester) async {
    await tickets.issue('e1');
    await tester.pumpWidget(BouncrApp(
      authRepository: FakeAuthRepository(signedIn: guest),
      eventRepository: events,
      ticketRepository: tickets,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();
    expect(find.text('AI Club Workshop'), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
  });

  group('ScannerViewModel', () {
    test('admits once, then reports already used', () async {
      await tickets.issue('e1');
      final code = tickets.tickets.values.single.code;
      var now = DateTime(2026, 10, 20, 18);
      final vm = ScannerViewModel(tickets, eventId: 'e1', clock: () => now);

      await vm.onCode(code);
      expect(vm.lastResult!.outcome, ScanOutcome.admitted);
      expect(vm.admittedCount, 1);

      now = now.add(const Duration(seconds: 10));
      await vm.onCode(code);
      expect(vm.lastResult!.outcome, ScanOutcome.alreadyUsed);
      expect(vm.admittedCount, 1);
    });

    test('ignores the camera repeating the same code within a few seconds', () async {
      await tickets.issue('e1');
      final code = tickets.tickets.values.single.code;
      var now = DateTime(2026, 10, 20, 18);
      final vm = ScannerViewModel(tickets, eventId: 'e1', clock: () => now);

      await vm.onCode(code);
      now = now.add(const Duration(milliseconds: 300));
      await vm.onCode(code);
      await vm.onCode(code);

      expect(tickets.validateCalls, 1);
      expect(vm.lastResult!.outcome, ScanOutcome.admitted);
    });

    test('a forged code is invalid', () async {
      final vm = ScannerViewModel(tickets, eventId: 'e1');
      await vm.onCode('BNCR1.e1_guest.forged-signature-123456789');
      expect(vm.lastResult!.outcome, ScanOutcome.invalid);
    });
  });
}
