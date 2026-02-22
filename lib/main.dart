import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

void main() {
  runApp(const BlockBreakerApp());
}

class BlockBreakerApp extends StatelessWidget {
  const BlockBreakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Breaker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 12),
                GameHeader(score: score, level: currentLevel, balls: ballsCount),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade800, width: 2),
                    ),
                    child: GameWidget(
                      key: _gameWidgetKey,
                      onStatsChanged: updateStats,
                      isPausedCallback: (paused) {
                        setState(() {
                          isPaused = paused;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            // Кнопка паузы в углу
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  _gameWidgetKey.currentState?.togglePause();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B9FD8).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5B9FD8).withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    isPaused ? '▶' : '⏸',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameHeader extends StatelessWidget {
  final int score;
  final int level;
  final int balls;

  const GameHeader({
    super.key,
    required this.score,
    required this.level,
    required this.balls,
  });

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
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class GameWidget extends StatefulWidget {
  final Function(int, int, int) onStatsChanged;
  final Function(bool)? isPausedCallback;

  const GameWidget({
    super.key,
    required this.onStatsChanged,
    this.isPausedCallback,
  });

  @override
  State<GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> with TickerProviderStateMixin {
  late List<Block> blocks;
  late List<Ball> balls;
  late Paddle paddle;
  late List<Particle> particles;
  late List<PowerUp> powerUps;
  int score = 0;
  int currentLevel = 1;
  int ballsCount = 1;
  late AnimationController _controller;
  bool isPaused = false;
  bool isGameOver = false;
  double gameSpeed = 1.0;

  late FocusNode _focusNode;
  int slowBallTimer = 0; // Таймер замедления
  int expandPaddleTimer = 0; // Таймер расширения

  void togglePause() {
    setState(() {
      isPaused = !isPaused;
      widget.isPausedCallback?.call(isPaused);
    });
  }

  @override
  void initState() {
    super.initState();
    _initGame();
    _focusNode = FocusNode();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
      setState(() {
        _updateGame();
      });
    });
    _controller.repeat();
  }

  void _initGame() {
    blocks = _generateLevel(currentLevel);
    balls = [Ball(x: 150, y: 450, radius: 8, dx: 2.5 * gameSpeed, dy: -3.0 * gameSpeed)];
    ballsCount = 1;
    particles = [];
    powerUps = [];
    paddle = Paddle(
      x: 120,
      y: 470,
      width: 80,
      height: 12,
    );
    isGameOver = false;
    isPaused = false;
  }

  List<Block> _generateLevel(int level) {
    List<Block> levelBlocks = [];
    double gameWidth = 300;
    double gameHeight = 300;
    double blockWidth = 45;
    double blockHeight = 16;
    double padding = 4;

    int targetBlockCount = 15 + level * 3;
    if (targetBlockCount > 50) targetBlockCount = 50;

    int maxSpecialBlocks = level <= 3 ? 2 : (level <= 6 ? 3 : 4);
    int specialCount = 0;
    int wallCount = 0;
    int maxWalls = level >= 5 ? 2 + (level - 5) ~/ 3 : 0; // Стены с уровня 5

    // Генерируем блоки в случайном порядке с нерегулярной сеткой
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    int blockCount = 0;

    for (int y = 40; y < gameHeight - 40 && blockCount < targetBlockCount; y += (blockHeight + padding).toInt()) {
      // Смещение каждой строки для неровности
      double xOffset = ((y.toInt() + random) % 10) - 5;

      for (double x = 10 + xOffset; x < gameWidth - blockWidth && blockCount < targetBlockCount; x += blockWidth + padding) {
        // Пропускаем блоки случайно для неровности
        if ((x.toInt() + y.toInt()) % 7 == 0) continue;

        int hits = 1;
        bool isSpecial = false;
        bool isWall = false;
        Color color = const Color(0xFF808080);

        // Определяем стены (неуничтожаемые блоки) на уровнях 5+
        if (level >= 5 && wallCount < maxWalls &&
            (x.toInt() * 19 + y.toInt() * 23 + random) % 20 == 0) {
          isWall = true;
          wallCount++;
          hits = 999; // Не уничтожаются
          color = const Color(0xFF3A3A3A); // Тёмно-серый
        } else {
          // Определяем урон блока на основе уровня
          if (level >= 3) {
            int rand = (x.toInt() + y.toInt() * 7) % 10;
            if (rand < 3) hits = 2;
            else if (rand < 6 && level >= 6) hits = 3;
            else if (rand < 8 && level >= 9) hits = 4;
          }

          // Определяем цвет на основе урона
          if (hits == 1) {
            color = const Color(0xFF707070); // Серый
          } else if (hits == 2) {
            color = const Color(0xFF5B9FD8); // Яркий синий
          } else if (hits == 3) {
            color = const Color(0xFF3A7BC8); // Глубокий синий
          } else {
            color = const Color(0xFF1E5BA8); // Тёмный синий
          }

          // Случайно выбираем спецблоки
          if (specialCount < maxSpecialBlocks &&
              (x.toInt() * 13 + y.toInt() * 17 + random) % 15 == 0 &&
              level > 1) {
            isSpecial = true;
            specialCount++;
            color = const Color(0xFF4ECDC4); // Красивый голубовато-зелёный
          }
        }

        levelBlocks.add(Block(
          x: x,
          y: y.toDouble(),
          width: blockWidth,
          height: blockHeight,
          hits: hits,
          color: color,
          isSpecial: isSpecial,
          isWall: isWall,
        ));

        blockCount++;
      }
    }

    return levelBlocks;
  }

  void _updateGame() {
    if (isPaused || isGameOver) return;

    final double width = 300;
    final double height = 500;

    // Обновляем таймеры бонусов
    if (slowBallTimer > 0) {
      slowBallTimer--;
      if (slowBallTimer == 0) {
        gameSpeed = 1.0; // Возвращаем нормальную скорость
      }
    }

    // Обновляем таймер расширения платформы
    if (paddle.expandedTime > 0) {
      paddle.expandedTime--;
      if (paddle.expandedTime == 0) {
        // Сжимаем платформу на шаг (макс до базовой ширины)
        if (paddle.width > paddle.baseWidth) {
          paddle.width -= 10;
          if (paddle.width < paddle.baseWidth) {
            paddle.width = paddle.baseWidth;
          }
          if (paddle.x + paddle.width > 300) {
            paddle.x = 300 - paddle.width;
          }
        }
      }
    }

    // Обновляем огненные шары - возвращаем в обычные по таймеру или после срока
    for (var ball in balls) {
      if (ball.isFireBall) {
        if (ball.fireballTimer > 0) {
          ball.fireballTimer--;
          if (ball.fireballTimer == 0) {
            ball.isFireBall = false;
            ball.radius = 8;
          }
        } else if (ball.fireballHits <= 0) {
          ball.isFireBall = false;
          ball.radius = 8;
        }
      }
    }

    // Обновляем частицы
    particles.removeWhere((p) => p.life <= 0);
    for (var p in particles) {
      p.update();
    }

    // Обновляем бонусы
    powerUps.removeWhere((pu) => pu.life <= 0 || pu.y > height + 50);
    for (var pu in powerUps) {
      pu.update();
    }

    // Проверка столкновения с бонусами
    for (var pu in powerUps.toList()) {
      if (pu.x + 6 > paddle.x &&
          pu.x - 6 < paddle.x + paddle.width &&
          pu.y + 8 > paddle.y - 30 &&
          pu.y - 8 < paddle.y + paddle.height) {
        _applyPowerUp(pu.type);
        powerUps.remove(pu);
      }
    }

    for (var ball in balls.toList()) {
      double prevX = ball.x;
      double prevY = ball.y;

      ball.x += ball.dx;
      ball.y += ball.dy;

      // Столкновение со стенами
      if (ball.x - ball.radius < 0 || ball.x + ball.radius > width) {
        ball.dx = -ball.dx;
      }
      if (ball.y - ball.radius < 0) {
        ball.dy = -ball.dy;
      }

      // Проверка падения шара
      if (ball.y > height + 20) {
        balls.remove(ball);
        ballsCount = balls.length;
        widget.onStatsChanged(score, currentLevel, ballsCount);
        if (balls.isEmpty) {
          isGameOver = true;
        }
        continue;
      }

      // Столкновение с платформой
      if (_checkPaddleCollision(ball)) {
        _handlePaddleCollision(ball);
      }

      // Столкновение с блоками
      for (var block in blocks.toList()) {
        if (_checkBlockCollisionLinecast(ball, block, prevX, prevY)) {
          _handleBlockCollision(ball, block);
          _spawnParticles(block.x + block.width / 2, block.y + block.height / 2);
          widget.onStatsChanged(score, currentLevel, ballsCount);
          break;
        }
      }
    }

    // Проверка завершения уровня
    if (blocks.isEmpty) {
      _nextLevel();
      widget.onStatsChanged(score, currentLevel, ballsCount);
    }

    // Проверка game over
    if (balls.isEmpty && !isGameOver) {
      isGameOver = true;
    }
  }

  bool _checkPaddleCollision(Ball ball) {
    // Исправлено: теперь проверка учитывает радиус шара
    if (ball.y + ball.radius >= paddle.y &&
        ball.y - ball.radius <= paddle.y + paddle.height &&
        ball.x + ball.radius >= paddle.x &&
        ball.x - ball.radius <= paddle.x + paddle.width) {
      return true;
    }
    return false;
  }

  void _handlePaddleCollision(Ball ball) {
    // Исправлено: шар отскакивает от платформы, а не проходит сквозь нее
    double overlap = (ball.y + ball.radius) - paddle.y;
    ball.y -= overlap;

    ball.dy = -ball.dy;

    // Управление направлением в зависимости от позиции удара
    double center = paddle.x + paddle.width / 2;
    double hitPosition = (ball.x - center) / (paddle.width / 2);
    ball.dx = hitPosition * 3.5;

    // Небольшое увеличение скорости для динамики
    double speed = ball.dx * ball.dx + ball.dy * ball.dy;
    if (speed < 25) {
      speed = 5.0;
    }
    ball.dx = ball.dx * (speed / (speed + 0.1));
    ball.dy = ball.dy * (speed / (speed + 0.1));
  }

  bool _checkBlockCollision(Ball ball, Block block) {
    // Исправлено: более точная проверка столкновения
    double closestX = ball.x.clamp(block.x, block.x + block.width);
    double closestY = ball.y.clamp(block.y, block.y + block.height);

    double distanceX = ball.x - closestX;
    double distanceY = ball.y - closestY;

    return (distanceX * distanceX + distanceY * distanceY) <= (ball.radius * ball.radius);
  }

  bool _checkBlockCollisionLinecast(Ball ball, Block block, double prevX, double prevY) {
    // Проверка столкновения с траекторией мячика
    double closestX = ball.x.clamp(block.x, block.x + block.width);
    double closestY = ball.y.clamp(block.y, block.y + block.height);

    double distanceX = ball.x - closestX;
    double distanceY = ball.y - closestY;

    if ((distanceX * distanceX + distanceY * distanceY) <= (ball.radius * ball.radius)) {
      return true;
    }

    // Проверяем прошлую позицию тоже
    closestX = prevX.clamp(block.x, block.x + block.width);
    closestY = prevY.clamp(block.y, block.y + block.height);

    distanceX = prevX - closestX;
    distanceY = prevY - closestY;

    return (distanceX * distanceX + distanceY * distanceY) <= (ball.radius * ball.radius);
  }

  void _handleBlockCollision(Ball ball, Block block) {
    int originalHits = block.hits;
    block.hits--;

    double closestX = ball.x.clamp(block.x, block.x + block.width);
    double closestY = ball.y.clamp(block.y, block.y + block.height);

    double distanceX = ball.x - closestX;
    double distanceY = ball.y - closestY;

    if (distanceX.abs() > distanceY.abs()) {
      ball.dx = -ball.dx;
      ball.x += distanceX > 0 ? ball.radius : -ball.radius;
    } else {
      ball.dy = -ball.dy;
      ball.y += distanceY > 0 ? ball.radius : -ball.radius;
    }

    // Выцветание синих блоков
    if (!block.isSpecial && !block.isWall && originalHits >= 2) {
      double saturation = block.hits / originalHits;

      if (originalHits == 2) {
        // От яркого синего к светлому
        int r = (91 + (220 - 91) * (1 - saturation)).toInt();
        int g = (159 + (210 - 159) * (1 - saturation)).toInt();
        int b = (216 + (245 - 216) * (1 - saturation)).toInt();
        block.color = Color.fromARGB(255, r, g, b);
      } else if (originalHits == 3) {
        // От глубокого синего к светлому
        int r = (58 + (220 - 58) * (1 - saturation)).toInt();
        int g = (123 + (210 - 123) * (1 - saturation)).toInt();
        int b = (200 + (245 - 200) * (1 - saturation)).toInt();
        block.color = Color.fromARGB(255, r, g, b);
      } else if (originalHits >= 4) {
        // От тёмного синего к светлому
        int r = (30 + (220 - 30) * (1 - saturation)).toInt();
        int g = (91 + (210 - 91) * (1 - saturation)).toInt();
        int b = (168 + (245 - 168) * (1 - saturation)).toInt();
        block.color = Color.fromARGB(255, r, g, b);
      }
    }

    // Логика огненного шара
    if (ball.isFireBall) {
      ball.fireballHits--;
      if (ball.fireballHits <= 0) {
        ball.isFireBall = false;
        ball.radius = 8; // Вернуть нормальный размер
      }
    }

    if (block.hits > 0) {
      score += 10;
    } else {
      score += 50;
    }

    if (block.hits <= 0 && !block.isWall) {
      if (block.isSpecial) {
        _addBonusBalls(level: currentLevel);
      } else {
        // Случайный бонус при уничтожении обычного блока
        int rand = (block.x.toInt() + block.y.toInt()) % 25;
        if (rand < 8) {
          powerUps.add(PowerUp(
            x: block.x + block.width / 2,
            y: block.y,
            type: rand < 2 ? PowerUpType.fireBall :
            rand < 5 ? PowerUpType.expandPaddle :
            rand < 7 ? PowerUpType.slowBall :
            PowerUpType.extraBall,
          ));
        }
      }
      blocks.remove(block);
    }
  }

  void _addBonusBalls({required int level}) {
    int bonusCount = 0;

    // Уровневая система бонусов
    if (level <= 4) {
      bonusCount = 2;
    } else if (level <= 7) {
      bonusCount = 3;
    } else {
      bonusCount = 5;
    }

    // Добавляем новые шары
    for (int i = 0; i < bonusCount; i++) {
      balls.add(
        Ball(
          x: 150 + i * 5,
          y: 400 - i * 5,
          radius: 8,
          dx: 2.0 + i * 0.5,
          dy: -2.5 - i * 0.3,
        ),
      );
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

  void _resetLevel() {
    _initGame();
  }

  void _resetGame() {
    currentLevel = 1;
    score = 0;
    gameSpeed = 1.0;
    _initGame();
  }

  void _spawnParticles(double x, double y) {
    for (int i = 0; i < 6; i++) {
      double angle = (i / 6) * 3.14159 * 2;
      double vx = 2 * cos(angle);
      double vy = 2 * sin(angle);
      particles.add(Particle(
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        color: const Color(0xFFFFDD00),
      ));
    }
  }

  void _applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.expandPaddle:
        if (paddle.width < 180) {
          paddle.width += 30;
          paddle.expandedTime = 600; // 600 кадров ~ 10 сек при 60 fps
          if (paddle.x + paddle.width > 300) {
            paddle.x = 300 - paddle.width;
          }
          // Спавним частицы для визуального эффекта
          for (int i = 0; i < 10; i++) {
            double angle = (i / 10) * 3.14159 * 2;
            double vx = 1.5 * cos(angle);
            double vy = 1.5 * sin(angle);
            particles.add(Particle(
              x: paddle.x + paddle.width / 2,
              y: paddle.y,
              vx: vx,
              vy: vy,
              color: const Color(0xFF5B9FD8),
            ));
          }
        }
        score += 150;
        break;
      case PowerUpType.slowBall:
        gameSpeed = 0.7;
        slowBallTimer = 600; // 600 кадров ~ 10 сек
        // Визуальный эффект
        for (int i = 0; i < 8; i++) {
          particles.add(Particle(
            x: 150,
            y: 250 + (i * 10).toDouble(),
            vx: (i.isEven ? -1.0 : 1.0),
            vy: 0,
            color: const Color(0xFF3A7BC8),
          ));
        }
        score += 100;
        break;
      case PowerUpType.extraBall:
        balls.add(Ball(
          x: paddle.x + paddle.width / 2,
          y: paddle.y - 20,
          radius: 8,
          dx: 2 * gameSpeed,
          dy: -3 * gameSpeed,
        ));
        ballsCount = balls.length;
        // Визуальный эффект
        for (int i = 0; i < 12; i++) {
          double angle = (i / 12) * 3.14159 * 2;
          double vx = 2 * cos(angle);
          double vy = 2 * sin(angle);
          particles.add(Particle(
            x: paddle.x + paddle.width / 2,
            y: paddle.y - 10,
            vx: vx,
            vy: vy,
            color: const Color(0xFF4ECDC4),
          ));
        }
        score += 250;
        break;
      case PowerUpType.fireBall:
      // Превращаем ближайший шар в огненный
        if (balls.isNotEmpty) {
          balls[0].isFireBall = true;
          balls[0].radius = 10; // Чуть толще обычного
          balls[0].fireballHits = 2; // Может ударить 2 блока
          balls[0].fireballTimer = 600; // 600 кадров ~ 10 сек
          // Визуальный эффект
          for (int i = 0; i < 16; i++) {
            double angle = (i / 16) * 3.14159 * 2;
            double vx = 2.5 * cos(angle);
            double vy = 2.5 * sin(angle);
            particles.add(Particle(
              x: balls[0].x,
              y: balls[0].y,
              vx: vx,
              vy: vy,
              color: const Color(0xFFFF6B35),
            ));
          }
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
          final isKeyDown = event.isKeyPressed(LogicalKeyboardKey.arrowLeft) ||
              event.isKeyPressed(LogicalKeyboardKey.arrowRight);

          if (!isPaused && !isGameOver) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
              setState(() {
                paddle.x = (paddle.x - 12).clamp(0, 300 - paddle.width);
              });
              return KeyEventResult.handled;
            } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
              setState(() {
                paddle.x = (paddle.x + 12).clamp(0, 300 - paddle.width);
              });
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onPanUpdate: !isPaused && !isGameOver ? (details) {
            setState(() {
              paddle.x = (paddle.x + details.delta.dx).clamp(0, 300 - paddle.width);
            });
          } : null,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(300, 500),
                painter: GamePainter(
                  blocks,
                  balls,
                  paddle,
                  particles,
                  powerUps,
                  score,
                  currentLevel,
                  ballsCount,
                ),
              ),
              // Game Over экран
              if (isGameOver)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'GAME OVER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Score: $score',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          'Level: $currentLevel',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 40),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _resetGame();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'RESTART',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Пауза экран
              if (isPaused && !isGameOver)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Text(
                      'PAUSED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        )
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
  final int score;
  final int level;
  final int ballsCount;

  GamePainter(
      this.blocks,
      this.balls,
      this.paddle,
      this.particles,
      this.powerUps,
      this.score,
      this.level,
      this.ballsCount,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Фон
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1E1E1E),
    );

    // Границы игровой площадки
    canvas.drawLine(
      const Offset(0, 0),
      const Offset(300, 0),
      Paint()
        ..color = const Color(0xFF404040)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(0, 0),
      const Offset(0, 500),
      Paint()
        ..color = const Color(0xFF404040)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(300, 0),
      const Offset(300, 500),
      Paint()
        ..color = const Color(0xFF404040)
        ..strokeWidth = 2,
    );

    // Отрисовка блоков
    for (var block in blocks) {
      // Основной блок
      canvas.drawRect(
        Rect.fromLTWH(
          block.x,
          block.y,
          block.width,
          block.height,
        ),
        Paint()
          ..color = block.color
          ..style = PaintingStyle.fill,
      );

      // Выцветание для прочных блоков - грань
      if (block.hits >= 1 && !block.isSpecial && !block.isWall) {
        canvas.drawRect(
          Rect.fromLTWH(
            block.x + 1,
            block.y + 1,
            block.width - 2,
            block.height - 2,
          ),
          Paint()
            ..color = block.color.withOpacity(0.6)
            ..style = PaintingStyle.fill,
        );
      }

      // Эффект для стен (крестик)
      if (block.isWall) {
        // Крестик на стене - пиксельный стиль
        for (int i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(block.x + 5 + i * 2, block.y + 3),
            Offset(block.x + block.width - 5 - i * 2, block.y + block.height - 3),
            Paint()
              ..color = Colors.white.withOpacity(0.25)
              ..strokeWidth = 1,
          );
          canvas.drawLine(
            Offset(block.x + block.width - 5 - i * 2, block.y + 3),
            Offset(block.x + 5 + i * 2, block.y + block.height - 3),
            Paint()
              ..color = Colors.white.withOpacity(0.25)
              ..strokeWidth = 1,
          );
        }
      }

      // Эффект свечения для спецблоков - пиксельный стиль
      if (block.isSpecial) {
        // Внутреннее свечение
        canvas.drawRect(
          Rect.fromLTWH(
            block.x + 2,
            block.y + 2,
            block.width - 4,
            block.height - 4,
          ),
          Paint()
            ..color = const Color(0xFF4ECDC4).withOpacity(0.7)
            ..style = PaintingStyle.fill,
        );

        // Светлые пиксели по краям
        for (double px = block.x + 1; px < block.x + block.width - 1; px += 4) {
          canvas.drawRect(
            Rect.fromLTWH(px, block.y + 1, 2, 1),
            Paint()..color = Colors.white.withOpacity(0.6),
          );
        }
      }
    }

    // Отрисовка шаров
    for (var ball in balls) {
      if (ball.isFireBall) {
        // Огненный шлейф (за мячом)
        for (int i = 0; i < 5; i++) {
          double trailX = ball.x - (ball.dx / 5 * (i + 1));
          double trailY = ball.y - (ball.dy / 5 * (i + 1));
          double opacity = (1.0 - (i / 5)) * 0.4;

          canvas.drawCircle(
            Offset(trailX, trailY),
            ball.radius * (1.0 - i * 0.15),
            Paint()
              ..color = const Color(0xFFFFAA00).withOpacity(opacity)
              ..style = PaintingStyle.fill,
          );
        }

        // Основной оранжевый шар
        canvas.drawCircle(
          Offset(ball.x, ball.y),
          ball.radius,
          Paint()
            ..color = const Color(0xFFFF6B35)
            ..style = PaintingStyle.fill,
        );

        // Жёлтый центр
        canvas.drawCircle(
          Offset(ball.x, ball.y),
          ball.radius * 0.6,
          Paint()
            ..color = const Color(0xFFFFDD00)
            ..style = PaintingStyle.fill,
        );

        // Белый блик
        canvas.drawCircle(
          Offset(ball.x - ball.radius * 0.2, ball.y - ball.radius * 0.2),
          ball.radius * 0.3,
          Paint()
            ..color = Colors.white.withOpacity(0.7)
            ..style = PaintingStyle.fill,
        );
      } else {
        // Обычный синий шар
        canvas.drawCircle(
          Offset(ball.x, ball.y),
          ball.radius,
          Paint()
            ..color = const Color(0xFF5B9FD8).withOpacity(0.9)
            ..style = PaintingStyle.fill,
        );

        // Блик
        canvas.drawCircle(
          Offset(ball.x - ball.radius * 0.3, ball.y - ball.radius * 0.3),
          ball.radius * 0.4,
          Paint()
            ..color = Colors.white.withOpacity(0.5)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Основание платформы
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          paddle.x,
          paddle.y,
          paddle.width,
          paddle.height,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF00D9FF),
    );

    // Верхняя светлая полоса платформы
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          paddle.x + 1,
          paddle.y + 1,
          paddle.width - 2,
          paddle.height * 0.6,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF00FFFF).withOpacity(0.8),
    );

    // Нижняя темная полоса для глубины
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          paddle.x + 2,
          paddle.y + paddle.height * 0.5,
          paddle.width - 4,
          paddle.height * 0.4,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF0099CC),
    );

    // Блик (свечение)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          paddle.x + 3,
          paddle.y + 1,
          paddle.width - 6,
          2,
        ),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    // Тень под платформой
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          paddle.x,
          paddle.y + paddle.height + 1,
          paddle.width,
          2,
        ),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.black.withOpacity(0.5),
    );

    // Отрисовка частиц
    for (var p in particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        2,
        Paint()
          ..color = p.color.withOpacity(p.life / 100)
          ..style = PaintingStyle.fill,
      );
    }

    // Отрисовка бонусов - простой пиксельарт
    for (var pu in powerUps) {
      Color puColor;

      switch (pu.type) {
        case PowerUpType.expandPaddle:
          puColor = const Color(0xFF5B9FD8); // Синий
          // Квадрат с горизонтальными полосками
          canvas.drawRect(
            Rect.fromLTWH(pu.x - 7, pu.y - 5, 14, 10),
            Paint()
              ..color = puColor
              ..style = PaintingStyle.fill,
          );
          for (double yy = pu.y - 4; yy <= pu.y + 4; yy += 3) {
            canvas.drawLine(
              Offset(pu.x - 6, yy),
              Offset(pu.x + 6, yy),
              Paint()
                ..color = Colors.white.withOpacity(0.5)
                ..strokeWidth = 1,
            );
          }
          break;
        case PowerUpType.slowBall:
          puColor = const Color(0xFF3A7BC8); // Тёмный синий
          // Круг с точками (часовая сетка)
          canvas.drawCircle(
            Offset(pu.x, pu.y),
            6,
            Paint()
              ..color = puColor
              ..style = PaintingStyle.fill,
          );
          for (int i = 0; i < 4; i++) {
            double angle = (i / 4) * 3.14159 * 2;
            double px = pu.x + cos(angle) * 4;
            double py = pu.y + sin(angle) * 4;
            canvas.drawCircle(
              Offset(px, py),
              1,
              Paint()
                ..color = Colors.white.withOpacity(0.7),
            );
          }
          break;
        case PowerUpType.extraBall:
          puColor = const Color(0xFF4ECDC4); // Голубовато-зелёный
          // Два квадрата рядом
          canvas.drawRect(
            Rect.fromLTWH(pu.x - 8, pu.y - 4, 7, 8),
            Paint()
              ..color = puColor
              ..style = PaintingStyle.fill,
          );
          canvas.drawRect(
            Rect.fromLTWH(pu.x + 1, pu.y - 4, 7, 8),
            Paint()
              ..color = puColor
              ..style = PaintingStyle.fill,
          );
          // Сетка
          for (double xx = pu.x - 7; xx <= pu.x + 6; xx += 3) {
            canvas.drawLine(
              Offset(xx, pu.y - 3),
              Offset(xx, pu.y + 3),
              Paint()
                ..color = Colors.white.withOpacity(0.4)
                ..strokeWidth = 0.5,
            );
          }
          break;
        case PowerUpType.fireBall:
          puColor = const Color(0xFFFF6B35); // Оранжевый огненный
          // Треугольник (пламя)
          canvas.drawPath(
            Path()
              ..moveTo(pu.x, pu.y - 7)
              ..lineTo(pu.x - 6, pu.y + 5)
              ..lineTo(pu.x + 6, pu.y + 5)
              ..close(),
            Paint()
              ..color = puColor
              ..style = PaintingStyle.fill,
          );
          // Жёлтый треугольник внутри
          canvas.drawPath(
            Path()
              ..moveTo(pu.x, pu.y - 4)
              ..lineTo(pu.x - 3, pu.y + 2)
              ..lineTo(pu.x + 3, pu.y + 2)
              ..close(),
            Paint()
              ..color = const Color(0xFFFFDD00)
              ..style = PaintingStyle.fill,
          );
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Игровые объекты
class Block {
  double x, y, width, height;
  int hits;
  Color color;
  bool isSpecial;
  bool isWall; // неуничтожаемая стена

  Block({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.hits,
    required this.color,
    this.isSpecial = false,
    this.isWall = false,
  });
}

class Ball {
  double x, y, radius, dx, dy;
  bool isFireBall = false;
  int fireballHits = 0; // Сколько блоков осталось ударить
  int fireballTimer = 0; // Таймер огненного шара

  Ball({
    required this.x,
    required this.y,
    required this.radius,
    required this.dx,
    required this.dy,
    this.isFireBall = false,
  });
}

class Paddle {
  double x, y, width, height;
  int expandedTime = 0; // Таймер расширения
  double baseWidth = 80; // Базовая ширина

  Paddle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) : baseWidth = width;
}

class Particle {
  double x, y, vx, vy;
  int life; // 0-100
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
  }) : life = 100;

  void update() {
    x += vx;
    y += vy;
    vy += 0.2; // гравитация
    life -= 5;
  }
}

enum PowerUpType { expandPaddle, slowBall, extraBall, fireBall }

class PowerUp {
  double x, y;
  double vx = 0, vy = 2.5;
  PowerUpType type;
  int life = 300; // больше времени

  PowerUp({
    required this.x,
    required this.y,
    required this.type,
  });

  void update() {
    x += vx;
    y += vy;
    life--;
  }
}