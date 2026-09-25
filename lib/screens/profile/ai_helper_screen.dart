import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/lottie_view.dart';

class AiHelperScreen extends StatefulWidget {
  const AiHelperScreen({super.key});

  @override
  State<AiHelperScreen> createState() => _AiHelperScreenState();
}

class _AiHelperScreenState extends State<AiHelperScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMsg> _messages = [
    const _ChatMsg(
      role: _MsgRole.bot,
      text:
          'Hey! I\'m your AI Fan Helper. Ask me for watch orders, merch ideas, con tips, or fandom debates.',
    ),
  ];
  bool _busy = false;

  static const _suggestions = [
    'Best starter anime?',
    'Gift ideas for a gamer',
    'What to bring to Comic-Con',
    'K-Pop album collecting 101',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _messages.add(_ChatMsg(role: _MsgRole.user, text: text));
      _busy = true;
    });
    _scrollDown();

    // Local canned assistant until cloud function / model is wired.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMsg(role: _MsgRole.bot, text: _reply(text)),
        );
        _busy = false;
      });
      _scrollDown();
    });
  }

  String _reply(String q) {
    final lower = q.toLowerCase();
    if (lower.contains('anime')) {
      return 'Try this starter pack:\n• Attack on Titan (action)\n• Spy x Family (fun)\n• Frieren (adventure)\n• Your Name (film)\n\nWant a darker or cozier list?';
    }
    if (lower.contains('gift') || lower.contains('gamer')) {
      return 'Gamer gift ideas:\n• Custom controller grips\n• Indie game steam card\n• Pixel art print\n• Mechanical keycap set\n\nTell me their favorite genre for tighter picks.';
    }
    if (lower.contains('comic') || lower.contains('con')) {
      return 'Con checklist:\n✅ comfy shoes\n✅ portable charger\n✅ cash + card\n✅ empty tote for merch\n✅ scheduled panel times\n✅ water bottle';
    }
    if (lower.contains('k-pop') || lower.contains('album')) {
      return 'Album collecting tips:\n• Start with one bias group\n• Check inclusions (photocards)\n• Trade duplicates in fan communities\n• Store albums away from direct sun';
    }
    return 'Got it — “$q”. I\'ll dig into that. Meanwhile try: watch orders, merch finds, con prep, or collecting guides.';
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      LottieView(
                        width: 36,
                        height: 36,
                        asset: 'lib/assets/lottie/sparkle.json',
                        fallback: const PulseDot(size: 28),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'AI Fan Helper',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  reverse: false,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: _messages.length + (_busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      );
                    }
                    return FadeSlideIn(
                      delay: Duration(milliseconds: (i % 6) * 30),
                      child: _Bubble(msg: _messages[i]),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _suggestions
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _send(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.white.withValues(alpha: 0.07),
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: AppColors.accent,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Ask about fandoms…',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _busy ? null : () => _send(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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

enum _MsgRole { user, bot }

class _ChatMsg {
  const _ChatMsg({required this.role, required this.text});
  final _MsgRole role;
  final String text;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});

  final _ChatMsg msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == _MsgRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                )
              : null,
          color: isUser ? null : Colors.white.withValues(alpha: 0.08),
          border: isUser
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(
            color: Colors.white,
            height: 1.4,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
