import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indonesia_law/core/models/chat_message.dart';
import 'package:indonesia_law/core/services/gemini_service.dart';

/// Builds an SSE body in the shape Gemini returns.
String _sse(List<Map<String, Object?>> parts) {
  return parts
      .map(
        (part) =>
            'data: ${jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [part],
                    'role': 'model',
                  },
                },
              ],
            })}\n\n',
      )
      .join();
}

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'GEMINI_API_KEY=test-key\nGEMINI_MODEL=gemini-3.5-flash',
    );
  });

  test('streams cumulative text and skips thought parts', () async {
    final client = MockClient.streaming((request, _) async {
      final body = _sse([
        {'text': 'rahasia', 'thought': true},
        {'text': 'Pasal 362 '},
        {'text': 'KUHP.'},
      ]);
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        request: request,
      );
    });

    final service = GeminiService(client: client);
    final chunks = await service
        .streamAnswer(prompt: 'Apa itu pencurian?')
        .toList();

    expect(chunks, ['Pasal 362 ', 'Pasal 362 KUHP.']);
  });

  test('sends system instruction and prior history', () async {
    late Map<String, Object?> payload;
    final client = MockClient.streaming((request, bodyStream) async {
      payload =
          jsonDecode(utf8.decode(await bodyStream.toBytes()))
              as Map<String, Object?>;
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            _sse([
              {'text': 'ok'},
            ]),
          ),
        ),
        200,
        request: request,
      );
    });

    await GeminiService(client: client)
        .streamAnswer(
          prompt: 'Lanjutkan',
          history: const [
            ChatMessage.user('Halo'),
            ChatMessage.model('Halo, ada yang bisa dibantu?'),
            ChatMessage.model('gagal', isError: true),
          ],
        )
        .drain<void>();

    final contents = payload['contents']! as List;
    expect(contents, hasLength(3), reason: 'error bubbles are not sent');
    expect((contents.first as Map)['role'], 'user');
    expect((contents.last as Map)['role'], 'user');
    expect(payload['systemInstruction'], isNotNull);
  });

  test('maps API errors to a readable Indonesian message', () async {
    final client = MockClient.streaming((request, _) async {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'error': {'message': 'bad key'},
            }),
          ),
        ),
        403,
        request: request,
      );
    });

    expect(
      () =>
          GeminiService(client: client).streamAnswer(prompt: 'x').drain<void>(),
      throwsA(
        isA<GeminiException>().having(
          (e) => e.message,
          'message',
          contains('API key Gemini tidak valid'),
        ),
      ),
    );
  });

  test('fails clearly when the API key is missing', () async {
    dotenv.loadFromString(envString: 'GEMINI_API_KEY=');

    expect(
      () => GeminiService().streamAnswer(prompt: 'x').drain<void>(),
      throwsA(
        isA<GeminiException>().having(
          (e) => e.message,
          'message',
          contains('GEMINI_API_KEY belum diatur'),
        ),
      ),
    );
  });
}
