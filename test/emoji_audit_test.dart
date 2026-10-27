import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SIFIR EMOJI DENETİMİ: lib/ altındaki hiçbir kod veya UI metninde emoji bulunmamalıdır', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib klasörü mevcut olmalıdır.');

    final emojiRegex = RegExp(r'[\u{10000}-\u{10ffff}]|[\u{2600}-\u{27bf}]', unicode: true);
    final allowedExceptions = {'➔', '✓', '✗', '→', '•'};

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final matches = emojiRegex.allMatches(line);
          for (final m in matches) {
            final char = m.group(0)!;
            if (!allowedExceptions.contains(char)) {
              violations.add('${entity.path}:${i + 1} -> "$char" in: ${line.trim()}');
            }
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Projede emoji kullanımı tavizsiz şekilde yasaktır. Bulunan emojiler:\n${violations.join('\n')}',
    );
  });
}
