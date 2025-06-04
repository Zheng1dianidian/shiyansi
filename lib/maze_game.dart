import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';  // 添加键盘控制相关的导入

// 游戏主题
enum GameTheme {
  fantasy,    // 幻想世界
  scifi,      // 科幻未来
  ancient     // 古代遗迹
}

// 道具类型
enum ItemType {
  vision,     // 透视道具
  bomb,       // 炸弹道具
  speed       // 速度道具
}

// 游戏状态
enum GameState {
  playing,    // 游戏中
  paused,     // 暂停
  completed,  // 完成
  failed      // 失败
}

class MazeGame extends StatefulWidget {
  const MazeGame({super.key});

  @override
  State<MazeGame> createState() => _MazeGameState();
}

class _MazeGameState extends State<MazeGame> {
  // 游戏配置
  static const int cellSize = 40;  // 单元格大小
  static const int initialMazeSize = 15;  // 增加初始迷宫大小
  int currentLevel = 1;  // 当前关卡
  int mazeSize = initialMazeSize;  // 迷宫大小
  int timeLimit = 120;  // 时间限制（秒）
  int remainingTime = 120;  // 剩余时间
  int score = 0;  // 分数
  int treasuresCollected = 0;  // 收集的宝藏数量
  int requiredTreasures = 3;  // 需要收集的宝藏数量
  
  // 游戏状态
  GameState gameState = GameState.playing;
  GameTheme currentTheme = GameTheme.fantasy;
  
  // 玩家位置
  int playerX = 1;
  int playerY = 1;
  
  // 怪物移动
  List<Monster> monsters = [];
  Timer? monsterTimer;
  
  // 道具
  Map<ItemType, int> items = {
    ItemType.vision: 0,
    ItemType.bomb: 0,
    ItemType.speed: 0,
  };
  
  // 迷宫数据
  List<List<bool>> maze = [];
  List<List<bool>> treasures = [];
  
  // 计时器
  Timer? gameTimer;
  bool isSpeedBoosted = false;
  FocusNode focusNode = FocusNode();  // 添加焦点节点
  
  @override
  void initState() {
    super.initState();
    _initializeGame();
  }
  
  void _initializeGame() {
    // 生成迷宫
    _generateMaze();
    // 放置宝藏
    _placeTreasures();
    // 放置怪物
    _placeMonsters();
    // 开始计时
    _startTimer();
    // 开始怪物移动
    _startMonsterMovement();
  }
  
  void _generateMaze() {
    // 初始化迷宫数组
    maze = List.generate(mazeSize, (_) => List.filled(mazeSize, true));
    treasures = List.generate(mazeSize, (_) => List.filled(mazeSize, false));
    
    // 使用深度优先搜索生成迷宫
    _dfs(1, 1);
    
    // 确保起点和终点是通路
    maze[1][1] = false;
    maze[mazeSize - 2][mazeSize - 2] = false;
    
    // 添加一些随机的额外通道，增加复杂度
    int extraPaths = mazeSize ~/ 2;
    for (int i = 0; i < extraPaths; i++) {
      int x = Random().nextInt(mazeSize - 2) + 1;
      int y = Random().nextInt(mazeSize - 2) + 1;
      if (maze[y][x]) {
        maze[y][x] = false;
      }
    }
  }
  
  void _dfs(int x, int y) {
    maze[y][x] = false;
    
    // 四个方向：上、右、下、左
    List<Point<int>> directions = [
      Point(0, -2), Point(2, 0), Point(0, 2), Point(-2, 0)
    ];
    directions.shuffle();
    
    for (var dir in directions) {
      int newX = x + dir.x;
      int newY = y + dir.y;
      
      if (newX > 0 && newX < mazeSize - 1 && newY > 0 && newY < mazeSize - 1
          && maze[newY][newX]) {
        maze[y + dir.y ~/ 2][x + dir.x ~/ 2] = false;
        _dfs(newX, newY);
      }
    }
  }
  
  void _placeTreasures() {
    int placed = 0;
    while (placed < requiredTreasures) {
      int x = Random().nextInt(mazeSize - 2) + 1;
      int y = Random().nextInt(mazeSize - 2) + 1;
      
      if (!maze[y][x] && !treasures[y][x] && (x != 1 || y != 1)) {
        treasures[y][x] = true;
        placed++;
      }
    }
  }
  
