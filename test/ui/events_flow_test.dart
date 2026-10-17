import 'package:bouncr/app.dart';
import 'package:bouncr/domain/app_user.dart';
import 'package:bouncr/ui/events/event_form_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

const me = AppUser(uid: 'me', email: 'anna@uni.pl', displayName: 'Anna');

Future<void> pumpApp(WidgetTester tester, FakeEventRepository events) async {
  await tester.pumpWidget(BouncrApp(
    authRepository: FakeAuthRepository(signedIn: me),
    eventRepository: events,
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the list shows upcoming events with seats left', (tester) async {
    await pumpApp(tester, FakeEventRepository([sampleEvent()]));

    expect(find.text('AI Club Workshop'), findsOneWidget);
    expect(find.text('28 seats left'), findsOneWidget);
  });

  testWidgets('an empty list shows a helpful message', (tester) async {
    await pumpApp(tester, FakeEventRepository());
    expect(find.text('No upcoming events yet'), findsOneWidget);
  });

  testWidgets('"My events" shows only events I organise', (tester) async {
    await pumpApp(
      tester,
      FakeEventRepository([
        sampleEvent(id: 'a', title: 'Not mine'),
        sampleEvent(id: 'b', title: 'My hackathon', ownerId: 'me'),
      ]),
    );
    await tester.tap(find.text('My events'));
    await tester.pumpAndSettle();

    expect(find.text('My hackathon'), findsOneWidget);
    expect(find.text('Not mine'), findsNothing);
  });

  testWidgets('only the organiser sees the edit button', (tester) async {
    await pumpApp(
      tester,
      FakeEventRepository([
        sampleEvent(id: 'a', title: 'Not mine'),
        sampleEvent(id: 'b', title: 'My hackathon', ownerId: 'me'),
      ]),
    );

    await tester.tap(find.text('Not mine'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit_event')), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('My hackathon'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit_event')), findsOneWidget);
  });

  testWidgets('the form validates before saving', (tester) async {
    final events = FakeEventRepository();
    await pumpApp(tester, events);

    await tester.tap(find.byKey(const Key('new_event')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('event_save')));
    await tester.tap(find.byKey(const Key('event_save')));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Location is required'), findsOneWidget);
    expect(find.text('Pick a date and time'), findsOneWidget);
    expect(events.all, isEmpty);
  });

  test('saving a new event stores it with me as the owner', () async {
    final events = FakeEventRepository();
    final vm = EventFormViewModel(events, uid: 'me')
      ..onTitleChanged('  Cloud Meetup ')
      ..onLocationChanged('Lab 2')
      ..onStartsAtChanged(DateTime.now().add(const Duration(days: 2)))
      ..onCapacityChanged('25');

    final id = await vm.save();

    expect(id, isNotNull);
    expect(events.all.single.ownerId, 'me');
    expect(events.all.single.title, 'Cloud Meetup');
    expect(events.all.single.ticketsIssued, 0);
  });

  test('editing keeps the owner and the seat counter', () async {
    final original = sampleEvent(ownerId: 'me', ticketsIssued: 12);
    final events = FakeEventRepository([original]);
    final vm = EventFormViewModel(events, uid: 'me', original: original)
      ..onCapacityChanged('10');

    expect(await vm.save(), isNull, reason: 'capacity below issued tickets');
    expect(vm.capacityError, isNotNull);

    vm.onCapacityChanged('60');
    expect(await vm.save(), original.id);
    expect(events.all.single.capacity, 60);
    expect(events.all.single.ticketsIssued, 12);
    expect(events.all.single.ownerId, 'me');
  });
}
