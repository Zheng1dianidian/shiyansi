import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class DinoGame extends StatefulWidget {
  const DinoGame({super.key});

  @override
  State<DinoGame> createState() => _DinoGameState();
}

class _DinoGameState extends State<DinoGame> with SingleTickerProviderStateMixin {
  static const double dinoHeight = 60;
  static const double dinoWidth = 60;
  static const double groundHeight = 50;
  static const double obstacleWidth = 40;
  static const double obstacleHeight = 60;
  static const double jumpHeight = 150;
  static const double gameSpeed = 5;

  double dinoY = 0;
  double dinoVelocity = 0;
  bool isJumping = false;
  bool isGameOver = false;
  int score = 0;
  List<Obstacle> obstacles = [];
  Timer? gameTimer;
  Timer? scoreTimer;
  final FocusNode _focusNode = FocusNode();
  late AnimationController _dinoController;
  bool isLookingRight = true;

  // 跳跃相关参数
  static const double initialJumpVelocity = -20.0; // 初始向上速度（负值表示向上）
  static const double gravity = 1.0; // 重力加速度
  static const double maxJumpHeight = 200.0; // 最大跳跃高度

  @override
  void initState() {
    super.initState();
    _dinoController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _startGame();
  }

  void _startGame() {
    setState(() {
      dinoY = 0;
      dinoVelocity = 0;
      isJumping = false;
      isGameOver = false;
      score = 0;
      obstacles.clear();
    });

    // 游戏主循环
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (isGameOver) {
        timer.cancel();
        return;
      }

      setState(() {
        // 更新恐龙位置
        if (isJumping) {
          dinoY += dinoVelocity; // 更新位置
          dinoVelocity += gravity; // 应用重力

          // 确保不会跳得太高
          if (dinoY < -maxJumpHeight) {
            dinoY = -maxJumpHeight;
            dinoVelocity = 0;
          }

          // 落地检测
          if (dinoY >= 0) {
            dinoY = 0;
            isJumping = false;
            dinoVelocity = 0;
          }
        }

        // 更新障碍物位置
        for (var obstacle in obstacles) {
          obstacle.x -= gameSpeed;
        }

        // 移除超出屏幕的障碍物
        obstacles.removeWhere((obstacle) => obstacle.x < -obstacleWidth);

        // 随机生成新障碍物
        if (obstacles.isEmpty || obstacles.last.x < 200) {
          obstacles.add(Obstacle(
            x: 400,
            height: obstacleHeight,
            width: obstacleWidth,
            type: ObstacleType.values[DateTime.now().millisecondsSinceEpoch % 3],
          ));
        }

        // 碰撞检测
        for (var obstacle in obstacles) {
          if (_checkCollision(obstacle)) {
            _gameOver();
            return;
          }
        }
      });
    });

    // 计分器
    scoreTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isGameOver) {
        setState(() {
          score++;
        });
      }
    });
  }

  bool _checkCollision(Obstacle obstacle) {
    // 调整碰撞检测范围，使其更精确
    final double dinoBottom = groundHeight + dinoY;
    final double dinoTop = dinoBottom - dinoHeight;
    final double obstacleBottom = groundHeight;
    final double obstacleTop = obstacleBottom - obstacle.height;

    return (obstacle.x < dinoWidth &&
        obstacle.x + obstacle.width > 0 &&
        dinoBottom > obstacleTop &&
        dinoTop < obstacleBottom);
  }

  void _jump() {
    if (!isJumping && !isGameOver) {
      setState(() {
        isJumping = true;
        dinoVelocity = initialJumpVelocity; // 使用负值，使恐龙向上跳跃
        _dinoController.forward().then((_) => _dinoController.reverse());
      });
    }
  }

  void _gameOver() {
    setState(() {
      isGameOver = true;
    });
    gameTimer?.cancel();
    scoreTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('游戏结束'),
        content: Text('你的得分是: $score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startGame();
            },
            child: const Text('重新开始'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    scoreTimer?.cancel();
    _focusNode.dispose();
    _dinoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('小恐龙跑步'),
      ),
      body: GestureDetector(
        onTapDown: (_) => _jump(),
        child: RawKeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKey: (event) {
            if (event is RawKeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space) {
                _jump();
              }
            }
          },
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.lightBlue, Colors.white],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('得分: $score'),
                      const Text('按空格键或点击屏幕跳跃'),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // 地面
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: groundHeight,
                          decoration: BoxDecoration(
                            color: Colors.brown[300],
                            border: Border(
                              top: BorderSide(
                                color: Colors.brown[400]!,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 恐龙
                      Positioned(
                        left: 50,
                        bottom: groundHeight + dinoY, // 使用dinoY来改变位置
                        child: AnimatedBuilder(
                          animation: _dinoController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_dinoController.value * 0.1),
                              child: const Text(
                                '🦕',
                                style: TextStyle(fontSize: 50),
                              ),
                            );
                          },
                        ),
                      ),
                      // 障碍物
                      ...obstacles.map((obstacle) => Positioned(
                            left: obstacle.x,
                            bottom: groundHeight,
                            child: _buildObstacle(obstacle),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildObstacle(Obstacle obstacle) {
    switch (obstacle.type) {
      case ObstacleType.cactus:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
            ),
            Container(
              width: 40,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
            ),
          ],
        );
      case ObstacleType.rock:
        return Container(
          width: obstacle.width,
          height: obstacle.height,
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(20),
          ),
        );
      case ObstacleType.bird:
        return const Text(
          '🦅',
          style: TextStyle(fontSize: 40),
        );
    }
  }
}

enum ObstacleType { cactus, rock, bird }

class Obstacle {
  double x;
  final double height;
  final double width;
  final ObstacleType type;

  Obstacle({
    required this.x,
    required this.height,
    required this.width,
    required this.type,
  });
} 