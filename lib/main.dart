import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/notification_helper.dart';

void main() {
  runApp(const CuteTodoApp());
}

/// 앱 메인 위젯
typedef MyApp = CuteTodoApp;

class CuteTodoApp extends StatelessWidget {
  const CuteTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '귀여운 투두리스트',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF9F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8DA1),
          primary: const Color(0xFFFF7597),
          secondary: const Color(0xFFFFB3C6),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF9F5),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF4A3E3D),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF4A3E3D)),
        ),
      ),
      home: const CuteTodoHomePage(),
    );
  }
}

/// 투두 아이템 모델
class TodoItem {
  final String id;
  String title;
  String category;
  TimeOfDay? time;
  bool isCompleted;
  bool isNotified;
  final DateTime createdAt;

  TodoItem({
    required this.id,
    required this.title,
    this.category = '일상 🍀',
    this.time,
    this.isCompleted = false,
    this.isNotified = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  TodoItem copyWith({
    String? id,
    String? title,
    String? category,
    TimeOfDay? time,
    bool? isCompleted,
    bool? isNotified,
    DateTime? createdAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      isNotified: isNotified ?? this.isNotified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'time': time != null ? {'hour': time!.hour, 'minute': time!.minute} : null,
      'isCompleted': isCompleted,
      'isNotified': isNotified,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parsedTime;
    if (json['time'] != null) {
      final t = json['time'] as Map<String, dynamic>;
      parsedTime = TimeOfDay(
        hour: t['hour'] as int,
        minute: t['minute'] as int,
      );
    }
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String? ?? '일상 🍀',
      time: parsedTime,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isNotified: json['isNotified'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// 홈 페이지 위젯
class CuteTodoHomePage extends StatefulWidget {
  const CuteTodoHomePage({super.key});

  @override
  State<CuteTodoHomePage> createState() => _CuteTodoHomePageState();
}

class _CuteTodoHomePageState extends State<CuteTodoHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const String _storageKey = 'cute_todos_list_v1';

  // 할 일 목록 (SharedPreferences에서 로컬 로드/저장)
  final List<TodoItem> _todos = [];
  bool _isLoading = true;
  Timer? _alarmTimer;

  // 초기 실행 시 제공되는 귀여운 기본 샘플 목록
  static List<TodoItem> get _defaultSampleTodos => [
    TodoItem(
      id: '1',
      title: '아침 스트레칭 & 물 한 잔 마시기',
      category: '운동 🏃',
      time: const TimeOfDay(hour: 8, minute: 0),
      isCompleted: true,
    ),
    TodoItem(
      id: '2',
      title: '귀여운 투두리스트 기능 살펴보기 ✨',
      category: '일상 🍀',
      time: const TimeOfDay(hour: 9, minute: 30),
      isCompleted: true,
    ),
    TodoItem(
      id: '3',
      title: 'Flutter 공부 및 위젯 실습하기 💻',
      category: '공부 📚',
      time: const TimeOfDay(hour: 14, minute: 0),
      isCompleted: false,
    ),
    TodoItem(
      id: '4',
      title: '토롱이랑 저녁 산책 다녀오기 🐾',
      category: '약속 ☕',
      time: const TimeOfDay(hour: 18, minute: 30),
      isCompleted: false,
    ),
    TodoItem(
      id: '5',
      title: '잠들기 전 일기 한 줄 적기 🌙',
      category: '일상 🍀',
      time: const TimeOfDay(hour: 22, minute: 0),
      isCompleted: false,
    ),
  ];

  // 캐릭터 대화 메시지 상태
  String _characterMessage = '안녕! 오늘도 토롱이랑 알찬 하루 보내볼까? 🥕';
  int _characterTapCount = 0;

  // 사용 가능한 카테고리 목록
  final List<String> _categories = [
    '일상 🍀',
    '공부 📚',
    '업무 💻',
    '운동 🏃',
    '약속 ☕',
    '쇼핑 🛒',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _updateCharacterMessageGreeting();
    _loadTodos();
    _startAlarmTimer();
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // 5초 간격으로 마감 시간 알람 확인
  void _startAlarmTimer() {
    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkAlarmTimes();
    });
  }

  // 마감 시간에 도달한 미완료 할 일 확인
  void _checkAlarmTimes() {
    if (!mounted) return;
    final now = DateTime.now();

    for (final item in _incompleteTodos) {
      if (item.time != null && !item.isNotified) {
        if (now.hour == item.time!.hour && now.minute == item.time!.minute) {
          item.isNotified = true;
          _saveTodos();
          _triggerAlarm(item);
          break; // 알람 창이 중첩되지 않도록 한 번에 하나씩 실행
        }
      }
    }
  }

  // 마감 시간 푸시 알람 & 오디오 차임벨 & 대화창 발생
  void _triggerAlarm(TodoItem item) {
    // 1. 크롬 브라우저 푸시 알림 발송
    NotificationHelper.showNotification(
      '⏰ 토롱이 마감 알람 도착!',
      '\'${item.title}\' 마감 시간이에요! 서둘러서 완료해볼까요? 🥕',
    );

    // 2. 맑은 딩동~ 3화음 신디사이저 사운드 재생
    NotificationHelper.playAlarmSound();

    // 3. 토롱이 캐릭터 대화창 멘트 변경
    setState(() {
      _characterMessage = '⏰ 띠링! \'${item.title}\' 마감 시간이야! 얼른 확인해봐~ 🥕';
    });

    // 4. 귀여운 인앱 알람 다이얼로그 팝업
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0F4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm_on_rounded, color: Color(0xFFFF7597), size: 28),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '마감 시간 알람! ⏰',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF4A3E3D),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.category,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF7597),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A3E3D),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '약속했던 마감 시간 (${_formatTimeOfDay(item.time!)})이 되었습니다!\n토롱이랑 함께 지금 바로 끝내볼까요? 🥕',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7597),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('지금 완료하기 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _toggleTodoStatus(item);
            },
          ),
        ],
      ),
    );
  }

  // 타임피커(TimePicker)를 즉시 띄워 마감 시간 설정
  Future<void> _pickTimeForTodo(TodoItem item) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: item.time ?? TimeOfDay.now(),
      helpText: '마감 시간 설정',
      cancelText: '취소',
      confirmText: '설정 완료',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF7597),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF4A3E3D),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        item.time = picked;
        item.isNotified = false; // 새로운 시간 설정 시 알람 상태 초기화
        _characterMessage = '⏰ \'${item.title}\' 마감 시간을 ${_formatTimeOfDay(picked)}으로 맞췄어!';
      });
      _saveTodos();
    }
  }

  // 브라우저 알림 설정 및 테스트 다이얼로그
  void _openNotificationSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isGranted = NotificationHelper.hasPermission;
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.notifications_active_rounded, color: Color(0xFFFF7597)),
                  SizedBox(width: 8),
                  Text(
                    '알림 설정 & 테스트',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4A3E3D)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '마감 시간이 되면 브라우저 푸시 알림과 딩동~ 멜로디가 함께 울려요! ⏰',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5A4D4B), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isGranted ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isGranted ? const Color(0xFF86EFAC) : const Color(0xFFFDBA74),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isGranted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          color: isGranted ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isGranted ? '브라우저 알림 권한 허용됨' : '브라우저 알림 권한 미허용',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isGranted ? Colors.green.shade800 : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!isGranted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7597),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.notification_add_rounded, size: 18),
                        label: const Text('브라우저 알림 허용하기'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final granted = await NotificationHelper.requestPermission();
                          setDialogState(() {});
                          if (granted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('브라우저 푸시 알림 권한이 허용되었습니다! 🥕')),
                            );
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF7597),
                        side: const BorderSide(color: Color(0xFFFF7597)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: const Text('알람 & 멜로디 테스트 울리기 🎵'),
                      onPressed: () {
                        NotificationHelper.playAlarmSound();
                        NotificationHelper.showNotification(
                          '🥕 토롱이 테스트 알림',
                          '알림과 멜로디가 정상적으로 작동해요! ✨',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('딩동~ 멜로디와 테스트 알림이 울렸어요! 🔔'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // SharedPreferences에서 할 일 목록 로드
  Future<void> _loadTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
        final loaded = decoded
            .map((item) => TodoItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _todos.clear();
            _todos.addAll(loaded);
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('할 일 목록 불러오기 실패: $e');
    }

    // 로컬에 저장된 기록이 없는 첫 실행일 경우 기본 샘플 데이터 적용 및 저장
    if (mounted) {
      setState(() {
        _todos.clear();
        _todos.addAll(_defaultSampleTodos);
        _isLoading = false;
      });
      _saveTodos();
    }
  }

  // SharedPreferences에 할 일 목록 자동 저장
  Future<void> _saveTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _todos.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('할 일 목록 저장 실패: $e');
    }
  }

  // 시간에 따른 기본 인사말
  void _updateCharacterMessageGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      _characterMessage = '상쾌한 아침이야! 오늘도 토롱이랑 힘내보자구~ ☀️';
    } else if (hour >= 11 && hour < 17) {
      _characterMessage = '나른한 오후지만 힘내! 물 한잔 마시고 스트레칭 헛둘! 💧';
    } else if (hour >= 17 && hour < 22) {
      _characterMessage = '벌써 저녁이네! 남은 할 일도 차근차근 끝내볼까? 🌆';
    } else {
      _characterMessage = '포근한 밤이야. 오늘 하루도 정말 고생 많았어 토닥토닥 🌙';
    }
  }

  // 미완료 / 완료 목록 분리
  List<TodoItem> get _incompleteTodos =>
      _todos.where((item) => !item.isCompleted).toList();

  List<TodoItem> get _completedTodos =>
      _todos.where((item) => item.isCompleted).toList();

  // 할 일 추가
  void _addTodo(String title, String category, TimeOfDay? time) {
    setState(() {
      _todos.insert(
        0,
        TodoItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          category: category,
          time: time,
          isCompleted: false,
        ),
      );
      _characterMessage = '새로운 목표를 추가했어! 차근차근 해보자구~ 🥕';
    });
    _saveTodos();
  }

  // 할 일 수정
  void _editTodo(TodoItem item, String newTitle, String newCategory, TimeOfDay? newTime) {
    setState(() {
      item.title = newTitle;
      item.category = newCategory;
      item.time = newTime;
      _characterMessage = '할 일을 깔끔하게 수정했어! 멋져~ ✨';
    });
    _saveTodos();
  }

  // 완료 상태 토글
  void _toggleTodoStatus(TodoItem item) {
    setState(() {
      item.isCompleted = !item.isCompleted;
      if (item.isCompleted) {
        final cheeringMessages = [
          '우와! 하나 해냈다! 최고야 최고! 🥳🎉',
          '짝짝짝! 한 걸음 더 나아갔어! 대단해~ 💖',
          '해냈구나! 이 기세로 다음 것도 파이팅! 🚀',
          '토롱이도 신나서 깡총깡총 뛰는 중! 🐰✨',
        ];
        _characterMessage = cheeringMessages[math.Random().nextInt(cheeringMessages.length)];

        // 모든 할 일이 완료되었을 때 축하 메시지
        if (_incompleteTodos.isEmpty && _todos.isNotEmpty) {
          _characterMessage = '만세!! 오늘 할 일을 전부 끝마쳤어! 넌 정말 최고야 🏆🎉';
        }
      } else {
        _characterMessage = '다시 차근차근 진행해보자! 응원할게~ 🌱';
      }
    });
    _saveTodos();
  }

  // 할 일 삭제
  void _deleteTodo(TodoItem item) {
    final deletedItem = item;
    final deletedIndex = _todos.indexOf(item);

    setState(() {
      _todos.remove(item);
      _characterMessage = '할 일을 정리했어! 가벼운 마음으로 다시 가보자 🍃';
    });
    _saveTodos();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('\'${deletedItem.title}\' 삭제됨'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF4A3E3D),
        action: SnackBarAction(
          label: '실행 취소',
          textColor: const Color(0xFFFFB3C6),
          onPressed: () {
            setState(() {
              _todos.insert(deletedIndex, deletedItem);
              _characterMessage = '휴~ 방금 삭제한 일을 다시 복구했어! 다행이다 🍀';
            });
            _saveTodos();
          },
        ),
      ),
    );
  }

  // 완료된 할 일 전체 삭제
  void _clearCompletedTodos() {
    if (_completedTodos.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🧹 ', style: TextStyle(fontSize: 22)),
            Text('완료 목록 비우기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text('완료된 할 일을 모두 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7597),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _todos.removeWhere((item) => item.isCompleted);
                _characterMessage = '완료된 일들을 모두 정리해서 방이 깨끗해졌어! 🧼✨';
              });
              _saveTodos();
            },
            child: const Text('모두 비우기'),
          ),
        ],
      ),
    );
  }

  // 캐릭터 터치 반응
  void _onTapCharacter() {
    setState(() {
      _characterTapCount++;
      final tapMessages = [
        '간지러워요 헤헤~ 즐거운 하루 보내고 있나요? 🌸',
        '토롱이는 언제나 당신 편이에요! 든든하죠? 🥰',
        '당근 하나 드실래요? 🥕 행운이 듬뿍 담겨있답니다!',
        '오늘도 반짝반짝 빛나는 당신을 응원해요! ⭐',
        '작은 목표부터 하나씩 이루다 보면 큰 꿈도 이룰 수 있어요! 🌈',
        '어려운 일이 있다면 잠시 쉬어가도 괜찮아요 토닥토닥 ☁️',
      ];
      _characterMessage = tapMessages[_characterTapCount % tapMessages.length];
    });
  }

  // 시간 포맷 변환 헬퍼 (오전/오후 HH:MM)
  String _formatTimeOfDay(TimeOfDay time) {
    final period = time.hour < 12 ? '오전' : '오후';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period $hour:$minute';
  }

  // 할 일 추가/수정 다이얼로그 열기
  void _openTodoDialog({TodoItem? existingItem}) {
    final isEditing = existingItem != null;
    final titleController = TextEditingController(text: existingItem?.title ?? '');
    String selectedCategory = existingItem?.category ?? _categories.first;
    TimeOfDay? selectedTime = existingItem?.time;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 핸들 바
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 헤더 타이틀
                    Row(
                      children: [
                        Text(
                          isEditing ? '✏️ 할 일 수정하기' : '🥕 새로운 할 일 등록',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A3E3D),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 제목 입력 필드
                    TextField(
                      controller: titleController,
                      autofocus: !isEditing,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '무슨 일을 해볼까요? (예: 책 20페이지 읽기)',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFFFF7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 카테고리 선택
                    const Text(
                      '카테고리 선택',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A3E3D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _categories.map((cat) {
                        final isSelected = selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? Colors.white : const Color(0xFF5A4D4B),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFF7597),
                          backgroundColor: const Color(0xFFFFF0F4),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() {
                                selectedCategory = cat;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 시간 설정 섹션
                    const Row(
                      children: [
                        Text(
                          '마감 시간 설정 (타임피커)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A3E3D),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '🔔 마감 시 푸시 알람',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7597),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                          helpText: '마감 시간 설정',
                          cancelText: '취소',
                          confirmText: '설정 완료',
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFFFF7597),
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Color(0xFF4A3E3D),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFE0E8)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_filled_rounded,
                              color: selectedTime != null
                                  ? const Color(0xFFFF7597)
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedTime != null
                                        ? _formatTimeOfDay(selectedTime!)
                                        : '시간 미지정 (터치하여 설정)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: selectedTime != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: selectedTime != null
                                          ? const Color(0xFF4A3E3D)
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedTime != null
                                        ? '마감 시간에 브라우저 푸시 알람이 울려요! ⏰'
                                        : '시간을 지정하면 마감 시간에 푸시 알람을 울려드려요',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: selectedTime != null
                                          ? const Color(0xFFFF7597)
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedTime != null)
                              IconButton(
                                tooltip: '시간 지우기',
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                onPressed: () {
                                  setModalState(() {
                                    selectedTime = null;
                                  });
                                },
                              ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7597),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime ?? TimeOfDay.now(),
                                  helpText: '마감 시간 설정',
                                  cancelText: '취소',
                                  confirmText: '설정 완료',
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFFFF7597),
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Color(0xFF4A3E3D),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    selectedTime = picked;
                                  });
                                }
                              },
                              icon: const Icon(Icons.schedule_rounded, size: 16),
                              label: Text(
                                selectedTime != null ? '변경' : '타임피커',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7597),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          final text = titleController.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('할 일 내용을 적어주세요! 🥕'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            return;
                          }

                          if (isEditing) {
                            _editTodo(existingItem, text, selectedCategory, selectedTime);
                          } else {
                            _addTodo(text, selectedCategory, selectedTime);
                          }
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          isEditing ? '수정 완료하기 ✨' : '토롱이에게 등록하기 🥕',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFF7597)),
              SizedBox(height: 16),
              Text(
                '토롱이가 할 일 목록을 불러오는 중... 🥕',
                style: TextStyle(
                  color: Color(0xFF4A3E3D),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalCount = _todos.length;
    final doneCount = _completedTodos.length;
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🐰 ', style: TextStyle(fontSize: 22)),
            Text(
              '귀여운 투두리스트',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: '알림 설정 및 테스트',
            onPressed: _openNotificationSettingsDialog,
          ),
          if (_tabController.index == 1 && _completedTodos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '완료 항목 비우기',
              onPressed: _clearCompletedTodos,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 귀여운 토롱이 캐릭터 & 말풍선 대화창 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CharacterDialogueWidget(
                message: _characterMessage,
                onTapCharacter: _onTapCharacter,
              ),
            ),

            // 2. 오늘의 달성률 프로그레스 바 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8DA1).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🌱 ', style: TextStyle(fontSize: 14)),
                            Text(
                              '오늘의 달성률 ${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A3E3D),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$doneCount / $totalCount 완료',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFFFF0F3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF7597)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 3. 미완료 / 완료 탭 버튼 (목록 분리)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECE7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFFFF7597),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7597).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF6E5F5D),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.edit_calendar_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text('진행 중 (${_incompleteTodos.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.task_alt_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text('완료됨 (${_completedTodos.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. 할 일 목록 리스트뷰 (탭 뷰)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 미완료 목록 탭
                  _buildIncompleteTodoList(),
                  // 완료 목록 탭
                  _buildCompletedTodoList(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTodoDialog(),
        backgroundColor: const Color(0xFFFF7597),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          '할 일 추가',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  // 미완료 할 일 리스트
  Widget _buildIncompleteTodoList() {
    final list = _incompleteTodos;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              '모든 할 일을 마쳤어요!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A3E3D),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '새로운 목표를 추가하거나\n토롱이랑 여유로운 휴식을 즐겨보세요 ☕',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openTodoDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8DA1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('새 할 일 만들기'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 80),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildTodoCard(item);
      },
    );
  }

  // 완료된 할 일 리스트
  Widget _buildCompletedTodoList() {
    final list = _completedTodos;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              '아직 완료한 일이 없어요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A3E3D),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '진행 중인 할 일을 체크해서\n하나씩 달성해보세요! 토롱이가 응원해요 💪',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 80),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildTodoCard(item);
      },
    );
  }

  // 개별 투두 카드
  Widget _buildTodoCard(TodoItem item) {
    final isDone = item.isCompleted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone ? Colors.grey.shade200 : const Color(0xFFFFE3EA),
          width: 1.5,
        ),
        boxShadow: [
          if (!isDone)
            BoxShadow(
              color: const Color(0xFFFF8DA1).withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _toggleTodoStatus(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 귀여운 체크박스 (하트/체크 스타일)
                GestureDetector(
                  onTap: () => _toggleTodoStatus(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? const Color(0xFFFF7597) : const Color(0xFFFFF0F4),
                      border: Border.all(
                        color: isDone ? const Color(0xFFFF7597) : const Color(0xFFFFB3C6),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isDone ? Icons.check_rounded : Icons.favorite_border_rounded,
                        size: 18,
                        color: isDone ? Colors.white : const Color(0xFFFF8DA1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 내용 본문
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 카테고리 태그 & 시간 태그
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? Colors.grey.shade200
                                  : const Color(0xFFFFF1F4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDone
                                    ? Colors.grey.shade600
                                    : const Color(0xFFFF7597),
                              ),
                            ),
                          ),
                          if (item.time != null) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: '마감 시간 변경 (타임피커 열기)',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: isDone ? null : () => _pickTimeForTodo(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDone
                                        ? Colors.grey.shade200
                                        : const Color(0xFFEFF8FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDone ? Colors.transparent : const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.alarm_rounded,
                                        size: 12,
                                        color: isDone
                                            ? Colors.grey.shade500
                                            : const Color(0xFF3B82F6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimeOfDay(item.time!),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDone
                                              ? Colors.grey.shade500
                                              : const Color(0xFF3B82F6),
                                        ),
                                      ),
                                      if (!isDone) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.edit_rounded,
                                          size: 10,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ] else if (!isDone) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: '마감 시간 설정 (타임피커 열기)',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _pickTimeForTodo(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFED7AA), width: 1),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_alarm_rounded, size: 12, color: Color(0xFFF97316)),
                                      SizedBox(width: 4),
                                      Text(
                                        '시간 설정',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFEA580C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 할 일 텍스트
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDone ? Colors.grey.shade400 : const Color(0xFF4A3E3D),
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),

                // 수정/삭제 버튼
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: Colors.grey.shade500,
                      tooltip: '수정',
                      onPressed: () => _openTodoDialog(existingItem: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: Colors.grey.shade400,
                      tooltip: '삭제',
                      onPressed: () => _deleteTodo(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 귀여운 캐릭터와 말풍선 대화창 위젯
class CharacterDialogueWidget extends StatefulWidget {
  final String message;
  final VoidCallback onTapCharacter;

  const CharacterDialogueWidget({
    super.key,
    required this.message,
    required this.onTapCharacter,
  });

  @override
  State<CharacterDialogueWidget> createState() => _CharacterDialogueWidgetState();
}

class _CharacterDialogueWidgetState extends State<CharacterDialogueWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _triggerBounce() {
    _bounceController.forward().then((_) => _bounceController.reverse());
    widget.onTapCharacter();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8DA1).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 캐릭터 (토롱이)
          GestureDetector(
            onTap: _triggerBounce,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Tooltip(
                message: '토롱이를 터치해봐요!',
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: CustomPaint(
                    painter: BunnyPainter(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // 말풍선 대화창
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F9),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: const Color(0xFFFFDCE4), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '토롱이의 한마디',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7597),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '터치 반응 💖',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      widget.message,
                      key: ValueKey<String>(widget.message),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A3E3D),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 귀여운 토끼 캐릭터 CustomPainter
class BunnyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);

    final earPaint = Paint()
      ..color = const Color(0xFFFFF2EC)
      ..style = PaintingStyle.fill;

    final earInnerPaint = Paint()
      ..color = const Color(0xFFFFB3C6)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFE8C8B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final blushPaint = Paint()
      ..color = const Color(0xFFFF7597).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final eyePaint = Paint()
      ..color = const Color(0xFF3A2E2C)
      ..style = PaintingStyle.fill;

    final eyeSparklePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final nosePaint = Paint()
      ..color = const Color(0xFFFF7597)
      ..style = PaintingStyle.fill;

    final mouthPaint = Paint()
      ..color = const Color(0xFF5A4542)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // 1. 왼쪽 귀
    canvas.save();
    canvas.translate(size.width * 0.35, size.height * 0.28);
    canvas.rotate(-0.12);
    final leftEarRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 0.22,
      height: size.height * 0.42,
    );
    canvas.drawOval(leftEarRect, earPaint);
    canvas.drawOval(leftEarRect, strokePaint);

    final leftEarInnerRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 0.12,
      height: size.height * 0.28,
    );
    canvas.drawOval(leftEarInnerRect, earInnerPaint);
    canvas.restore();

    // 2. 오른쪽 귀
    canvas.save();
    canvas.translate(size.width * 0.65, size.height * 0.28);
    canvas.rotate(0.12);
    final rightEarRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 0.22,
      height: size.height * 0.42,
    );
    canvas.drawOval(rightEarRect, earPaint);
    canvas.drawOval(rightEarRect, strokePaint);

    final rightEarInnerRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 0.12,
      height: size.height * 0.28,
    );
    canvas.drawOval(rightEarInnerRect, earInnerPaint);
    canvas.restore();

    // 3. 얼굴 (통통한 원형)
    final headRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.74,
      height: size.height * 0.64,
    );
    canvas.drawOval(headRect, earPaint);
    canvas.drawOval(headRect, strokePaint);

    // 4. 발그레 볼터치
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.26, size.height * 0.64),
        width: size.width * 0.16,
        height: size.height * 0.09,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.74, size.height * 0.64),
        width: size.width * 0.16,
        height: size.height * 0.09,
      ),
      blushPaint,
    );

    // 5. 초롱초롱한 눈
    // 왼쪽 눈
    final leftEyeCenter = Offset(size.width * 0.35, size.height * 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: leftEyeCenter,
        width: size.width * 0.09,
        height: size.height * 0.12,
      ),
      eyePaint,
    );
    canvas.drawCircle(
      Offset(leftEyeCenter.dx - 1.5, leftEyeCenter.dy - 2),
      2.2,
      eyeSparklePaint,
    );

    // 오른쪽 눈
    final rightEyeCenter = Offset(size.width * 0.65, size.height * 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: rightEyeCenter,
        width: size.width * 0.09,
        height: size.height * 0.12,
      ),
      eyePaint,
    );
    canvas.drawCircle(
      Offset(rightEyeCenter.dx - 1.5, rightEyeCenter.dy - 2),
      2.2,
      eyeSparklePaint,
    );

    // 6. 조그만 코 (하트/삼각형 느낌)
    final noseCenter = Offset(size.width * 0.50, size.height * 0.61);
    final nosePath = Path()
      ..moveTo(noseCenter.dx - 3, noseCenter.dy - 2)
      ..lineTo(noseCenter.dx + 3, noseCenter.dy - 2)
      ..lineTo(noseCenter.dx, noseCenter.dy + 2)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // 7. 깜찍한 :3 입모양
    final mouthPath = Path();
    // 왼쪽 곡선
    mouthPath.moveTo(noseCenter.dx - 7, noseCenter.dy + 4);
    mouthPath.quadraticBezierTo(
      noseCenter.dx - 3.5,
      noseCenter.dy + 8,
      noseCenter.dx,
      noseCenter.dy + 4,
    );
    // 오른쪽 곡선
    mouthPath.quadraticBezierTo(
      noseCenter.dx + 3.5,
      noseCenter.dy + 8,
      noseCenter.dx + 7,
      noseCenter.dy + 4,
    );
    canvas.drawPath(mouthPath, mouthPaint);

    // 8. 귀여운 리본 악세서리 (오른쪽 귀 아래)
    final ribbonPaint = Paint()
      ..color = const Color(0xFFFF5277)
      ..style = PaintingStyle.fill;
    final ribbonCenter = Offset(size.width * 0.72, size.height * 0.36);
    canvas.drawCircle(ribbonCenter, 3.5, ribbonPaint);
    final leftRibbonWing = Path()
      ..moveTo(ribbonCenter.dx, ribbonCenter.dy)
      ..lineTo(ribbonCenter.dx - 7, ribbonCenter.dy - 4)
      ..lineTo(ribbonCenter.dx - 7, ribbonCenter.dy + 4)
      ..close();
    canvas.drawPath(leftRibbonWing, ribbonPaint);
    final rightRibbonWing = Path()
      ..moveTo(ribbonCenter.dx, ribbonCenter.dy)
      ..lineTo(ribbonCenter.dx + 7, ribbonCenter.dy - 4)
      ..lineTo(ribbonCenter.dx + 7, ribbonCenter.dy + 4)
      ..close();
    canvas.drawPath(rightRibbonWing, ribbonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
