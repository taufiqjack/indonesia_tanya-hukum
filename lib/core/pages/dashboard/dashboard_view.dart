import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:indonesia_law/core/models/chat_message.dart';
import 'package:indonesia_law/core/models/chat_session.dart';
import 'package:indonesia_law/core/pages/dashboard/chat_controller.dart';
import 'package:indonesia_law/core/pages/dashboard/history_drawer.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/auth_controller.dart';
import 'package:indonesia_law/core/widgets/common_handle_back.dart';
import 'package:indonesia_law/core/widgets/rich_answer_text.dart';
import 'package:indonesia_law/core/widgets/spotlight_backdrop.dart';

/// Chat-style landing page for the assistant, matching `dashboard_chat.png`.
///
/// Only reachable once [auth] holds a signed-in account; see `AuthGate`.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key, required this.auth});

  final AuthController auth;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  static const _background = Color(0xFF050505);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0x1AFFFFFF);

  /// Back has to be pressed twice within this window to leave the app.

  final ChatController _chat = ChatController();
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _chat.addListener(_scrollToBottom);
    _chat.loadHistory();
  }

  @override
  void dispose() {
    _chat.removeListener(_scrollToBottom);
    _chat.dispose();
    _promptController.dispose();
    _promptFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit([String? text]) {
    final prompt = text ?? _promptController.text;
    if (prompt.trim().isEmpty || _chat.isSending) return;

    _promptController.clear();
    _promptFocusNode.unfocus();
    _chat.send(prompt);
  }

  /// First back press only warns; a second one within [_exitWindow] closes the
  /// app. Runs on Android — other platforms never deliver the pop.

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _openHistory() {
    _promptFocusNode.unfocus();
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _newChat() async {
    _promptController.clear();
    _promptFocusNode.unfocus();
    await _chat.startNewChat();
  }

  Future<void> _openSession(ChatSession session) async {
    _scaffoldKey.currentState?.closeDrawer();
    _promptController.clear();
    _promptFocusNode.unfocus();
    await _chat.openSession(session);
    _scrollToBottom();
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Hapus semua riwayat?'),
        content: const Text(
          'Seluruh obrolan yang tersimpan di perangkat ini akan dihapus '
          'dan tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF8A8A),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    // The drawer stays open so its empty state confirms the wipe.
    await _chat.clearHistory();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Anda perlu masuk kembali dengan Google untuk melanjutkan obrolan. '
          'Riwayat yang tersimpan di perangkat ini tidak dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF8A8A),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    // Saves the open transcript first — signing out swaps this page for the
    // sign-in one and disposes the controller.
    await _chat.startNewChat();
    await widget.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      drawerScrimColor: Colors.black.withValues(alpha: 0.6),
      drawer: ListenableBuilder(
        listenable: _chat,
        builder: (context, _) => HistoryDrawer(
          sessions: _chat.sessions,
          activeId: _chat.activeSessionId,
          isLoading: _chat.isLoadingHistory,
          user: widget.auth.user,
          onSignOut: _confirmSignOut,
          onOpen: _openSession,
          onDelete: (session) => _chat.deleteSession(session.id),
          onNewChat: () {
            _scaffoldKey.currentState?.closeDrawer();
            _newChat();
          },
          onClearAll: _confirmClearHistory,
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) => handleBack(context, didPop),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _chat,
            builder: (context, _) {
              final isEmpty = _chat.isEmpty;
              return Column(
                children: [
                  _TopBar(
                    onMenu: _openHistory,
                    onNewChat: isEmpty ? null : _newChat,
                  ),
                  Expanded(
                    child: isEmpty
                        ? const _EmptyState()
                        : _Transcript(
                            messages: _chat.messages,
                            controller: _scrollController,
                            onRetry: _chat.retryLast,
                          ),
                  ),
                  if (isEmpty) _SuggestionCards(onTap: _submit),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _PromptComposer(
                      controller: _promptController,
                      focusNode: _promptFocusNode,
                      surface: _surface,
                      border: _border,
                      isSending: _chat.isSending,
                      onSend: _submit,
                      onStop: _chat.stop,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onMenu, this.onNewChat});

  final VoidCallback onMenu;

  /// Null while the transcript is already empty.
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            tooltip: 'Riwayat obrolan',
            icon: const Icon(Icons.view_sidebar_outlined, size: 22),
            color: Colors.white,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Tanya Hukum',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNewChat,
            tooltip: 'Obrolan baru',
            icon: const Icon(Icons.add_comment_outlined, size: 22),
            color: Colors.white,
            disabledColor: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

/// Hero copy shown before the first question is asked.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: SpotlightBackdrop()),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tanyakan Hukum,\nSiap Kapan Saja.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tulis pertanyaan Anda di bawah lalu tekan '
                  'tombol untuk memulai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The scrolling conversation.
class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.messages,
    required this.controller,
    required this.onRetry,
  });

  final List<ChatMessage> messages;
  final ScrollController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final message = messages[index];
        final isLast = index == messages.length - 1;
        return _MessageBubble(
          message: message,
          onRetry: message.isError && isLast ? onRetry : null,
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ),
      );
    }

    final isPending = message.isStreaming && message.text.isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: message.isError
                ? const Color(0x33FF6B6B)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Icon(
            message.isError
                ? Icons.error_outline_rounded
                : Icons.balance_rounded,
            size: 15,
            color: message.isError
                ? const Color(0xFFFF8A8A)
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPending)
                const _TypingIndicator()
              else
                RichAnswerText(
                  text: message.text,
                  color: message.isError
                      ? const Color(0xFFFF8A8A)
                      : Colors.white.withValues(alpha: 0.92),
                ),
              if (!message.isStreaming && !message.isError)
                _AnswerActions(text: message.text),
              if (onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Coba lagi'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerActions extends StatelessWidget {
  const _AnswerActions({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: IconButton(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jawaban disalin'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        tooltip: 'Salin jawaban',
        icon: const Icon(Icons.copy_rounded, size: 16),
        color: Colors.white.withValues(alpha: 0.5),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Three pulsing dots shown while waiting for the first token.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            children: List.generate(3, (index) {
              final phase = (_controller.value - index * 0.18) % 1.0;
              final opacity = 0.25 + 0.6 * (1 - (phase * 2 - 1).abs());
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: opacity),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _SuggestionCards extends StatelessWidget {
  const _SuggestionCards({required this.onTap});

  final ValueChanged<String> onTap;

  static const _items = <({IconData icon, String text, String prompt})>[
    (
      icon: Icons.lightbulb_outline_rounded,
      text:
          'Pahami pasal, kontrak, dan '
          'istilah hukum yang rumit '
          'dengan penjelasan sederhana.',
      prompt:
          'Jelaskan dengan bahasa sederhana isi dan maksud Pasal 1320 '
          'KUHPerdata tentang syarat sahnya perjanjian.',
    ),
    (
      icon: Icons.person_outline_rounded,
      text:
          'Dapatkan jawaban mendalam '
          'atas persoalan hukum Anda '
          'secara cepat dan akurat.',
      prompt:
          'Apa langkah hukum yang bisa saya tempuh jika gaji saya tidak '
          'dibayar oleh perusahaan selama tiga bulan?',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _SuggestionCard(
            icon: item.icon,
            text: item.text,
            onTap: () => onTap(item.prompt),
          );
        },
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(height: 20),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptComposer extends StatelessWidget {
  const _PromptComposer({
    required this.controller,
    required this.focusNode,
    required this.surface,
    required this.border,
    required this.isSending,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color surface;
  final Color border;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 4,
            minLines: 1,
            textInputAction: TextInputAction.newline,
            cursorColor: Colors.white,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: 'Ketik pertanyaan Anda di sini...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const _CircleButton(
                icon: Icons.attach_file_rounded,
                tooltip: 'Lampirkan berkas',
              ),
              const SizedBox(width: 8),
              const _CircleButton(
                icon: Icons.lightbulb_outline_rounded,
                tooltip: 'Mode berpikir',
              ),
              const SizedBox(width: 8),
              const _CircleButton(
                icon: Icons.auto_fix_high_outlined,
                tooltip: 'Sempurnakan prompt',
              ),
              const Spacer(),
              const _CircleButton(
                icon: Icons.mic_none_rounded,
                tooltip: 'Suara',
              ),
              const SizedBox(width: 8),
              _SendButton(
                isSending: isSending,
                onPressed: isSending ? onStop : onSend,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(side: BorderSide(color: Color(0x26FFFFFF))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {},
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 19,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending, required this.onPressed});

  final bool isSending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            isSending ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            size: 22,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
