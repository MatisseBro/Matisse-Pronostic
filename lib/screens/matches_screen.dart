import 'package:flutter/material.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matchs du jour'),
      ),
      body: const Center(
        child: Text('Aucun match chargé'),
      ),
    );
  }
}
