import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shows a bottom sheet with two wheels (minutes: 0-59, seconds: 0-59)
/// allowing the user to select an image display duration. Clamped to minimum 1 second.
Future<Duration?> showDurationPickerSheet({
  required BuildContext context,
  required Duration initialDuration,
}) {
  return showModalBottomSheet<Duration>(
    context: context,
    backgroundColor: const Color(0xFF1E143C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DurationPickerSheet(initialDuration: initialDuration),
  );
}

class DurationPickerSheet extends StatefulWidget {
  final Duration initialDuration;

  const DurationPickerSheet({
    super.key,
    required this.initialDuration,
  });

  @override
  State<DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<DurationPickerSheet> {
  late int _selectedMinutes;
  late int _selectedSeconds;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _secondController;

  @override
  void initState() {
    super.initState();
    final totalSec = widget.initialDuration.inSeconds;
    _selectedMinutes = (totalSec ~/ 60).clamp(0, 59);
    _selectedSeconds = (totalSec % 60).clamp(0, 59);
    if (_selectedMinutes == 0 && _selectedSeconds == 0) {
      _selectedSeconds = 5;
    }
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinutes);
    _secondController = FixedExtentScrollController(initialItem: _selectedSeconds);
  }

  @override
  void dispose() {
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _onDone() {
    var totalSeconds = _selectedMinutes * 60 + _selectedSeconds;
    // Enforce minimum 1 second
    if (totalSeconds < 1) {
      totalSeconds = 1;
    }
    Navigator.of(context).pop(Duration(seconds: totalSeconds));
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Colors.white;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                const Text(
                  'Display Duration',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: _onDone,
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Color(0xFF2ECC71),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _minuteController,
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedMinutes = index);
                      },
                      children: List.generate(60, (index) {
                        return Center(
                          child: Text(
                            '$index min',
                            style: const TextStyle(color: textColor, fontSize: 18),
                          ),
                        );
                      }),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _secondController,
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedSeconds = index);
                      },
                      children: List.generate(60, (index) {
                        return Center(
                          child: Text(
                            '$index sec',
                            style: const TextStyle(color: textColor, fontSize: 18),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
