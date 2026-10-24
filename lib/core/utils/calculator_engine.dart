class CalculatorEngine {
  CalculatorEngine._();

  /// Verilen matematiksel ifadeyi (+, -, ×, *, ÷, /, %) güvenle hesaplar
  static double evaluate(String expression) {
    if (expression.trim().isEmpty) return 0.0;

    String clean = expression
        .replaceAll(' ', '')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(',', '.');

    // Sondaki tamamlanmamış işleçleri, tek başına % ve noktaları temizle (örn: "150+" -> "150", "150+%" -> "150", "150." -> "150")
    while (clean.isNotEmpty) {
      final last = clean[clean.length - 1];
      if (_isBinaryOperator(last) || last == '.') {
        clean = clean.substring(0, clean.length - 1);
      } else if (last == '%' && (clean.length == 1 || _isOperator(clean[clean.length - 2]))) {
        // Önünde geçerli sayı olmayan % işleci
        clean = clean.substring(0, clean.length - 1);
      } else {
        break;
      }
    }

    if (clean.isEmpty) return 0.0;

    try {
      // Yüzde (%) işlemlerini çöz
      clean = _resolvePercentages(clean);

      // İfadeleri tokenlara böl
      final tokens = _tokenize(clean);
      if (tokens.isEmpty) return 0.0;

      // İşlem önceliği 1: Çarpma (*) ve Bölme (/)
      final intermediate = <dynamic>[];
      int i = 0;
      while (i < tokens.length) {
        final token = tokens[i];
        if (token == '*' || token == '/') {
          if (intermediate.isEmpty || i + 1 >= tokens.length || tokens[i + 1] is! double) {
            i++;
            continue;
          }
          final prev = intermediate.removeLast() as double;
          final next = tokens[i + 1] as double;
          if (token == '*') {
            intermediate.add(prev * next);
          } else {
            intermediate.add(next != 0 ? prev / next : prev);
          }
          i += 2;
        } else {
          intermediate.add(token);
          i++;
        }
      }

      if (intermediate.isEmpty || intermediate[0] is! double) return 0.0;

      // İşlem önceliği 2: Toplama (+) ve Çıkarma (-)
      double result = intermediate[0] as double;
      int j = 1;
      while (j < intermediate.length) {
        if (j + 1 >= intermediate.length || intermediate[j + 1] is! double) {
          break;
        }
        final op = intermediate[j] as String;
        final next = intermediate[j + 1] as double;
        if (op == '+') {
          result += next;
        } else if (op == '-') {
          result -= next;
        }
        j += 2;
      }

      return double.parse(result.toStringAsFixed(2));
    } catch (_) {
      final direct = double.tryParse(clean);
      return direct ?? 0.0;
    }
  }

  static bool _isBinaryOperator(String ch) {
    return ch == '+' || ch == '-' || ch == '*' || ch == '/';
  }

  static bool _isOperator(String ch) {
    return _isBinaryOperator(ch) || ch == '%';
  }

  static String _resolvePercentages(String input) {
    // 1. Önce "sayı (+ veya -) yüzde%" örn: "200+10%" -> "200+20"
    final addSubRegex = RegExp(r'(\d+(?:\.\d+)?)([\+\-])(\d+(?:\.\d+)?)%');
    String resolved = input.replaceAllMapped(addSubRegex, (match) {
      final base = double.tryParse(match.group(1)!) ?? 0.0;
      final op = match.group(2)!;
      final pct = double.tryParse(match.group(3)!) ?? 0.0;
      final delta = base * (pct / 100.0);
      return '$base$op$delta';
    });

    // 2. Çarpma/bölme veya yalın yüzde: "200*10%" -> "200*0.1"
    final standaloneRegex = RegExp(r'(\d+(?:\.\d+)?)%');
    resolved = resolved.replaceAllMapped(standaloneRegex, (match) {
      final pctValue = double.tryParse(match.group(1)!) ?? 0.0;
      final factor = pctValue / 100.0;
      return factor.toString();
    });

    return resolved;
  }

  static List<dynamic> _tokenize(String input) {
    final tokens = <dynamic>[];
    final numBuffer = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      final char = input[i];

      if (_isOperator(char)) {
        // Negatif sayı kontrolü (en başta veya başka bir operatörden sonra)
        if (char == '-' &&
            (i == 0 || _isOperator(input[i - 1])) &&
            numBuffer.isEmpty) {
          numBuffer.write(char);
          continue;
        }

        if (numBuffer.isNotEmpty) {
          final num = double.tryParse(numBuffer.toString()) ?? 0.0;
          tokens.add(num);
          numBuffer.clear();
        }
        tokens.add(char);
      } else {
        numBuffer.write(char);
      }
    }

    if (numBuffer.isNotEmpty) {
      final num = double.tryParse(numBuffer.toString()) ?? 0.0;
      tokens.add(num);
    }

    return tokens;
  }
}
