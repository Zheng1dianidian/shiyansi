import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

// 泡泡类型
enum BubbleType { normal, special, bomb }

class BubbleGame extends StatefulWidget {
  const BubbleGame({super.key});

  @override
  State<BubbleGame> createState() => _BubbleGameState();
}

class _BubbleGameState extends State<BubbleGame> with TickerProviderStateMixin {
  int _score = 0;
  int _timeLeft = 30;
  bool _isPlaying = false;
  Timer? _timer;
  Timer? _bubbleTimer;
  List<Bubble> _bubbles = [];
  final Random _random = Random();
  final int _maxBubbles = 15;
  
  // 泡泡颜色
  final Map<BubbleType, Color> _bubbleColors = {
    BubbleType.normal: Colors.blue,
    BubbleType.special: Colors.purple,
    BubbleType.bomb: Colors.red,
  };

  @override
  void initState() {
    super.initState();
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _timeLeft = 30;
      _isPlaying = true;
      _bubbles.clear();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _endGame();
        }
      });
    });

    _bubbleTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_isPlaying && _bubbles.length < _maxBubbles) {
        _addNewBubble();
      }
    });
  }

  void _addNewBubble() {
    // 随机选择泡泡类型
    BubbleType type = BubbleType.normal;
    if (_random.nextDouble() < 0.2) { // 20%概率生成特殊泡泡
      type = BubbleType.special;
    } else if (_random.nextDouble() < 0.1) { // 10%概率生成炸弹
      type = BubbleType.bomb;
    }

    // 随机选择出现位置（四个边）
    double x, y;
    double dx, dy;
    
    switch (_random.nextInt(4)) {
      case 0: // 左边
        x = 0;
        y = _random.nextDouble() * 500;
        dx = _random.nextDouble() * 2 + 1;
        dy = _random.nextDouble() * 2 - 1;
        break;
      case 1: // 右边
        x = 300;
        y = _random.nextDouble() * 500;
        dx = -(_random.nextDouble() * 2 + 1);
        dy = _random.nextDouble() * 2 - 1;
        break;
      case 2: // 上边
        x = _random.nextDouble() * 300;
        y = 0;
        dx = _random.nextDouble() * 2 - 1;
        dy = _random.nextDouble() * 2 + 1;
        break;
      default: // 下边
        x = _random.nextDouble() * 300;
        y = 500;
        dx = _random.nextDouble() * 2 - 1;
        dy = -(_random.nextDouble() * 2 + 1);
        break;
    }

    setState(() {
      _bubbles.add(Bubble(
        x: x,
        y: y,
        size: _random.nextDouble() * 30 + 20,
        controller: AnimationController(
          duration: const Duration(seconds: 3),
          vsync: this,
        ),
        type: type,
        dx: dx,
        dy: dy,
      ));
      _bubbles.last.controller.forward();
    });
  }

  void _endGame() {
    _timer?.cancel();
    _bubbleTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
    
    // 显示游戏结束对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('游戏结束'),
        content: Text('你的得分是: $_score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _popBubble(int index) {
    if (!_isPlaying) return;
    
    setState(() {
      // 根据泡泡类型计算分数
      switch (_bubbles[index].type) {
        case BubbleType.normal:
          _score += 1;
          break;
        case BubbleType.special:
          _score += 3;
          break;
        case BubbleType.bomb:
          _score = max(0, _score - 2); // 扣2分，但不低于0
          break;
      }

      // 播放破裂动画
      _bubbles[index].controller.reverse().then((_) {
        setState(() {
          _bubbles.removeAt(index);
        });
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bubbleTimer?.cancel();
    for (var bubble in _bubbles) {
      bubble.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('泡泡游戏'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('得分: $_score'),
                Text('剩余时间: $_timeLeft秒'),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ...List.generate(_bubbles.length, (index) {
                  return AnimatedBuilder(
                    animation: _bubbles[index].controller,
                    builder: (context, child) {
                      return Positioned(
                        left: _bubbles[index].x + (_bubbles[index].dx * 100 * _bubbles[index].controller.value),
                        top: _bubbles[index].y + (_bubbles[index].dy * 100 * _bubbles[index].controller.value),
                        child: GestureDetector(
                          onTap: () => _popBubble(index),
                          child: Transform.scale(
                            scale: _bubbles[index].controller.value,
                            child: Container(
                              width: _bubbles[index].size,
                              height: _bubbles[index].size,
                              decoration: BoxDecoration(
                                color: _bubbleColors[_bubbles[index].type]!.withOpacity(0.6),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _bubbleColors[_bubbles[index].type]!.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _bubbles[index].type == BubbleType.bomb
                                  ? const Icon(Icons.warning, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isPlaying ? null : _startGame,
        tooltip: '开始游戏',
        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}

class Bubble {
  final double x;
  final double y;
  final double size;
  final AnimationController controller;
  final BubbleType type;
  final double dx;
  final double dy;

  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.controller,
    required this.type,
    required this.dx,
    required this.dy,
  });
} 