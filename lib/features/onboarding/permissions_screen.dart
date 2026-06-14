import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/overlay/call_assist.dart';

/// First-run screen that explains each permission VoiceUp uses and lets the
/// user grant it. Re-checks status whenever the app returns to the foreground
/// (e.g. after coming back from the system settings page).
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool _mic = false;
  bool _phone = false;
  bool _accessibility = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final mic = await Permission.microphone.isGranted;
    final phone = await Permission.phone.isGranted;
    final accessibility = await CallAssist.isAccessibilityEnabled();
    if (!mounted) return;
    setState(() {
      _mic = mic;
      _phone = phone;
      _accessibility = accessibility;
      _loading = false;
    });
  }

  Future<void> _request(Permission permission) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied) await openAppSettings();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('권한 안내')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'VoiceUp을 편하게 쓰려면 아래 권한이 필요해요.\n'
                  '왜 필요한지 확인하고 허용해 주세요.',
                  style: TextStyle(fontSize: 15, height: 1.5, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                _PermissionTile(
                  icon: Icons.mic,
                  title: '마이크',
                  required: true,
                  reason: '작은 목소리를 녹음하고 인식해서 크게 들려주는 핵심 기능에 꼭 필요해요.',
                  granted: _mic,
                  onGrant: () => _request(Permission.microphone),
                ),
                _PermissionTile(
                  icon: Icons.phone_in_talk,
                  title: '전화 상태',
                  reason: '통화가 시작되면 통화 보조 버튼을 자동으로 띄우고, 끝나면 숨기기 위해 필요해요.',
                  granted: _phone,
                  onGrant: () => _request(Permission.phone),
                ),
                _PermissionTile(
                  icon: Icons.accessibility_new,
                  title: '접근성',
                  reason: '통화 화면 위에서도 눌리는 플로팅 버튼을 띄우기 위해 필요해요. '
                      '화면 내용을 읽지 않고 버튼 표시 용도로만 사용합니다.',
                  granted: _accessibility,
                  actionLabel: '설정 열기',
                  onGrant: CallAssist.openAccessibilitySettings,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: widget.onContinue,
                  child: Text(_mic ? '시작하기' : '마이크 없이 시작하기'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '권한은 나중에 휴대폰 설정에서도 바꿀 수 있어요.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.reason,
    required this.granted,
    required this.onGrant,
    this.required = false,
    this.actionLabel = '허용',
  });

  final IconData icon;
  final String title;
  final String reason;
  final bool granted;
  final VoidCallback onGrant;
  final bool required;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(
                  required ? '필수' : '선택',
                  style: TextStyle(
                    fontSize: 12,
                    color: required ? cs.error : cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (granted)
                  Icon(Icons.check_circle, color: Colors.green.shade600)
                else
                  const Icon(Icons.radio_button_unchecked, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(reason, style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: granted
                  ? const Text('허용됨', style: TextStyle(fontWeight: FontWeight.w600))
                  : FilledButton.tonal(onPressed: onGrant, child: Text(actionLabel)),
            ),
          ],
        ),
      ),
    );
  }
}
