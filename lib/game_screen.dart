import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int score = 0;
  int currentLevel = 1;
  int ballsCount = 1;
  bool isPaused = false;
  final GlobalKey<_GameWidgetState> _gameWidgetKey = GlobalKey();

  void updateStats(int newScore, int newLevel, int newBalls) {
    setState(() {
      score = newScore;
      currentLevel = newLevel;
      ballsCount = newBalls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false, scrollbars: false),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 72),
                  GameHeader(score: score, level: currentLevel, balls: ballsCount),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade800, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GameWidget(
                          key: _gameWidgetKey,
                          onStatsChanged: updateStats,
                          isPausedCallback: (paused) {
                            setState(() { isPaused = paused; });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              Positioned(
                top: 6,
                right: 18,
                child: GestureDetector(
                  onTap: () => _gameWidgetKey.currentState?.togglePause(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)],
                    ),
                    child: Text(
                      isPaused ? '▶' : 'II',
                      style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameHeader extends StatelessWidget {
  final int score;
  final int level;
  final int balls;

  const GameHeader({super.key, required this.score, required this.level, required this.balls});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStat('SCORE', score.toString(), const Color(0xFF6E8BAA)),
        _buildStat('LEVEL', level.toString(), const Color(0xFF8AA66E)),
        _buildStat('BALLS', balls.toString(), const Color(0xFFA68A6E)),
      ],
    );
  }

  static Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }
}

class GameWidget extends StatefulWidget {
  final Function(int, int, int) onStatsChanged;
  final Function(bool)? isPausedCallback;

  const GameWidget({super.key, required this.onStatsChanged, this.isPausedCallback});

