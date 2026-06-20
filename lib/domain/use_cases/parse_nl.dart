import '../value_objects/result.dart';
import '../value_objects/parsed_transaction.dart';
import '../../ai/nl_parser.dart';

class ParseNL {
  NLParser _parser;
  final bool _aiEnabled;

  ParseNL({
    NLParser? parser,
    List<String> knownPayees = const [],
    List<String> knownAccounts = const [],
    bool aiEnabled = true,
  })  : _parser = parser ??
            NLParser(
              knownPayees: knownPayees,
              knownAccounts: knownAccounts,
            ),
        _aiEnabled = aiEnabled;

  Result<ParsedTransaction> call(String rawText) {
    if (!_aiEnabled) {
      return Failure('AI features are disabled', code: 'ai_disabled');
    }
    if (rawText.trim().isEmpty) {
      return Failure('Input text is empty', code: 'empty_input');
    }

    final result = _parser.parse(rawText.trim());

    if (result == null) {
      return Failure('Could not extract amount from input',
          code: 'parse_failed');
    }

    return Success(result.parsed);
  }

  void updateLists({
    List<String>? knownPayees,
    List<String>? knownAccounts,
  }) {
    _parser = _parser.copyWith(
      knownPayees: knownPayees ?? _parser.knownPayees,
      knownAccounts: knownAccounts ?? _parser.knownAccounts,
    );
  }
}
