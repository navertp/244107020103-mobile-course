import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../messaging/push_service.dart';
import '../providers/auth_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    setupPush();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Notify'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: ValueListenableBuilder<String?>(
        valueListenable: fcmTokenNotifier,
        builder: (context, token, _) => ListTile(
          leading: const Icon(Icons.vpn_key_outlined),
          title: const Text('FCM token (terpotong)'),
          subtitle: Text(shortToken(token)),
        ),
      ),
    );
  }
}