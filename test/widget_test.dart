import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indonesia_law/core/models/app_user.dart';
import 'package:indonesia_law/core/pages/dashboard/chat_controller.dart';
import 'package:indonesia_law/core/pages/dashboard/dashboard_view.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/auth_controller.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/signin_view.dart';
import 'package:indonesia_law/core/services/auth_service.dart';
import 'package:indonesia_law/core/services/gemini_service.dart';

const _user = AppUser(
  id: 'user-1',
  email: 'budi@example.com',
  name: 'Budi Santoso',
);

/// Stands in for Google Sign-In: [session] is what a successful sign-in
/// returns, [failure] turns sign-in into an error, and neither one set means
/// the user backed out of the flow.
class FakeAuthService implements AuthService {
  FakeAuthService({this.session, this.failure});

  final AppUser? session;
  final String? failure;
  bool signedOut = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<AppUser?> signIn() async {
    if (failure != null) throw AuthException(failure!);
    return session;
  }

  @override
  Future<void> signOut() async => signedOut = true;
}

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'GEMINI_API_KEY=test-key\nGEMINI_MODEL=gemini-3.5-flash',
    );
  });

  testWidgets('dashboard opens on the empty state', (tester) async {
    final auth = AuthController(service: FakeAuthService(session: _user));
    addTearDown(auth.dispose);
    await auth.signIn();

    await tester.pumpWidget(MaterialApp(home: DashboardView(auth: auth)));

    expect(find.text('Tanya Hukum'), findsOneWidget);
    expect(find.text('Ketik pertanyaan Anda di sini...'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
  });

  testWidgets('sign-in page offers Google and reports failures', (
    tester,
  ) async {
    final auth = AuthController(
      service: FakeAuthService(failure: 'Gagal masuk dengan Google.'),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(MaterialApp(home: SigninView(auth: auth)));
    expect(find.text('Masuk dengan Google'), findsOneWidget);

    await tester.tap(find.text('Masuk dengan Google'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal masuk dengan Google.'), findsOneWidget);
    expect(auth.isSignedIn, isFalse);
  });

  testWidgets('a cancelled sign-in leaves the page quiet', (tester) async {
    final auth = AuthController(service: FakeAuthService());
    addTearDown(auth.dispose);

    await tester.pumpWidget(MaterialApp(home: SigninView(auth: auth)));
    await tester.tap(find.text('Masuk dengan Google'));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    expect(auth.error, isNull);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });

  test('signing in, then signing out, flips the gate', () async {
    final service = FakeAuthService(session: _user);
    final auth = AuthController(service: service);
    addTearDown(auth.dispose);

    expect(auth.isSignedIn, isFalse);

    await auth.signIn();
    expect(auth.user?.email, 'budi@example.com');

    await auth.signOut();
    expect(auth.isSignedIn, isFalse);
    expect(service.signedOut, isTrue);
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
