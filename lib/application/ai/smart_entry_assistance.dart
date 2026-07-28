import '../../ai/categorizer.dart';
import '../../domain/entities/category.dart';
import '../../domain/use_cases/parse_nl.dart';
import '../../domain/value_objects/parsed_transaction.dart';
import '../../domain/value_objects/result.dart';
import '../categorization/category_matcher.dart';

/// Application boundary for parsing entry text and enriching its preview.
///
/// Suggestions stay as [ParsedTransaction] values. This service has no ledger
/// repository and therefore cannot finalize a transaction.
class SmartEntryAssistance {
  const SmartEntryAssistance(this._parseNL, this._categorizer);

  final ParseNL _parseNL;
  final Categorizer _categorizer;

  Future<Result<ParsedTransaction>> parse(
    String rawText,
    List<Category> categories,
  ) async {
    final result = _parseNL(rawText);
    if (result is Failure<ParsedTransaction>) return result;
    final parsed = (result as Success<ParsedTransaction>).value;
    return Success(await enrich(parsed, categories));
  }

  Future<ParsedTransaction> enrich(
    ParsedTransaction parsed,
    List<Category> categories,
  ) async {
    if (parsed.category != null) return parsed;
    final suggestion = await _categorizer.suggest(
      amount: parsed.amount,
      payee: parsed.payee,
      note: parsed.note,
      direction: parsed.direction,
    );
    if (suggestion == null) return parsed;
    final category = CategoryMatcher.resolve(
      idOrLabel: suggestion.categoryId,
      direction: parsed.direction,
      categories: categories,
    );
    return category == null
        ? parsed
        : parsed.copyWith(category: () => category.name);
  }
}
