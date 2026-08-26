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
import 'package:indonesia_law/core/pages/signin_view.dart/signin_google_view.dart';
import 'package:indonesia_law/core/services/auth_service.dart';
import 'package:indonesia_law/core/services/gemini_service.dart';
import 'package:indonesia_law/core/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool signInCalled = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<AppUser?> signIn() async {
    signInCalled = true;
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
    // Backs LocalSessionStore and the chat history in every test.
    SharedPreferences.setMockInitialValues({});
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

    await tester.pumpWidget(MaterialApp(home: SigninGoogleView(auth: auth)));
    expect(find.text('Masuk dengan Google'), findsOneWidget);

    await tester.tap(find.text('Masuk dengan Google'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal masuk dengan Google.'), findsOneWidget);
    expect(auth.isSignedIn, isFalse);
  });

  testWidgets('a cancelled sign-in leaves the page quiet', (tester) async {
    final auth = AuthController(service: FakeAuthService());
    addTearDown(auth.dispose);

    await tester.pumpWidget(MaterialApp(home: SigninGoogleView(auth: auth)));
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

  testWidgets('the session outlives a restart, and sign-out ends it', (
    tester,
  ) async {
    final store = LocalSessionStore();

    final first = AuthController(
      service: FakeAuthService(session: _user),
      store: store,
    );
    addTearDown(first.dispose);
    await first.signIn();

    // A fresh controller stands in for the next launch: same device, same
    // store, nothing typed by the user.
    final second = AuthController(service: FakeAuthService(), store: store);
    addTearDown(second.dispose);
    expect(second.isRestoring, isTrue);
    await second.restore();

    expect(second.isRestoring, isFalse);
    expect(second.isSignedIn, isTrue);
    expect(second.user?.email, 'budi@example.com');

    await second.signOut();

    final third = AuthController(service: FakeAuthService(), store: store);
    addTearDown(third.dispose);
    await third.restore();
    expect(third.isSignedIn, isFalse);
  });

  test(
    'restoring never touches Google, so no account sheet can appear',
    () async {
      // The saved account is the whole answer; asking the SDK anything on launch
      // is what put a bottom sheet over the chat.
      final service = FakeAuthService(session: _user);
      final auth = AuthController(service: service, store: LocalSessionStore());
      addTearDown(auth.dispose);

      await auth.restore();

      expect(service.signInCalled, isFalse);
      expect(auth.isSignedIn, isFalse);
      expect(auth.isRestoring, isFalse);
    },
  );

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
