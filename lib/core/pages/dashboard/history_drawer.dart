import 'package:flutter/material.dart';
import 'package:indonesia_law/core/models/chat_session.dart';

/// Side panel listing the saved conversations.
class HistoryDrawer extends StatelessWidget {
  const HistoryDrawer({
    super.key,
    required this.sessions,
    required this.activeId,
    required this.isLoading,
    required this.onOpen,
    required this.onDelete,
    required this.onNewChat,
    required this.onClearAll,
  });

  static const _background = Color(0xFF0B0B0B);
  static const _border = Color(0x1AFFFFFF);

  final List<ChatSession> sessions;
  final String? activeId;
  final bool isLoading;
  final ValueChanged<ChatSession> onOpen;
  final ValueChanged<ChatSession> onDelete;
  final VoidCallback onNewChat;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _background,
      width: MediaQuery.sizeOf(context).width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        side: BorderSide(color: _border),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onClearAll: sessions.isEmpty ? null : onClearAll),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _NewChatButton(onTap: onNewChat),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (isLoading && sessions.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    if (sessions.isEmpty) return const _EmptyHistory();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _HistoryTile(
          session: session,
          isActive: session.id == activeId,
          onTap: () => onOpen(session),
          onDelete: () => onDelete(session),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onClearAll});

  /// Null while there is nothing to clear.
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Riwayat Obrolan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onClearAll,
            tooltip: 'Hapus semua riwayat',
            icon: const Icon(Icons.delete_sweep_outlined, size: 21),
            color: Colors.white.withValues(alpha: 0.7),
            disabledColor: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF161616),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.add_comment_outlined,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                'Obrolan baru',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 34,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 14),
          Text(
            'Belum ada riwayat.\nObrolan Anda akan tersimpan otomatis '
            'di perangkat ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: const Color(0x33FF6B6B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFFF8A8A),
          size: 20,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: isActive ? const Color(0xFF1C1C1C) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? const Color(0x26FFFFFF) : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Text(
                    formatSessionTime(session.updatedAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _monthsId = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Short Indonesian stamp: clock for today, "Kemarin", then a date.
String formatSessionTime(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(time.year, time.month, time.day);
  final difference = today.difference(day).inDays;

  if (difference <= 0) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (difference == 1) return 'Kemarin';
  if (time.year == reference.year) {
    return '${time.day} ${_monthsId[time.month - 1]}';
  }
  return '${time.day} ${_monthsId[time.month - 1]} ${time.year}';
}
