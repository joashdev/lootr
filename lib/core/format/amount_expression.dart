class AmountExpression {
  const AmountExpression._();

  static double evaluate(String expression) {
    final parser = _AmountExpressionParser(expression);
    final value = parser.parse();
    if (!value.isFinite) {
      throw const FormatException('Result must be a finite number');
    }
    return value;
  }
}

class _AmountExpressionParser {
  _AmountExpressionParser(this.source);

  final String source;
  int index = 0;

  double parse() {
    final value = _expression();
    _skipWhitespace();
    if (index != source.length) {
      throw FormatException('Unexpected character at ${index + 1}');
    }
    return value;
  }

  double _expression() {
    var value = _term();
    while (true) {
      _skipWhitespace();
      if (_consume('+')) {
        value += _term();
      } else if (_consume('-')) {
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _factor();
    while (true) {
      _skipWhitespace();
      if (_consume('*')) {
        value *= _factor();
      } else if (_consume('/')) {
        final divisor = _factor();
        if (divisor == 0) throw const FormatException('Cannot divide by zero');
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _factor() {
    _skipWhitespace();
    if (_consume('+')) return _factor();
    if (_consume('-')) return -_factor();
    if (_consume('(')) {
      final value = _expression();
      _skipWhitespace();
      if (!_consume(')')) throw const FormatException('Missing closing )');
      return value;
    }
    return _number();
  }

  double _number() {
    _skipWhitespace();
    final start = index;
    var hasDecimal = false;
    while (index < source.length) {
      final character = source[index];
      if (character == '.') {
        if (hasDecimal) break;
        hasDecimal = true;
        index++;
      } else if (_isDigit(character)) {
        index++;
      } else {
        break;
      }
    }
    if (start == index) throw const FormatException('Expected a number');
    final value = double.tryParse(source.substring(start, index));
    if (value == null) throw const FormatException('Invalid number');
    return value;
  }

  bool _consume(String character) {
    if (index >= source.length || source[index] != character) return false;
    index++;
    return true;
  }

  void _skipWhitespace() {
    while (index < source.length && source[index].trim().isEmpty) {
      index++;
    }
  }

  bool _isDigit(String character) {
    final code = character.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
