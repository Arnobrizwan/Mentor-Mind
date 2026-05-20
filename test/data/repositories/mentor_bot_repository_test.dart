// Unit tests for MentorBotRepository.sendMessage.
//
// Strategy: instantiate MentorBotRepository directly with a fake FirebaseFunctions
// stub built via mocktail (or a hand-rolled fake). Verify:
//   1. Payload built from the 6 named parameters matches the wire shape.
//   2. fromMap decodes the canned callable response into MentorBotResponse.
//   3. Optional fields (imageUrl, subject, level) are omitted from the payload
//      when null (the if-null guard in the implementation).
//
// We avoid mocktail to keep this plan dependency-narrow — a hand-rolled fake is
// sufficient.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentor_minds/data/models/mentor_bot_response.dart';
import 'package:mentor_minds/data/repositories/mentor_bot_repository.dart';

class _FakeHttpsCallableResult implements HttpsCallableResult<dynamic> {
  _FakeHttpsCallableResult(this._data);
  final Object? _data;
  @override
  dynamic get data => _data;
}

class _FakeHttpsCallable implements HttpsCallable {
  _FakeHttpsCallable({required this.cannedResponse, required this.spy});
  final Map<String, dynamic> cannedResponse;
  final List<Object?> spy;

  @override
  Future<HttpsCallableResult<T>> call<T>([Object? parameters]) async {
    spy.add(parameters);
    return _FakeHttpsCallableResult(cannedResponse) as HttpsCallableResult<T>;
  }

  @override
  Stream<StreamResponse> stream<T, R>([Object? input]) async* {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseFunctions implements FirebaseFunctions {
  _FakeFirebaseFunctions({required this.callable});
  final _FakeHttpsCallable callable;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return callable;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MentorBotRepository.sendMessage', () {
    test('builds the correct payload with all 6 fields', () async {
      final spy = <Object?>[];
      final fakeCallable = _FakeHttpsCallable(
        cannedResponse: <String, dynamic>{
          'text': 'hi',
          'promptTokens': 10,
          'completionTokens': 20,
          'messageId': 'mid-1',
          'createdAt': 1700000000000,
        },
        spy: spy,
      );
      final repo = MentorBotRepository(
        functions: _FakeFirebaseFunctions(callable: fakeCallable),
      );

      await repo.sendMessage(
        sessionId: 'sess-1',
        clientRequestId: 'req-1',
        message: 'Hello',
        imageUrl: 'gs://b/p.jpg',
        subject: 'Physics',
        level: 'A-Level',
      );

      expect(spy, hasLength(1));
      final payload = spy.first as Map<String, dynamic>;
      expect(payload['sessionId'], 'sess-1');
      expect(payload['clientRequestId'], 'req-1');
      expect(payload['message'], 'Hello');
      expect(payload['imageUrl'], 'gs://b/p.jpg');
      expect(payload['subject'], 'Physics');
      expect(payload['level'], 'A-Level');
    });

    test('omits optional fields when null', () async {
      final spy = <Object?>[];
      final fakeCallable = _FakeHttpsCallable(
        cannedResponse: <String, dynamic>{
          'text': 'hi',
          'promptTokens': 1,
          'completionTokens': 2,
          'messageId': 'mid',
          'createdAt': 0,
        },
        spy: spy,
      );
      final repo = MentorBotRepository(
        functions: _FakeFirebaseFunctions(callable: fakeCallable),
      );

      await repo.sendMessage(
        sessionId: 'sess-2',
        clientRequestId: 'req-2',
        message: 'Hi',
      );

      final payload = spy.first as Map<String, dynamic>;
      expect(payload.containsKey('imageUrl'), isFalse);
      expect(payload.containsKey('subject'), isFalse);
      expect(payload.containsKey('level'), isFalse);
      expect(payload.keys, containsAll(<String>['sessionId', 'clientRequestId', 'message']));
    });

    test('decodes the callable response into MentorBotResponse', () async {
      final fakeCallable = _FakeHttpsCallable(
        cannedResponse: <String, dynamic>{
          'text': 'Hello student',
          'promptTokens': 50,
          'completionTokens': 100,
          'messageId': 'mid-xyz',
          'createdAt': 1710000000000,
        },
        spy: <Object?>[],
      );
      final repo = MentorBotRepository(
        functions: _FakeFirebaseFunctions(callable: fakeCallable),
      );

      final response = await repo.sendMessage(
        sessionId: 'sess-3',
        clientRequestId: 'req-3',
        message: 'Q',
      );

      expect(response, isA<MentorBotResponse>());
      expect(response.text, 'Hello student');
      expect(response.promptTokens, 50);
      expect(response.completionTokens, 100);
      expect(response.messageId, 'mid-xyz');
      expect(response.createdAt.millisecondsSinceEpoch, 1710000000000);
    });

    test('decodes safely when fields are missing (defaults applied)', () async {
      final fakeCallable = _FakeHttpsCallable(
        cannedResponse: <String, dynamic>{}, // empty response
        spy: <Object?>[],
      );
      final repo = MentorBotRepository(
        functions: _FakeFirebaseFunctions(callable: fakeCallable),
      );

      final response = await repo.sendMessage(
        sessionId: 'sess-4',
        clientRequestId: 'req-4',
        message: 'Q',
      );

      expect(response.text, '');
      expect(response.promptTokens, 0);
      expect(response.completionTokens, 0);
      expect(response.messageId, '');
      // createdAt defaults to DateTime.now() — confirm it's recent (within 5s).
      final delta = DateTime.now().difference(response.createdAt).inSeconds;
      expect(delta.abs(), lessThan(5));
    });
  });
}
