import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/settings/presentation/pages/debug_page.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  int _tapCount = 0;
  DateTime? _lastTapTime;
  String _version = '1.0.0';
  int _devTapCount = 0;
  DateTime? _devLastTapTime;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) < const Duration(seconds: 1)) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    if (_tapCount == 5) {
      if (mounted) {
        AppToast.show(
          context,
          '🌸樱&晓 永远爱着Anson❤️',
          duration: const Duration(seconds: 3),
        );
      }
      _tapCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于白守')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _handleLogoTap,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/BaiShou-v0.0.1.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '白守 (BaiShou)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              'v$_version',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            '开发者',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              final now = DateTime.now();
              if (_devLastTapTime == null ||
                  now.difference(_devLastTapTime!) <
                      const Duration(seconds: 2)) {
                _devTapCount++;
              } else {
                _devTapCount = 1;
              }
              _devLastTapTime = now;

              if (_devTapCount == 7) {
                AppToast.show(context, '再点 3 次进入开发者模式');
              } else if (_devTapCount >= 10) {
                _devTapCount = 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebugPage()),
                );
              }
            },
            child: const Card(
              child: ListTile(
                title: Text('Anson & Kasumiame Sakura & Tenkou Akatsuki'),
                subtitle: Text('The Trio'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '开源协议',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('GPL v3.0'),
              subtitle: const Text(
                'Copyright (C) 2026 Anson, Kasumiame Sakura & Tenkou Akatsuki',
              ),
              trailing: const Icon(Icons.arrow_outward, size: 16),
              onTap: () {
                launchUrl(
                  Uri.parse('https://www.gnu.org/licenses/gpl-3.0.html'),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              launchUrl(Uri.parse('https://github.com/Anson-Trio/BaiShou'));
            },
            icon: const Icon(Icons.code),
            label: const Text('访问 GitHub 仓库'),
          ),
        ],
      ),
    );
  }
}
