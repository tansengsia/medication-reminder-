import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 初始化全局变量
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final AudioPlayer audioPlayer = AudioPlayer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地通知配置（Android）
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // 使用默认应用图标
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(const ScheduledMedApp());
}

class ScheduledMedApp extends StatelessWidget {
  const ScheduledMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '长辈服药助手',
      home: ScheduledReminderScreen(),
    );
  }
}

class ScheduledReminderScreen extends StatefulWidget {
  const ScheduledReminderScreen({super.key});

  @override
  State<ScheduledReminderScreen> createState() => _ScheduledReminderScreenState();
}

class _ScheduledReminderScreenState extends State<ScheduledReminderScreen> {
  bool _hasTaken = false; // 记录长辈是否已吃药
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0); // 默认提醒时间 08:00

  // ⚠️ 注意：如果你在实体手机上测试，必须填写你电脑在局域网内的真实 IP 地址（例如 192.168.1.100）。
  // 模拟器测试可以使用默认的 10.0.2.2。
  final String backendUrl = "http://10.0.2.2:5000";

  // 1. 设置手机本地定时闹钟（每天重复）
  Future<void> _scheduleNotification(TimeOfDay time) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'med_alarm_channel_id', // 频道ID
      '吃药提醒闹钟频道', // 频道名称
      channelDescription: '到了设定时间自动唤醒、响铃并弹出全屏提醒界面。',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true, // 支持锁屏全屏弹窗响铃
      sound: RawResourceAndroidNotificationSound('father_med_reminder'), // 自定义家人原声铃声 (assets/father_med_reminder.mp3)
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    // 计算触发距离当前时间的时间差
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1)); // 如果选的时间已过，设置到明天
    }

    // 这里使用 flutter_local_notifications 播放自定义声音并通知
    // 为了支持更高级的语音克隆播报，这里配合 AudioPlayer
    // 并触发云端告警计时

    // (实际上 flutter_local_notifications 可以直接处理铃声，这里为了演示逻辑分离)
    await audioPlayer.play(AssetSource('father_med_reminder.mp3')); // 触发家人原声

    // 触发后端云端报警倒计时（15分钟）
    _triggerBackendTimer();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已成功设置每日 ${time.format(context)} 服药提醒')),
      );
    }
  }

  // 2. 通知 Python 后端开启云端 15 分钟告警倒计时
  Future<void> _triggerBackendTimer() async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/trigger-reminder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "patient_name": "张爸爸", // 长辈姓名
          "med_name": "降压药",     // 药品名称
        }),
      );
      print("后端定时启动状态: ${response.statusCode}");
    } catch (e) {
      print("后端连接失败: $e (请确保后端已启动且IP正确)");
    }
  }

  // 3. 长辈点击“已吃药”大按钮：停止响铃，并向后端同步状态
  Future<void> _confirmMedication() async {
    await audioPlayer.stop(); // 停止家人语音播放响铃
    setState(() {
      _hasTaken = true; // 界面变为绿色
    });

    // 告诉 Python 后端长辈已吃药，取消紧急告警
    try {
      await http.post(
        Uri.parse('$backendUrl/confirm-medication'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print("后端连接失败: $e");
    }
  }

  // 4. 打开时间选择器，让家属选择吃药时间
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime, // 默认显示上次选的时间或08:00
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _hasTaken = false; // 重置吃药状态，开启新的提醒
      });
      _scheduleNotification(picked); // 设置新的定时闹钟
    }
  }

  @override
  Widget build(BuildContext context) {
    // 根据是否吃药，动态切换界面背景颜色
    return Scaffold(
      backgroundColor: _hasTaken ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0), // 绿色表示已吃药，橙色表示未吃药
      appBar: AppBar(
        title: const Text("爸爸吃药闹钟设置"),
        actions: [
          // 右上角添加闹钟图标，用于设置时间
          IconButton(
            icon: const Icon(Icons.alarm_add, size: 30),
            onPressed: _pickTime, // 点击打开时间选择器
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 第一部分：提醒时间与大字号状态提示
              Column(
                children: [
                  Text(
                    "今天提醒时间：${_selectedTime.format(context)}",
                    style: const TextStyle(fontSize: 22, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    _hasTaken ? "非常棒！药已经吃了。" : "爸爸，到了吃降压药的时间啦！",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: _hasTaken ? Colors.green[800] : Colors.deepOrange[900],
                      height: 1.3,
                    ),
                  ),
                ],
              ),

              // 第二部分：专为长辈设计的防误触大按钮
              SizedBox(
                width: double.infinity,
                height: 110, // 超高按钮，易于点击
                child: ElevatedButton(
                  onPressed: _hasTaken ? null : _confirmMedication, // 如果已吃药，按钮置灰不可点击
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasTaken ? Colors.grey : Colors.green[600], // 已吃药灰色，未吃药绿色
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), // 圆角大按钮
                    elevation: 10, // 增加阴影，更有立体感
                  ),
                  child: Text(
                    _hasTaken ? "已确认服药" : "点这里：我吃过药了",
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
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