  void _placeMonsters() {
    monsters.clear();
    int monsterCount = currentLevel + 1;  // 每关增加一个怪物
    for (int i = 0; i < monsterCount; i++) {
      int x, y;
      do {
        x = Random().nextInt(mazeSize - 2) + 1;
        y = Random().nextInt(mazeSize - 2) + 1;
      } while (maze[y][x] || treasures[y][x] || (x == 1 && y == 1));
      
      monsters.add(Monster(
        x: x,
        y: y,
        direction: Random().nextInt(4),  // 0: 上, 1: 右, 2: 下, 3: 左
        speed: 1 + (currentLevel ~/ 3),  // 每3关增加速度
      ));
    }
  }
  
  void _startTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (gameState == GameState.playing) {
        setState(() {
          if (remainingTime > 0) {
            remainingTime--;
          } else {
            _gameOver(false);
          }
        });
      }
    });
  }
  
  void _startMonsterMovement() {
    monsterTimer?.cancel();
    monsterTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (gameState == GameState.playing) {
        setState(() {
          for (var monster in monsters) {
            _moveMonster(monster);
          }
        });
      }
    });
  }
  
  void _movePlayer(int dx, int dy) {
    if (gameState != GameState.playing) return;
    
    int newX = playerX + dx;
    int newY = playerY + dy;
    
    // 检查是否可以移动
    if (newX >= 0 && newX < mazeSize && newY >= 0 && newY < mazeSize
        && !maze[newY][newX]) {
      setState(() {
        playerX = newX;
        playerY = newY;
        
        // 检查是否收集到宝藏
        if (treasures[playerY][playerX]) {
          treasures[playerY][playerX] = false;
          treasuresCollected++;
          score += 100;
          
          // 检查是否收集完所有宝藏
          if (treasuresCollected >= requiredTreasures) {
            _checkLevelComplete();
          }
        }
        
        // 检查是否碰到怪物
        for (var monster in monsters) {
          if (monster.x == playerX && monster.y == playerY) {
            _gameOver(false);
          }
        }
        
        // 检查是否到达终点
        if (playerX == mazeSize - 2 && playerY == mazeSize - 2) {
          _checkLevelComplete();
        }
      });
    }
  }
  
  void _moveMonster(Monster monster) {
    // 尝试当前方向
    int newX = monster.x;
    int newY = monster.y;
    
    switch (monster.direction) {
      case 0: // 上
        newY--;
        break;
      case 1: // 右
        newX++;
        break;
      case 2: // 下
        newY++;
        break;
      case 3: // 左
        newX--;
        break;
    }
    
    // 检查是否可以移动
    if (newX >= 0 && newX < mazeSize && newY >= 0 && newY < mazeSize
        && !maze[newY][newX]) {
      monster.x = newX;
      monster.y = newY;
    } else {
      // 如果不能移动，随机选择新方向
      monster.direction = Random().nextInt(4);
    }
    
    // 检查是否碰到玩家
    if (monster.x == playerX && monster.y == playerY) {
      _gameOver(false);
    }
  }
  
  void _useItem(ItemType type) {
    if (items[type]! > 0) {
      setState(() {
        items[type] = items[type]! - 1;
        
        switch (type) {
          case ItemType.vision:
            // TODO: 实现透视效果
            break;
          case ItemType.bomb:
            // TODO: 实现炸弹效果
            break;
          case ItemType.speed:
            _activateSpeedBoost();
            break;
        }
      });
    }
  }
  
  void _activateSpeedBoost() {
    if (!isSpeedBoosted) {
      isSpeedBoosted = true;
      Future.delayed(const Duration(seconds: 5), () {
        setState(() {
          isSpeedBoosted = false;
        });
      });
    }
  }
  
  void _checkLevelComplete() {
    if (treasuresCollected >= requiredTreasures) {
      setState(() {
        gameState = GameState.completed;
        score += remainingTime * 10;  // 剩余时间转换为分数
        
        // 显示完成对话框
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('关卡完成！'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('得分: $score'),
                Text('剩余时间: $remainingTime 秒'),
                Text('收集宝藏: $treasuresCollected/$requiredTreasures'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _nextLevel();
                },
                child: const Text('下一关'),
              ),
            ],
          ),
        );
      });
    }
  }
  
  void _nextLevel() {
    setState(() {
      currentLevel++;
      mazeSize = initialMazeSize + (currentLevel ~/ 2) * 2;
      timeLimit = 120 + (currentLevel - 1) * 30;
      remainingTime = timeLimit;
      requiredTreasures = 3 + (currentLevel ~/ 2);
      treasuresCollected = 0;
      playerX = 1;
      playerY = 1;
      gameState = GameState.playing;
      _initializeGame();
    });
    // 确保在状态更新后重新设置焦点
    Future.microtask(() {
      focusNode.requestFocus();
    });
  }
  
  void _gameOver(bool success) {
    setState(() {
      gameState = success ? GameState.completed : GameState.failed;
      gameTimer?.cancel();
      monsterTimer?.cancel();
    });
    
    // 显示游戏结束对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(success ? '游戏胜利！' : '游戏结束'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('最终得分: $score'),
            Text('收集宝藏: $treasuresCollected/$requiredTreasures'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 使用 Future.microtask 确保在对话框完全关闭后再重置游戏
              Future.microtask(() {
                setState(() {
                  currentLevel = 1;
                  score = 0;
                  _initializeGame();
                });
                // 确保在状态更新后重新设置焦点
                Future.microtask(() {
                  focusNode.requestFocus();
                });
              });
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
    monsterTimer?.cancel();
    focusNode.dispose();  // 释放焦点节点
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('迷宫探险'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () {
              setState(() {
                gameState = gameState == GameState.playing
                    ? GameState.paused
                    : GameState.playing;
              });
              // 确保在状态更新后重新设置焦点
              if (gameState == GameState.playing) {
                Future.microtask(() {
                  focusNode.requestFocus();
                });
              }
            },
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: focusNode,
        autofocus: true,
        onKey: (event) {
          if (event is RawKeyDownEvent && gameState == GameState.playing) {
            switch (event.logicalKey) {
              case LogicalKeyboardKey.arrowUp:
                _movePlayer(0, -1);
                break;
              case LogicalKeyboardKey.arrowDown:
                _movePlayer(0, 1);
                break;
              case LogicalKeyboardKey.arrowLeft:
                _movePlayer(-1, 0);
                break;
              case LogicalKeyboardKey.arrowRight:
                _movePlayer(1, 0);
                break;
            }
          }
        },
        child: GestureDetector(
          onTap: () {
            if (gameState == GameState.playing) {
              focusNode.requestFocus();
            }
          },
          child: Column(
            children: [
              // 游戏信息
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('关卡: $currentLevel'),
                    Text('时间: $remainingTime'),
                    Text('分数: $score'),
                    Text('宝藏: $treasuresCollected/$requiredTreasures'),
                  ],
                ),
              ),
              
              // 道具栏
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildItemButton(ItemType.vision),
                    _buildItemButton(ItemType.bomb),
                    _buildItemButton(ItemType.speed),
                  ],
                ),
              ),
              
              // 迷宫
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: MazePainter(
                        maze: maze,
                        treasures: treasures,
                        monsters: monsters,
                        playerX: playerX,
                        playerY: playerY,
                        cellSize: cellSize.toDouble(),
                        theme: currentTheme,
                      ),
                    ),
                  ),
                ),
              ),
              
              // 操作说明
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '使用方向键控制角色移动',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildItemButton(ItemType type) {
    return ElevatedButton(
      onPressed: () => _useItem(type),
      child: Column(
        children: [
          Icon(_getItemIcon(type)),
          Text('${items[type]}'),
        ],
      ),
    );
  }
  
  IconData _getItemIcon(ItemType type) {
    switch (type) {
      case ItemType.vision:
        return Icons.visibility;
      case ItemType.bomb:
        return Icons.local_fire_department;
      case ItemType.speed:
        return Icons.speed;
    }
  }
}

