import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_logs_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCollectionRef extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockQueryDocSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late _MockFirestore db;
  late _MockCollectionRef collection;
  late _MockQuery ordered;
  late _MockQuery limited;
  late _MockQuerySnapshot snapshot;
  late _MockQueryDocSnapshot doc;

  setUp(() {
    db = _MockFirestore();
    collection = _MockCollectionRef();
    ordered = _MockQuery();
    limited = _MockQuery();
    snapshot = _MockQuerySnapshot();
    doc = _MockQueryDocSnapshot();

    when(() => db.collection(any())).thenReturn(collection);
    when(() => collection.orderBy('timestamp', descending: true))
        .thenReturn(ordered);
    when(() => ordered.limit(any())).thenReturn(limited);
    when(() => limited.get()).thenAnswer((_) async => snapshot);
    when(() => snapshot.docs).thenReturn([doc]);
  });

  test('recentEvents maps documents into AdminEventLog', () async {
    when(() => doc.data()).thenReturn({
      'uid': 'u1',
      'name': 'search_topic',
      'timestamp': Timestamp.fromMillisecondsSinceEpoch(0),
      'params': {'keyword': 'robotics'},
    });
    final service = AdminLogsService(firestore: db);

    final events = await service.recentEvents(limit: 50);

    expect(collection.toString, isNotNull);
    verify(() => db.collection('admin_events')).called(1);
    verify(() => ordered.limit(50)).called(1);
    expect(events, hasLength(1));
    expect(events.single.uid, 'u1');
    expect(events.single.name, 'search_topic');
    expect(events.single.params, {'keyword': 'robotics'});
  });
}
