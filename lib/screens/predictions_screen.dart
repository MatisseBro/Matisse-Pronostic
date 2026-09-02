import 'package:flutter/material.dart';

class PredictionsScreen extends StatelessWidget {
  const PredictionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes pronostics'),
      ),
      body: const Center(
        child: Text('Aucun pronostic'),
      ),
    );
  }
}
