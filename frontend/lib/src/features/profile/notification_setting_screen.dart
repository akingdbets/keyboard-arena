import 'package:flutter/material.dart';
import 'notification_settings_model.dart';
import 'notification_service.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  // ▼▼▼ 에러 해결을 위해 이 줄을 추가했습니다! ▼▼▼
  static bool isMyProfilePublic = true;
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

  @override
  State<NotificationSettingScreen> createState() => _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  final NotificationService _notificationService = NotificationService();
  NotificationSettingsModel _settings = NotificationSettingsModel();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final savedSettings = await _notificationService.fetchSettings();
    if (mounted) {
      setState(() {
        _settings = savedSettings;
        _isLoading = false;
      });
    }
  }

  void _updateSetting({bool? isGlobal, bool? onPost, bool? onComment}) async {
    final newSettings = _settings.copyWith(
      isGlobalEnabled: isGlobal,
      notifyOnMyPost: onPost,
      notifyOnMyComment: onComment,
    );
    setState(() {
      _settings = newSettings;
    });
    await _notificationService.updateSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')), // 깨진 글자 복원
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('전체 알림 받기', style: TextStyle(fontWeight: FontWeight.bold)), // 깨진 글자 복원
                  value: _settings.isGlobalEnabled,
                  onChanged: (value) => _updateSetting(isGlobal: value),
                ),
                const Divider(),
                Opacity(
                  opacity: _settings.isGlobalEnabled ? 1.0 : 0.5,
                  child: IgnorePointer(
                    ignoring: !_settings.isGlobalEnabled,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('내 글 반응 알림'), // 깨진 글자 복원
                          value: _settings.notifyOnMyPost,
                          onChanged: (value) => _updateSetting(onPost: value),
                        ),
                        SwitchListTile(
                          title: const Text('내 댓글 반응 알림'), // 깨진 글자 복원
                          value: _settings.notifyOnMyComment,
                          onChanged: (value) => _updateSetting(onComment: value),
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