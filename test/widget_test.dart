import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indonesia_law/core/pages/dashboard/chat_controller.dart';
import 'package:indonesia_law/core/pages/dashboard/dashboard_view.dart';
import 'package:indonesia_law/core/services/gemini_service.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'GEMINI_API_KEY=test-key\nGEMINI_MODEL=gemini-3.5-flash',
    );
  });

  testWidgets('dashboard opens on the empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardView()));

    expect(find.text('Hukum AI'), findsOneWidget);
    expect(find.text('Ketik pertanyaan Anda di sini...'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
  });

  testWidgets('typing a question and sending it shows both bubbles', (
    tester,
  ) async {
    final client = MockClient.streaming((request, _) async {
      const chunk = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Pasal 362 KUHP.'},
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

    final chat = ChatController(service: GeminiService(client: client));
    addTearDown(chat.dispose);

    await chat.send('Apa itu pencurian?');

    expect(chat.messages, hasLength(2));
    expect(chat.messages.first.isUser, isTrue);
    expect(chat.messages.last.text, 'Pasal 362 KUHP.');
    expect(chat.messages.last.isStreaming, isFalse);
    expect(chat.isSending, isFalse);
  });

  testWidgets('a failed answer becomes an error bubble, retry re-asks', (
    tester,
  ) async {
    var attempt = 0;
    final client = MockClient.streaming((request, _) async {
      attempt++;
      if (attempt == 1) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error":{"message":"boom"}}')),
          500,
          request: request,
        );
      }
      const chunk = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Berhasil.'},
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

    final chat = ChatController(service: GeminiService(client: client));
    addTearDown(chat.dispose);

    await chat.send('Halo');
    expect(chat.messages.last.isError, isTrue);
    expect(chat.messages.last.text, contains('Server Gemini'));

    await chat.retryLast();
    expect(attempt, 2);
    expect(chat.messages, hasLength(2));
    expect(chat.messages.last.text, 'Berhasil.');
    expect(chat.messages.last.isError, isFalse);
  });
}
