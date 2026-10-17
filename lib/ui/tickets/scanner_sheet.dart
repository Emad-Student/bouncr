import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../data/ticket_repository.dart';
import '../../domain/event.dart';
import '../../domain/ticket.dart';
import '../theme.dart';
import '../widgets/form_widgets.dart';
import '../widgets/formatting.dart';
import 'scanner_view_model.dart';

/// Opens the door scanner as a full-height sheet on top of the event detail.
Future<void> showScannerSheet(BuildContext context, Event event) {
  final repo = context.read<TicketRepository>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => ScannerViewModel(repo, eventId: event.id),
      child: _ScannerSheet(event: event),
    ),
  );
}

class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet({required this.event});

  final Event event;

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  final _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _manual = TextEditingController();

  @override
  void dispose() {
    _camera.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _check(String code, {bool manual = false}) async {
    final vm = context.read<ScannerViewModel>();
    await vm.onCode(code, manual: manual);
    final result = vm.lastResult;
    if (result == null) return;
    if (result.isAdmitted) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScannerViewModel>();
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Door check-in', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(widget.event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              _Counter(count: vm.admittedCount),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(fit: StackFit.expand, children: [
                  MobileScanner(
                    controller: _camera,
                    onDetect: (capture) {
                      final code = capture.barcodes.firstOrNull?.rawValue;
                      if (code != null) _check(code);
                    },
                    errorBuilder: (context, error) => const _CameraUnavailable(),
                  ),
                  const _Viewfinder(),
                  if (vm.isChecking)
                    const ColoredBox(
                      color: Colors.black38,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            if (vm.lastResult != null) _ResultBanner(result: vm.lastResult!),
            if (vm.error != null) ErrorBanner(vm.error!),
            const SizedBox(height: 14),
            Text('Camera not working? Enter the code manually:', style: text.bodySmall),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('manual_code'),
                  controller: _manual,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'BNCR1.…',
                    isDense: true,
                  ),
                  onSubmitted: (v) => _check(v, manual: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('manual_check'),
                tooltip: 'Check code',
                onPressed: vm.isChecking ? null : () => _check(_manual.text, manual: true),
                icon: const Icon(Icons.check),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, subtitle) = switch (result.outcome) {
      ScanOutcome.admitted => (
          BouncrColors.valid,
          Icons.check_circle,
          "You're in!",
          'Welcome, ${result.attendeeName ?? 'guest'}',
        ),
      ScanOutcome.alreadyUsed => (
          BouncrColors.invalid,
          Icons.cancel,
          'Already used',
          '${result.attendeeName ?? 'This ticket'} checked in'
              '${result.usedAt != null ? ' at ${formatFullDate(result.usedAt!)}' : ' before'}',
        ),
      ScanOutcome.cancelled => (
          BouncrColors.invalid,
          Icons.cancel,
          'Ticket cancelled',
          'This ticket was cancelled by its owner',
        ),
      ScanOutcome.wrongEvent => (
          BouncrColors.warning,
          Icons.warning_amber_rounded,
          'Wrong event',
          'This ticket belongs to another event',
        ),
      ScanOutcome.invalid => (
          BouncrColors.invalid,
          Icons.gpp_bad,
          'Invalid ticket',
          'Not a genuine Bouncr ticket',
        ),
    };
    return Container(
      key: Key('scan_result_${result.outcome.name}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ]),
        ),
      ]),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.how_to_reg, size: 18),
      label: Text('$count in'),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.65,
          heightFactor: 0.65,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Camera unavailable.\nAllow camera access or use manual entry below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
