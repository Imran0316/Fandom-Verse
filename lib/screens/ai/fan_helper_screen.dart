import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/groq_service.dart';
import '../../widgets/liquid_glass.dart';

const String _botIdleAsset = 'lib/assets/images/ChatbotImage.png';
const String _botTalkingAsset = 'lib/assets/images/ChatbotGIF.gif';

/// Fan Helper — an AI chat companion built on Groq that helps fans
/// discover content, understand lore, and find their next favourite thing.
class FanHelperScreen extends StatefulWidget {
  const FanHelperScreen({super.key});

  @override
  State<FanHelperScreen> createState() => _FanHelperScreenState();
}

class _FanHelperScreenState extends State<FanHelperScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = <ChatMessage>[];

  bool _sending = false;
  String? _error;

  static const List<String> _suggestions = [
    'Recommend an anime like Attack on Titan',
    'What should I catch up on this weekend?',
    'Explain the lore of my favourite fandom',
    'Help me find merch for my fandom',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(const AssetImage(_botIdleAsset), context);
      precacheImage(const AssetImage(_botTalkingAsset), context);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _landed => _messages.isNotEmpty;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      _sending = true;
      _error = null;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      final reply = await GroqService.instance.sendMessage(_messages);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: ChatRole.model, text: reply));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (!GroqService.isConfigured) {
          _error = 'Fan Helper isn\'t configured yet. Add your Groq API key to '
              'enable chatting.';
        } else if (e is StateError && e.message.trim().isNotEmpty) {
          // Surface the real API error (bad key, quota, retired model, …)
          // instead of a generic message.
          _error = e.message.trim();
        } else {
          _error = 'Fan Helper hit a snag. Please try again.';
        }
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      resizeToAvoidBottomInset: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Stack(
            children: [
              // Ambient red wash, matching the dashboard.
              const Positioned(
                top: -140,
                left: -40,
                right: -40,
                height: 320,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1,
                      colors: [Color(0x55E50914), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  SafeArea(bottom: false, child: _header()),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 480),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: animation,
                          alignment: Alignment.topLeft,
                          child: child,
                        ),
                      ),
                      child: _landed
                          ? KeyedSubtree(
                              key: const ValueKey<String>('chat'),
                              child: _messageList(),
                            )
                          : KeyedSubtree(
                              key: const ValueKey<String>('landing'),
                              child: _LandingView(
                                suggestions: _suggestions,
                                onPick: _send,
                              ),
                            ),
                    ),
                  ),
                  if (_error != null) _errorBanner(_error!),
                  _composer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                alignment: Alignment.topLeft,
                child: child,
              ),
            ),
            child: _landed
                ? Row(
                    key: const ValueKey<String>('identity'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BotAvatar(talking: _sending, size: 42),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fan Helper',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Your AI fandom guide',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey<String>('none')),
          ),
        ],
      ),
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return const _TypingBubble();
        }
        return _MessageBubble(message: _messages[index]);
      },
    );
  }

  Widget _errorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: LiquidGlass(
        radius: 14,
        blur: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderColor: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B6B).withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFFF9B9B),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final hasText = _inputController.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: LiquidGlass(
                radius: 24,
                blur: 22,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.13),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                  cursorColor: AppColors.accent,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    hintText: 'Ask Fan Helper anything…',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _SendButton(
              enabled: hasText && !_sending,
              loading: _sending,
              onTap: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------- MESSAGES -------------------------------- */

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 5),
          bottomRight: Radius.circular(isUser ? 5 : 18),
        ),
        gradient: isUser
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
              )
            : null,
      ),
      child: Text(
        message.text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          height: 1.4,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUser)
            bubble
          else
            Flexible(
              child: LiquidGlass(
                radius: 18,
                blur: 20,
                borderColor: Colors.white.withValues(alpha: 0.14),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.11),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
                padding: EdgeInsets.zero,
                child: bubble,
              ),
            ),
        ],
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar({this.talking = false, this.size = 36});

  final bool talking;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.45,
            spreadRadius: -size * 0.08,
          ),
        ],
      ),
      child: ClipOval(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOut,
          child: Image.asset(
            talking ? _botTalkingAsset : _botIdleAsset,
            key: ValueKey<bool>(talking),
            width: size - 4,
            height: size - 4,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Container(
              width: size - 4,
              height: size - 4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF5C4D), Color(0xFF7F1D1D)],
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: size * 0.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------- LANDING -------------------------------- */

class _LandingView extends StatelessWidget {
  const _LandingView({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BotAvatar(size: 180),
            const SizedBox(height: 24),
            const Text(
              'Fan Helper',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Explore ideas, lore recommendations, articles, news and more '
              'with Fan Helper.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TRY ASKING',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SuggestionRow(label: s, onTap: onPick),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.label, required this.onTap});

  final String label;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: LiquidGlass(
        radius: 16,
        blur: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderColor: Colors.white.withValues(alpha: 0.1),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.accent,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: LiquidGlass(
              radius: 18,
              blur: 20,
              borderColor: Colors.white.withValues(alpha: 0.14),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.11),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const _TypingDots(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Opacity(
                opacity: _dotOpacity(i),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  double _dotOpacity(int index) {
    final t = (_controller.value - index * 0.18) % 1.0;
    final wave = (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
    return 0.25 + wave * 0.75;
  }
}

/* -------------------------------- CONTROLS -------------------------------- */

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF5C4D),
                    Color(0xFFC1121F),
                    Color(0xFF7F1D1D),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 22,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.send_rounded,
                size: 21,
                color: enabled ? Colors.white : Colors.white38,
              ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        radius: 16,
        blur: 20,
        padding: const EdgeInsets.all(10),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
