import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indonesia_law/core/models/chat_message.dart';
import 'package:indonesia_law/core/models/chat_session.dart';
import 'package:indonesia_law/core/pages/dashboard/chat_controller.dart';
import 'package:indonesia_law/core/pages/dashboard/history_drawer.dart';
import 'package:indonesia_law/core/services/chat_history_store.dart';
import 'package:indonesia_law/core/services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in so controller tests never touch platform channels.
class FakeChatHistoryStore implements ChatHistoryStore {
  final List<ChatSession> sessions = <ChatSession>[];
  int saveCount = 0;

  @override
  Future<List<ChatSession>> load() async => List.of(sessions);

  @override
  Future<void> save(ChatSession session) async {
    saveCount++;
    sessions
      ..removeWhere((existing) => existing.id == session.id)
      ..insert(0, session);
  }

  @override
  Future<void> delete(String id) async {
    sessions.removeWhere((session) => session.id == id);
  }

  @override
  Future<void> clear() async => sessions.clear();
}

/// Answers every request with a single SSE chunk holding [text].
http.Client _clientAnswering(String text) {
  return MockClient.streaming((request, _) async {
    final chunk = {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    };
    return http.StreamedResponse(
      Stream.value(utf8.encode('data: ${jsonEncode(chunk)}\n\n')),
      200,
      request: request,
    );
  });
}

