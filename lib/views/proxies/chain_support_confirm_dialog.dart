import 'package:flutter/material.dart';

class ChainSupportConfirmDialog extends StatelessWidget {
  const ChainSupportConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Support Package'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Included:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('✓ Chain Summary\n✓ Telemetry\n✓ Intelligence\n✓ Insight'),
          SizedBox(height: 16),
          Text('Excluded:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('✓ Credentials\n✓ Tokens\n✓ Subscription URLs'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