  @override
  State<GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> with TickerProviderStateMixin {
  List<Block> blocks = [];
  List<Ball> balls = [];
  Paddle paddle = Paddle(x: 0, y: 0, width: 80, height: 12);
  List<Particle> particles = [];
  List<PowerUp> powerUps = [];
  int score = 0;
  int currentLevel = 1;
  int ballsCount = 1;
  late AnimationController _controller;
  bool isPaused = false;
  bool isGameOver = false;
  double gameSpeed = 1.0;
  int slowBallTimer = 0;

  late FocusNode _focusNode;

  // Реальные размеры поля — устанавливаются после первого layout
  double _w = 300;
  double _h = 500;
  bool _initialized = false;

  void togglePause() {
    setState(() {
      isPaused = !isPaused;
      widget.isPausedCallback?.call(isPaused);
    });
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
      setState(() { _updateGame(); });
    });
    _controller.repeat();
    Future.delayed(const Duration(milliseconds: 100), () => _focusNode.requestFocus());
  }

  void _initGame() {
    blocks = _generateLevel(currentLevel);
    final cx = _w / 2;
    balls = [Ball(x: cx, y: _h * 0.73, radius: 8, dx: 2.75 * gameSpeed, dy: -3.3 * gameSpeed)];
    ballsCount = 1;
    particles = [];
    powerUps = [];
    paddle = Paddle(x: cx - 40, y: _h * 0.83, width: 80, height: 12);
    isGameOver = false;
    isPaused = false;
  }

  List<Block> _generateLevel(int level) {
    List<Block> result = [];
    double blockW = (_w - 14) / 6 - 5;   // 6 колонок, вписываем в ширину
    double blockH = 15.0;
    double padX = 5;
    double padY = 5;
    int cols = 6;
    int rows = 8 + (level ~/ 2);
    if (rows > 12) rows = 12;

    int maxSpecial = level <= 3 ? 2 : (level <= 6 ? 3 : 4);
    int specialCount = 0;
    int wallCount = 0;
    int maxWalls = level >= 5 ? 2 + (level - 5) ~/ 3 : 0;
    final rng = DateTime.now().millisecondsSinceEpoch % 10000;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double x = 7 + c * (blockW + padX);
        double y = 30 + r * (blockH + padY);

        // Не даём блокам уйти ниже 65% высоты поля
        if (y + blockH > _h * 0.65) continue;

        int hits = 1;
        bool isSpecial = false;
        bool isWall = false;
        Color color = const Color(0xFF707070);

        if (level >= 5 && wallCount < maxWalls && (r * 7 + c * 13 + rng) % 20 == 0) {
          isWall = true;
          wallCount++;
          hits = 999;
          color = const Color(0xFF3A3A3A);
        } else {
          if (level >= 3) {
            int rand = (r * 7 + c * 13) % 10;
            if (rand < 3) hits = 2;
            else if (rand < 6 && level >= 6) hits = 3;
            else if (rand < 8 && level >= 9) hits = 4;
          }
          if (hits == 1) color = const Color(0xFF707070);
          else if (hits == 2) color = const Color(0xFF5B9FD8);
          else if (hits == 3) color = const Color(0xFF3A7BC8);
          else color = const Color(0xFF1E5BA8);

          if (specialCount < maxSpecial && (r * 11 + c * 17 + rng) % 15 == 0 && level > 1) {
            isSpecial = true;
            specialCount++;
            color = const Color(0xFF4ECDC4);
          }
        }

        result.add(Block(x: x, y: y, width: blockW, height: blockH,
            hits: hits, color: color, isSpecial: isSpecial, isWall: isWall));
      }
    }
    return result;
  }

  void _updateGame() {
    if (!_initialized || isPaused || isGameOver) return;

    if (slowBallTimer > 0) {
      slowBallTimer--;
      if (slowBallTimer == 0) gameSpeed = 1.0;
    }

    if (paddle.expandedTime > 0) {
      paddle.expandedTime--;
      if (paddle.expandedTime == 0 && paddle.width > paddle.baseWidth) {
        paddle.width -= 10;
        if (paddle.width < paddle.baseWidth) paddle.width = paddle.baseWidth;
        if (paddle.x + paddle.width > _w) paddle.x = _w - paddle.width;
      }
    }

    for (var ball in balls) {
      if (ball.isFireBall) {
        if (ball.fireballTimer > 0) {
          ball.fireballTimer--;
          if (ball.fireballTimer == 0) { ball.isFireBall = false; ball.radius = 8; }
        } else if (ball.fireballHits <= 0) {
          ball.isFireBall = false; ball.radius = 8;
        }
      }
    }

    particles.removeWhere((p) => p.life <= 0);
    for (var p in particles) { p.update(); }

    powerUps.removeWhere((pu) => pu.life <= 0 || pu.y > _h + 50);
    for (var pu in powerUps) { pu.update(); }

    for (var pu in powerUps.toList()) {
      if (pu.x + 6 > paddle.x && pu.x - 6 < paddle.x + paddle.width &&
          pu.y + 8 > paddle.y && pu.y - 8 < paddle.y + paddle.height) {
        _applyPowerUp(pu.type);
        powerUps.remove(pu);
      }
    }

    for (var ball in balls.toList()) {
      double prevX = ball.x;
      double prevY = ball.y;
      ball.x += ball.dx;
      ball.y += ball.dy;

      // Стены
      if (ball.x - ball.radius < 0) { ball.dx = ball.dx.abs(); ball.x = ball.radius; }
      if (ball.x + ball.radius > _w) { ball.dx = -ball.dx.abs(); ball.x = _w - ball.radius; }
      if (ball.y - ball.radius < 0) { ball.dy = ball.dy.abs(); ball.y = ball.radius; }

      // Падение
      if (ball.y > _h + 20) {
        balls.remove(ball);
        ballsCount = balls.length;
        widget.onStatsChanged(score, currentLevel, ballsCount);
        if (balls.isEmpty) isGameOver = true;
        continue;
      }

      if (_checkPaddleCollision(ball)) _handlePaddleCollision(ball);

      for (var block in blocks.toList()) {
        if (_checkBlockCollisionLinecast(ball, block, prevX, prevY)) {
          _handleBlockCollision(ball, block);
          _spawnParticles(block.x + block.width / 2, block.y + block.height / 2);
          widget.onStatsChanged(score, currentLevel, ballsCount);
          break;
        }
      }
    }

    if (blocks.isEmpty) {
      _nextLevel();
      widget.onStatsChanged(score, currentLevel, ballsCount);
    }
    if (balls.isEmpty && !isGameOver) isGameOver = true;
  }

  bool _checkPaddleCollision(Ball ball) {
    return ball.y + ball.radius >= paddle.y &&
        ball.y - ball.radius <= paddle.y + paddle.height &&
        ball.x + ball.radius >= paddle.x &&
        ball.x - ball.radius <= paddle.x + paddle.width;
  }

  void _handlePaddleCollision(Ball ball) {
    ball.y = paddle.y - ball.radius;
    ball.dy = -ball.dy.abs();
    double center = paddle.x + paddle.width / 2;
    double hitPos = (ball.x - center) / (paddle.width / 2);
    ball.dx = hitPos * 3.5;
    if (ball.dx.abs() < 0.5) ball.dx = ball.dx < 0 ? -0.5 : 0.5;
  }

  bool _checkBlockCollisionLinecast(Ball ball, Block block, double prevX, double prevY) {
    double cx = ball.x.clamp(block.x, block.x + block.width);
    double cy = ball.y.clamp(block.y, block.y + block.height);
    double dx = ball.x - cx, dy = ball.y - cy;
    if (dx * dx + dy * dy <= ball.radius * ball.radius) return true;
    cx = prevX.clamp(block.x, block.x + block.width);
    cy = prevY.clamp(block.y, block.y + block.height);
    dx = prevX - cx; dy = prevY - cy;
    return dx * dx + dy * dy <= ball.radius * ball.radius;
  }

  void _handleBlockCollision(Ball ball, Block block) {
    int origHits = block.hits;
    block.hits--;

    double cx = ball.x.clamp(block.x, block.x + block.width);
    double cy = ball.y.clamp(block.y, block.y + block.height);
    double dx = ball.x - cx, dy = ball.y - cy;

    if (dx.abs() > dy.abs()) {
      ball.dx = -ball.dx;
      ball.x += dx > 0 ? ball.radius - dx : -(ball.radius - dx.abs());
    } else {
      ball.dy = -ball.dy;
      ball.y += dy > 0 ? ball.radius - dy : -(ball.radius - dy.abs());
    }

    if (!block.isSpecial && !block.isWall && origHits >= 2) {
      double sat = block.hits / origHits;
      if (origHits == 2) {
        block.color = Color.fromARGB(255, (91 + (220 - 91) * (1 - sat)).toInt(),
            (159 + (210 - 159) * (1 - sat)).toInt(), (216 + (245 - 216) * (1 - sat)).toInt());
      } else if (origHits == 3) {
        block.color = Color.fromARGB(255, (58 + (220 - 58) * (1 - sat)).toInt(),
            (123 + (210 - 123) * (1 - sat)).toInt(), (200 + (245 - 200) * (1 - sat)).toInt());
      } else {
        block.color = Color.fromARGB(255, (30 + (220 - 30) * (1 - sat)).toInt(),
            (91 + (210 - 91) * (1 - sat)).toInt(), (168 + (245 - 168) * (1 - sat)).toInt());
      }
    }

    if (ball.isFireBall) {
      ball.fireballHits--;
      if (ball.fireballHits <= 0) { ball.isFireBall = false; ball.radius = 8; }
    }

    score += block.hits > 0 ? 10 : 50;

    if (block.hits <= 0 && !block.isWall) {
      if (block.isSpecial) {
        _addBonusBalls(level: currentLevel);
      } else {
        int rand = (block.x.toInt() + block.y.toInt()) % 25;
        if (rand < 8) {
          powerUps.add(PowerUp(
            x: block.x + block.width / 2, y: block.y,
            type: rand < 2 ? PowerUpType.fireBall :
            rand < 5 ? PowerUpType.expandPaddle :
            rand < 7 ? PowerUpType.slowBall : PowerUpType.extraBall,
          ));
        }
      }
      blocks.remove(block);
    }
  }

  void _addBonusBalls({required int level}) {
    int count = level <= 4 ? 2 : level <= 7 ? 3 : 5;
    for (int i = 0; i < count; i++) {
      balls.add(Ball(x: _w / 2 + i * 5, y: _h * 0.75 - i * 5,
          radius: 8, dx: 2.0 + i * 0.5, dy: -2.5 - i * 0.3));
    }
    ballsCount = balls.length;
  }

  void _nextLevel() {
    if (currentLevel < 20) {
      currentLevel++;
      gameSpeed = 1.0 + (currentLevel - 1) * 0.08;
      if (gameSpeed > 2.0) gameSpeed = 2.0;
      _initGame();
    } else {
      isGameOver = true;
    }
  }

  void _resetGame() {
    currentLevel = 1;
    score = 0;
    gameSpeed = 1.0;
    _initGame();
  }

  void _spawnParticles(double x, double y) {
    for (int i = 0; i < 6; i++) {
      double angle = (i / 6) * pi * 2;
      particles.add(Particle(x: x, y: y, vx: 2 * cos(angle), vy: 2 * sin(angle),
          color: const Color(0xFFFFDD00)));
    }
  }

  void _applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.expandPaddle:
        if (paddle.width < 180) {
          paddle.width += 30;
          paddle.expandedTime = 600;
          if (paddle.x + paddle.width > _w) paddle.x = _w - paddle.width;
        }
        score += 150;
        break;
      case PowerUpType.slowBall:
        gameSpeed = 0.7;
        slowBallTimer = 600;
        score += 100;
        break;
      case PowerUpType.extraBall:
        balls.add(Ball(x: paddle.x + paddle.width / 2, y: paddle.y - 20,
            radius: 8, dx: 2 * gameSpeed, dy: -3 * gameSpeed));
        ballsCount = balls.length;
        score += 250;
        break;
      case PowerUpType.fireBall:
        if (balls.isNotEmpty) {
          balls[0].isFireBall = true;
          balls[0].radius = 10;
          balls[0].fireballHits = 2;
          balls[0].fireballTimer = 600;
        }
        score += 200;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKey: (node, event) {
        if (!isPaused && !isGameOver) {
          if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
            setState(() { paddle.x = (paddle.x - 12).clamp(0, _w - paddle.width); });
            return KeyEventResult.handled;
          } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
            setState(() { paddle.x = (paddle.x + 12).clamp(0, _w - paddle.width); });
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (_) {}, // перехватываем вертикальный скролл
        onPanUpdate: !isPaused && !isGameOver ? (details) {
          setState(() { paddle.x = (paddle.x + details.delta.dx).clamp(0, _w - paddle.width); });
        } : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final newW = constraints.maxWidth;
            final newH = constraints.maxHeight;

            // Инициализируем с реальными размерами
            if (!_initialized || (_w - newW).abs() > 1 || (_h - newH).abs() > 1) {
              _w = newW;
              _h = newH;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() { _initGame(); });
              });
              _initialized = true;
            }

            return Stack(
              children: [
                CustomPaint(
                  size: Size(_w, _h),
                  painter: GamePainter(blocks, balls, paddle, particles, powerUps, _w, _h),
                ),
                if (isGameOver)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('GAME OVER', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Text('Score: $score', style: const TextStyle(color: Colors.white70, fontSize: 22)),
                          Text('Level: $currentLevel', style: const TextStyle(color: Colors.white70, fontSize: 22)),
                          const SizedBox(height: 32),
                          GestureDetector(
                            onTap: () { setState(() { _resetGame(); }); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                              decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(12)),
                              child: const Text('RESTART', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isPaused && !isGameOver)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class GamePainter extends CustomPainter {
  final List<Block> blocks;
  final List<Ball> balls;
  final Paddle paddle;
  final List<Particle> particles;
  final List<PowerUp> powerUps;
  final double w, h;

  GamePainter(this.blocks, this.balls, this.paddle, this.particles, this.powerUps, this.w, this.h);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF1E1E1E));

    final bp = Paint()..color = const Color(0xFF404040)..strokeWidth = 2;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), bp);
    canvas.drawLine(Offset.zero, Offset(0, size.height), bp);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), bp);

    for (var block in blocks) {
      canvas.drawRect(Rect.fromLTWH(block.x, block.y, block.width, block.height),
          Paint()..color = block.color);
      if (block.isWall) {
        for (int i = 0; i < 3; i++) {
          canvas.drawLine(Offset(block.x + 5 + i * 2, block.y + 3),
              Offset(block.x + block.width - 5 - i * 2, block.y + block.height - 3),
              Paint()..color = Colors.white.withOpacity(0.25)..strokeWidth = 1);
          canvas.drawLine(Offset(block.x + block.width - 5 - i * 2, block.y + 3),
              Offset(block.x + 5 + i * 2, block.y + block.height - 3),
              Paint()..color = Colors.white.withOpacity(0.25)..strokeWidth = 1);
        }
      }
      if (block.isSpecial) {
        canvas.drawRect(Rect.fromLTWH(block.x + 2, block.y + 2, block.width - 4, block.height - 4),
            Paint()..color = const Color(0xFF4ECDC4).withOpacity(0.7));
      }
    }

    for (var ball in balls) {
      if (ball.isFireBall) {
        for (int i = 0; i < 5; i++) {
          canvas.drawCircle(Offset(ball.x - ball.dx / 5 * (i + 1), ball.y - ball.dy / 5 * (i + 1)),
              ball.radius * (1.0 - i * 0.15),
              Paint()..color = const Color(0xFFFFAA00).withOpacity((1.0 - i / 5) * 0.4));
        }
        canvas.drawCircle(Offset(ball.x, ball.y), ball.radius, Paint()..color = const Color(0xFFFF6B35));
        canvas.drawCircle(Offset(ball.x, ball.y), ball.radius * 0.6, Paint()..color = const Color(0xFFFFDD00));
        canvas.drawCircle(Offset(ball.x - ball.radius * 0.2, ball.y - ball.radius * 0.2),
            ball.radius * 0.3, Paint()..color = Colors.white.withOpacity(0.7));
      } else {
        canvas.drawCircle(Offset(ball.x, ball.y), ball.radius,
            Paint()..color = const Color(0xFF5B9FD8).withOpacity(0.9));
        canvas.drawCircle(Offset(ball.x - ball.radius * 0.3, ball.y - ball.radius * 0.3),
            ball.radius * 0.4, Paint()..color = Colors.white.withOpacity(0.5));
      }
    }

    // Платформа
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(paddle.x, paddle.y, paddle.width, paddle.height), const Radius.circular(8)),
        Paint()..color = const Color(0xFF00D9FF));
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(paddle.x + 1, paddle.y + 1, paddle.width - 2, paddle.height * 0.6), const Radius.circular(6)),
        Paint()..color = const Color(0xFF00FFFF).withOpacity(0.8));
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(paddle.x + 3, paddle.y + 1, paddle.width - 6, 2), const Radius.circular(1)),
        Paint()..color = Colors.white.withOpacity(0.6));

    for (var p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), 2, Paint()..color = p.color.withOpacity(p.life / 100));
    }

    for (var pu in powerUps) {
      switch (pu.type) {
        case PowerUpType.expandPaddle:
          canvas.drawRect(Rect.fromLTWH(pu.x - 7, pu.y - 5, 14, 10),
              Paint()..color = const Color(0xFF5B9FD8));
          break;
        case PowerUpType.slowBall:
          canvas.drawCircle(Offset(pu.x, pu.y), 6, Paint()..color = const Color(0xFF3A7BC8));
          break;
        case PowerUpType.extraBall:
          canvas.drawRect(Rect.fromLTWH(pu.x - 8, pu.y - 4, 7, 8), Paint()..color = const Color(0xFF4ECDC4));
          canvas.drawRect(Rect.fromLTWH(pu.x + 1, pu.y - 4, 7, 8), Paint()..color = const Color(0xFF4ECDC4));
          break;
        case PowerUpType.fireBall:
          canvas.drawPath(
              Path()..moveTo(pu.x, pu.y - 7)..lineTo(pu.x - 6, pu.y + 5)..lineTo(pu.x + 6, pu.y + 5)..close(),
              Paint()..color = const Color(0xFFFF6B35));
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Block {
  double x, y, width, height;
  int hits;
  Color color;
  bool isSpecial;
  bool isWall;

  Block({required this.x, required this.y, required this.width, required this.height,
    required this.hits, required this.color, this.isSpecial = false, this.isWall = false});
}

class Ball {
  double x, y, radius, dx, dy;
  bool isFireBall;
  int fireballHits = 0;
  int fireballTimer = 0;

  Ball({required this.x, required this.y, required this.radius, required this.dx, required this.dy, this.isFireBall = false});
}

class Paddle {
  double x, y, width, height;
  int expandedTime = 0;
  late double baseWidth;

  Paddle({required this.x, required this.y, required this.width, required this.height}) {
    baseWidth = width;
  }
}

class Particle {
  double x, y, vx, vy;
  int life = 100;
  Color color;

  Particle({required this.x, required this.y, required this.vx, required this.vy, required this.color});

  void update() { x += vx; y += vy; vy += 0.2; life -= 5; }
}

enum PowerUpType { expandPaddle, slowBall, extraBall, fireBall }

class PowerUp {
  double x, y;
  double vx = 0, vy = 2.5;
  PowerUpType type;
  int life = 300;

  PowerUp({required this.x, required this.y, required this.type});

  void update() { x += vx; y += vy; life--; }
}