// 怪物类
class Monster {
  int x;
  int y;
  int direction;
  int speed;
  
  Monster({
    required this.x,
    required this.y,
    required this.direction,
    required this.speed,
  });
}

class MazePainter extends CustomPainter {
  final List<List<bool>> maze;
  final List<List<bool>> treasures;
  final List<Monster> monsters;
  final int playerX;
  final int playerY;
  final double cellSize;
  final GameTheme theme;
  
  MazePainter({
    required this.maze,
    required this.treasures,
    required this.monsters,
    required this.playerX,
    required this.playerY,
    required this.cellSize,
    required this.theme,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    // 绘制迷宫
    for (int y = 0; y < maze.length; y++) {
      for (int x = 0; x < maze[y].length; x++) {
        if (maze[y][x]) {
          // 墙壁
          paint.color = _getWallColor();
          canvas.drawRect(
            Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
            paint,
          );
        } else {
          // 通道
          paint.color = _getPathColor();
          canvas.drawRect(
            Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
            paint,
          );
          
          // 绘制宝藏
          if (treasures[y][x]) {
            _drawTreasure(canvas, paint, x, y);
          }
        }
      }
    }
    
    // 绘制怪物
    for (var monster in monsters) {
      _drawMonster(canvas, paint, monster);
    }
    
    // 绘制玩家
    _drawPlayer(canvas, paint);
  }
  
  void _drawTreasure(Canvas canvas, Paint paint, int x, int y) {
    // 绘制宝箱
    paint.color = Colors.amber;
    canvas.drawRect(
      Rect.fromLTWH(
        (x + 0.2) * cellSize,
        (y + 0.2) * cellSize,
        cellSize * 0.6,
        cellSize * 0.6,
      ),
      paint,
    );
    // 绘制宝箱盖子
    paint.color = Colors.amber[700]!;
    canvas.drawRect(
      Rect.fromLTWH(
        (x + 0.2) * cellSize,
        (y + 0.2) * cellSize,
        cellSize * 0.6,
        cellSize * 0.2,
      ),
      paint,
    );
    // 绘制宝箱锁
    paint.color = Colors.brown[700]!;
    canvas.drawCircle(
      Offset((x + 0.5) * cellSize, (y + 0.4) * cellSize),
      cellSize * 0.1,
      paint,
    );
  }
  
  void _drawMonster(Canvas canvas, Paint paint, Monster monster) {
    final centerX = (monster.x + 0.5) * cellSize;
    final centerY = (monster.y + 0.5) * cellSize;
    
    // 绘制怪物身体
    paint.color = Colors.purple[700]!;
    canvas.drawCircle(
      Offset(centerX, centerY),
      cellSize * 0.3,
      paint,
    );
    
    // 绘制怪物眼睛
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(centerX - cellSize * 0.1, centerY - cellSize * 0.1),
      cellSize * 0.1,
      paint,
    );
    canvas.drawCircle(
      Offset(centerX + cellSize * 0.1, centerY - cellSize * 0.1),
      cellSize * 0.1,
      paint,
    );
    
    // 绘制怪物瞳孔
    paint.color = Colors.red;
    canvas.drawCircle(
      Offset(centerX - cellSize * 0.1, centerY - cellSize * 0.1),
      cellSize * 0.05,
      paint,
    );
    canvas.drawCircle(
      Offset(centerX + cellSize * 0.1, centerY - cellSize * 0.1),
      cellSize * 0.05,
      paint,
    );
    
    // 绘制怪物嘴巴
    paint.color = Colors.red[700]!;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX, centerY + cellSize * 0.1),
        width: cellSize * 0.3,
        height: cellSize * 0.2,
      ),
      0,
      3.14,
      false,
      paint,
    );
  }
  
  void _drawPlayer(Canvas canvas, Paint paint) {
    final centerX = (playerX + 0.5) * cellSize;
    final centerY = (playerY + 0.5) * cellSize;
    
    // 绘制身体
    paint.color = Colors.blue;
    canvas.drawCircle(
      Offset(centerX, centerY),
      cellSize * 0.3,
      paint,
    );
    
    // 绘制眼睛
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(centerX - cellSize * 0.1, centerY - cellSize * 0.1),
      cellSize * 0.1,
      paint,
    );
    canvas.drawCircle(
      Offset(centerX + cellSize * 0.1, centerY - cellSize * 0.1),
      cellSize * 0.1,
      paint,
    );
    
    // 绘制瞳孔
    paint.color = Colors.black;
    canvas.drawCircle(
      Offset(centerX - cellSize * 0.1, centerY - cellSize * 0.1),
      cellSize * 0.05,
      paint,
    );
    canvas.drawCircle(
      Offset(centerX + cellSize * 0.1, centerY - cellSize * 0.1),
      cellSize * 0.05,
      paint,
    );
    
    // 绘制嘴巴
    paint.color = Colors.red;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX, centerY + cellSize * 0.1),
        width: cellSize * 0.3,
        height: cellSize * 0.2,
      ),
      0,
      3.14,
      false,
      paint,
    );
  }
  
  Color _getWallColor() {
    switch (theme) {
      case GameTheme.fantasy:
        return Colors.brown[800]!;
      case GameTheme.scifi:
        return Colors.blueGrey[800]!;
      case GameTheme.ancient:
        return Colors.brown[900]!;
    }
  }
  
  Color _getPathColor() {
    switch (theme) {
      case GameTheme.fantasy:
        return Colors.brown[100]!;
      case GameTheme.scifi:
        return Colors.blueGrey[100]!;
      case GameTheme.ancient:
        return Colors.brown[200]!;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 