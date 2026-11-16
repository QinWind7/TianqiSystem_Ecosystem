import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 沉浸式全屏：隐藏状态栏与底部导航栏，向上滑动时短暂出现后自动隐藏。
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 先恢复上次选择的皮肤，再启动 App，避免首帧闪烁。
  final themeProvider = ThemeProvider();
  await themeProvider.load();

  // 初始化通知插件，并恢复已保存的每日唤醒提醒。
  try {
    await NotificationService.instance.initialize();
    await NotificationService.instance.rescheduleSaved();
  } catch (_) {
    // 通知初始化失败不应阻塞 App 启动。
  }

  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: const TianqiSystemApp(),
    ),
  );
}

class TianqiSystemApp extends StatelessWidget {
  const TianqiSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: '天命系统',
          // 网络层在 401 时通过该 key 清栈跳转登录页。
          navigatorKey: ApiService.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(AppPalette.light, Brightness.light),
          darkTheme: buildAppTheme(AppPalette.darkRed, Brightness.dark),
          themeMode: themeProvider.isDarkRed ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        );
      },
    );
  }
}
