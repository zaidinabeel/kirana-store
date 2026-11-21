import 'package:flutter_test/flutter_test.dart';
import 'package:kirana_store/features/help/help_content.dart';

String? _top(String q) {
  final r = HelpSearch.search(q);
  return r.isEmpty ? null : r.first.id;
}

void main() {
  test('Hinglish questions find the right guide', () {
    expect(_top('printer kaise jode'), 'printer_connect');
    expect(_top('udhar kaise likhe'), 'khata_credit');
    expect(_top('naya phone me data kaise laye'), 'restore');
    expect(_top('backup kaise le'), 'backup');
    expect(_top('naya bill banana hai'), 'first_bill');
  });

  test('Hindi questions find the right guide', () {
    expect(_top('प्रिंटर कैसे जोड़ें?'), 'printer_connect');
    expect(_top('बैकअप कैसे लें'), 'backup');
    expect(_top('गलत बिल रद्द करना है'), 'void_bill');
    expect(_top('₹50 की चीनी खुला सामान'), 'loose_item');
    expect(_top('ग्राहक ने उधार चुकाया'), 'khata_payment');
  });

  test('English questions work too', () {
    expect(_top('how to connect bluetooth printer'), 'printer_connect');
    expect(_top('restore data on new phone'), 'restore');
  });

  test('unrelated text returns nothing', () {
    expect(HelpSearch.search('qwerty zzz'), isEmpty);
    expect(HelpSearch.search('   '), isEmpty);
  });

  test('every guide has steps and keywords', () {
    final ids = <String>{};
    for (final t in helpTopics) {
      expect(t.steps, isNotEmpty, reason: t.id);
      expect(t.keywords, isNotEmpty, reason: t.id);
      expect(ids.add(t.id), isTrue, reason: 'duplicate id ${t.id}');
    }
  });
}
