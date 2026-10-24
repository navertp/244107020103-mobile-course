import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'messaging/push_service.dart';
import 'pages/announcement_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'providers/auth_provider.dart';
import 'routes.dart';

final container = ProviderContainer();
final _authRefresh = ValueNotifier<int>(0);

final router = GoRouter(
  refreshListenable: _authRefresh,
  redirect: (context, state) {
    final loggedIn = container.read(authStateProvider).value ?? false;
    final goingLogin = state.matchedLocation == kRouteLogin;
    if (!loggedIn && !goingLogin) return kRouteLogin;
    if (loggedIn && goingLogin) return kRouteHome;
    return null;
  },
  routes: [
    GoRoute(path: kRouteLogin, builder: (_, __) => const LoginPage()),
    GoRoute(path: kRouteHome, builder: (_, __) => const HomePage()),
    GoRoute(
      path: kRouteAnnouncementPattern,
      builder: (_, s) => AnnouncementPage(id: s.pathParameters['id'] ?? ''),
    ),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  registerBackgroundHandler(); // baru
  await initLocalNotifications();

  container.listen(authStateProvider, (_, __) => _authRefresh.value++);
  runApp(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );

  // baru: tunggu status login siap, agar deep link tidak terpotong guard route
  await container.read(authStateProvider.future);
  listenForeground((route) => router.push(route));
  await handleTerminated((route) => router.push(route));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Week 6 - Auth',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        routerConfig: router,
      );
}