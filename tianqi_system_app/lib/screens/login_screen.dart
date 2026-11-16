import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import 'system_home_screen.dart';

/// 登录页：极简 HUD 风格的账号接入终端。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _accountFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _accountFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final account = _accountController.text.trim();
    final password = _passwordController.text;
    if (account.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入账号与密码');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ApiService.instance.login(username: account, password: password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 360),
          pageBuilder: (_, _, _) => const SystemHomeScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ApiService.describeError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTitle(),
                          const SizedBox(height: 28),
                          _buildPanel(),
                          const SizedBox(height: 18),
                          Text(
                            'SYNC NODE // ${ApiService.host.replaceFirst('http://', '')}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 1.1,
                              fontFamily: 'monospace',
                              color: AppColors.techLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '// ACCESS TERMINAL',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.6,
            fontFamily: 'monospace',
            color: AppColors.techLabel,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '天启系统',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '登录后同步等级、经验与连击',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  label: 'HOST ID',
                  controller: _accountController,
                  focusNode: _accountFocus,
                  hint: '用户名或邮箱',
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'PASSCODE',
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  hint: '请输入密码',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '× $_error',
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: Color(0xFFC94F4F),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor: AppColors.accent.withValues(
                        alpha: 0.45,
                      ),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('接 入 系 统'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required TextInputAction textInputAction,
    required ValueChanged<String> onSubmitted,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            letterSpacing: 1.4,
            fontFamily: 'monospace',
            color: AppColors.techLabel,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '>_',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                enabled: !_submitting,
                textInputAction: textInputAction,
                onSubmitted: onSubmitted,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.accent,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: AppColors.accent,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
