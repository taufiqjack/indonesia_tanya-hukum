import 'package:flutter/material.dart';
import 'package:indonesia_law/core/models/app_user.dart';
import 'package:indonesia_law/core/models/chat_session.dart';
import 'package:indonesia_law/core/services/api_logger.dart';

/// Side panel listing the saved conversations, with the signed-in account at
/// the bottom.
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
    required this.user,
    required this.onSignOut,
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

  /// Signed-in account. Null only in the brief moment after signing out.
  final AppUser? user;
  final VoidCallback onSignOut;

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
            if (ApiLogger.isEnabled) const _ApiLogTile(),
            if (user != null) _AccountTile(user: user!, onSignOut: onSignOut),
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

/// Signed-in account, pinned to the bottom of the drawer.
/// Way into the API inspector. Only built in debug builds, where the logger
/// actually captures anything.
class _ApiLogTile extends StatelessWidget {
  const _ApiLogTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HistoryDrawer._border)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).pop();
          ApiLogger.instance.showInspector();
        },
        dense: true,
        leading: Icon(
          Icons.bug_report_outlined,
          size: 20,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        title: Text(
          'Log API',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Hanya tampil di mode debug',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        children: [
          _Avatar(user: user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
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
          IconButton(
            onPressed: onSignOut,
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded, size: 19),
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

/// Google profile picture, falling back to the first letter of the name.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoUrl;
    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: photoUrl == null
          ? _Initial(user: user)
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              // A missing picture must not leave a hole in the drawer.
              errorBuilder: (_, _, _) => _Initial(user: user),
            ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        user.initial,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 15,
          fontWeight: FontWeight.w600,
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