ChatController _controller(
  FakeChatHistoryStore store, {
  String answer = 'Ya.',
}) {
  return ChatController(
    service: GeminiService(client: _clientAnswering(answer)),
    history: store,
  );
}

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'GEMINI_API_KEY=test-key\nGEMINI_MODEL=gemini-3.5-flash',
    );
  });

  group('ChatController history', () {
    test('saves the transcript once an answer arrives', () async {
      final store = FakeChatHistoryStore();
      final chat = _controller(store, answer: 'Pasal 362 KUHP.');
      addTearDown(chat.dispose);

      await chat.send('Apa itu pencurian?');

      expect(store.sessions, hasLength(1));
      expect(chat.sessions, hasLength(1));
      expect(chat.sessions.single.title, 'Apa itu pencurian?');
      expect(chat.sessions.single.preview, 'Pasal 362 KUHP.');
      expect(chat.activeSessionId, isNotNull);
    });

    test('keeps appending to the same session across turns', () async {
      final store = FakeChatHistoryStore();
      final chat = _controller(store);
      addTearDown(chat.dispose);

      await chat.send('Pertanyaan pertama');
      final id = chat.activeSessionId;
      await chat.send('Pertanyaan kedua');

      expect(chat.activeSessionId, id);
      expect(store.sessions, hasLength(1));
      expect(store.sessions.single.messages, hasLength(4));
    });

    test('a failed exchange is not saved', () async {
      final store = FakeChatHistoryStore();
      final chat = ChatController(
        service: GeminiService(
          client: MockClient.streaming((request, _) async {
            return http.StreamedResponse(
              Stream.value(utf8.encode('{"error":{"message":"boom"}}')),
              500,
              request: request,
            );
          }),
        ),
        history: store,
      );
      addTearDown(chat.dispose);

      await chat.send('Halo');

      expect(chat.messages.last.isError, isTrue);
      expect(store.sessions, isEmpty);
      expect(chat.activeSessionId, isNull);
    });

    test(
      'startNewChat archives the transcript and clears the screen',
      () async {
        final store = FakeChatHistoryStore();
        final chat = _controller(store);
        addTearDown(chat.dispose);

        await chat.send('Pertanyaan lama');
        await chat.startNewChat();

        expect(chat.isEmpty, isTrue);
        expect(chat.activeSessionId, isNull);
        expect(chat.sessions, hasLength(1));

        await chat.send('Pertanyaan baru');
        expect(chat.sessions, hasLength(2));
      },
    );

    test('openSession restores a saved transcript', () async {
      final store = FakeChatHistoryStore();
      final chat = _controller(store);
      addTearDown(chat.dispose);

      await chat.send('Pertanyaan lama');
      final saved = chat.sessions.single;
      await chat.startNewChat();
      await chat.openSession(saved);

      expect(chat.activeSessionId, saved.id);
      expect(chat.messages.first.text, 'Pertanyaan lama');
      expect(chat.messages.every((message) => !message.isStreaming), isTrue);
    });

    test('loadHistory reads what the store already holds', () async {
      final store = FakeChatHistoryStore();
      await store.save(
        ChatSession(
          id: 'chat-1',
          messages: const [
            ChatMessage.user('Halo'),
            ChatMessage.model('Halo juga.'),
          ],
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final chat = _controller(store);
      addTearDown(chat.dispose);
      await chat.loadHistory();

      expect(chat.sessions, hasLength(1));
      expect(chat.isLoadingHistory, isFalse);
    });

    test('deleteSession drops the row and clears it when open', () async {
      final store = FakeChatHistoryStore();
      final chat = _controller(store);
      addTearDown(chat.dispose);

      await chat.send('Pertanyaan');
      await chat.deleteSession(chat.activeSessionId!);

      expect(chat.sessions, isEmpty);
      expect(store.sessions, isEmpty);
      expect(chat.isEmpty, isTrue);
    });

    test('clearHistory wipes everything', () async {
      final store = FakeChatHistoryStore();
      final chat = _controller(store);
      addTearDown(chat.dispose);

      await chat.send('Pertanyaan');
      await chat.clearHistory();

      expect(chat.sessions, isEmpty);
      expect(store.sessions, isEmpty);
      expect(chat.isEmpty, isTrue);
    });
  });

  group('LocalChatHistoryStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round-trips sessions newest first', () async {
      final store = LocalChatHistoryStore(
        await SharedPreferences.getInstance(),
      );

      await store.save(
        ChatSession(
          id: 'old',
          messages: const [
            ChatMessage.user('Lama'),
            ChatMessage.model('Jawaban lama'),
          ],
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      await store.save(
        ChatSession(
          id: 'new',
          messages: const [
            ChatMessage.user('Baru'),
            ChatMessage.model('Jawaban baru', isError: true),
          ],
          createdAt: DateTime(2026, 2, 1),
          updatedAt: DateTime(2026, 2, 1),
        ),
      );

      final loaded = await store.load();
      expect(loaded.map((session) => session.id), ['new', 'old']);
      expect(loaded.first.messages.last.isError, isTrue);
      expect(loaded.last.messages.first.isUser, isTrue);
    });

    test('replaces a session saved under the same id', () async {
      final store = LocalChatHistoryStore(
        await SharedPreferences.getInstance(),
      );
      final session = ChatSession(
        id: 'chat-1',
        messages: const [ChatMessage.user('Halo')],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await store.save(session);
      await store.save(
        session.copyWith(
          messages: const [
            ChatMessage.user('Halo'),
            ChatMessage.model('Halo juga.'),
          ],
          updatedAt: DateTime(2026, 1, 2),
        ),
      );

      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.messages, hasLength(2));
    });

    test('a corrupted payload is discarded instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.chat_history_v1': 'not json',
      });
      final store = LocalChatHistoryStore(
        await SharedPreferences.getInstance(),
      );

      expect(await store.load(), isEmpty);
    });

    test('delete and clear remove rows', () async {
      final store = LocalChatHistoryStore(
        await SharedPreferences.getInstance(),
      );
      for (final id in ['a', 'b']) {
        await store.save(
          ChatSession(
            id: id,
            messages: const [ChatMessage.user('Halo')],
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );
      }

      await store.delete('a');
      expect((await store.load()).map((session) => session.id), ['b']);

      await store.clear();
      expect(await store.load(), isEmpty);
    });
  });

  group('formatSessionTime', () {
    final now = DateTime(2026, 8, 13, 15, 30);

    test('shows the clock for today', () {
      expect(formatSessionTime(DateTime(2026, 8, 13, 9, 5), now: now), '09:05');
    });

    test('shows "Kemarin" for yesterday', () {
      expect(
        formatSessionTime(DateTime(2026, 8, 12, 23, 0), now: now),
        'Kemarin',
      );
    });

    test('shows day and month within the year', () {
      expect(formatSessionTime(DateTime(2026, 8, 2), now: now), '2 Agu');
    });

    test('adds the year for older conversations', () {
      expect(
        formatSessionTime(DateTime(2025, 12, 31), now: now),
        '31 Des 2025',
      );
    });
  });

  group('ChatSession', () {
    test('falls back to placeholder labels when empty', () {
      final session = ChatSession(
        id: 'empty',
        messages: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(session.title, 'Obrolan baru');
      expect(session.preview, 'Belum ada jawaban');
    });

    test('truncates a long first question', () {
      final session = ChatSession(
        id: 'long',
        messages: [ChatMessage.user('a' * 100)],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(session.title.length, 61);
      expect(session.title.endsWith('…'), isTrue);
    });
  });
}
