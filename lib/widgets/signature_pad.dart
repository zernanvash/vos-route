import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignaturePad extends StatefulWidget {
  final ValueChanged<Uint8List?> onSign;

  const SignaturePad({super.key, required this.onSign});

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.white,
    exportBackgroundColor: Colors.black,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Signature(
            controller: _controller,
            width: double.infinity,
            height: 200,
          ),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => _controller.clear(),
              icon: Icon(Icons.clear),
              label: Text('Clear'),
            ),
            ElevatedButton.icon(
              onPressed: _saveSignature,
              icon: Icon(Icons.check),
              label: Text('Confirm'),
            ),
          ],
        ),
      ],
    );
  }

  void _saveSignature() async {
    final data = await _controller.toPngBytes();
    widget.onSign(data);
  }
}
