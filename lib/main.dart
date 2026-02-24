import 'package:flutter/material.dart';
import 'game_screen.dart';

void main() {
  runApp(const BlockBreakerApp());
}

class BlockBreakerApp extends StatelessWidget {
  const BlockBreakerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Breaker',
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}
