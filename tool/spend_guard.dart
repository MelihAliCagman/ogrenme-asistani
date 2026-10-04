// Shared spend guard for every tool that calls the (paid) Gemini API.
//
// Keeps a running total of the money spent in tool/spend_ledger.json
// (gitignored, local state) and refuses to start a call that could push
// the total past the budget the caller passed in (--budget-usd). Raising
// the budget later (after topping up credit in AI Studio) is all it takes
// to continue: the ledger remembers what was already spent.
//
// Costs are computed from the token counts Gemini returns in
// `usageMetadata`. Thinking tokens are billed as output, so they are
// counted too. Prices below are USD per 1M tokens, taken from
// https://ai.google.dev/gemini-api/docs/pricing — re-check them before
// relying on the numbers, Google changes them.

import 'dart:convert';
import 'dart:io';

class BudgetExceeded implements Exception {
  BudgetExceeded(this.message);
  final String message;
  @override
  String toString() => message;
}

class ModelPrice {
  const ModelPrice({required this.inputPerM, required this.outputPerM});
  final double inputPerM;
  final double outputPerM;
}

/// `gemini-flash-lite-latest` currently resolves to Gemini 3.5 Flash-Lite.
const ModelPrice flashLitePrice = ModelPrice(inputPerM: 0.30, outputPerM: 2.50);
const ModelPrice flashPrice = ModelPrice(inputPerM: 1.50, outputPerM: 9.00);

ModelPrice priceFor(String model) {
  if (model.contains('lite')) return flashLitePrice;
  return flashPrice;
}

class SpendGuard {
  SpendGuard({
    required this.budgetUsd,
    required this.model,
    this.ledgerPath = 'tool/spend_ledger.json',
  }) {
    _load();
  }

  final double budgetUsd;
  final String model;
  final String ledgerPath;

  double totalUsd = 0;
  int inputTokens = 0;
  int outputTokens = 0;
  int requests = 0;

  ModelPrice get _price => priceFor(model);

  double costOf(int input, int output) =>
      input / 1e6 * _price.inputPerM + output / 1e6 * _price.outputPerM;

  double get remainingUsd => budgetUsd - totalUsd;

  /// Cost of a hypothetical call, without needing a ledger (used for
  /// --dry-run estimates).
  static double estimateCost(String model, int input, int output) {
    final price = priceFor(model);
    return input / 1e6 * price.inputPerM + output / 1e6 * price.outputPerM;
  }

  /// Rough token estimate for Turkish text (~2.5 characters per token).
  static int estimateTokens(String text) => (text.length / 2.5).ceil();

  /// Throws [BudgetExceeded] if a call with [inputTokens] of input and up to
  /// [maxOutputTokens] of output could exceed the budget.
  void assertCanSpend({required int inputTokens, required int maxOutputTokens}) {
    final worstCase = costOf(inputTokens, maxOutputTokens);
    if (totalUsd + worstCase > budgetUsd) {
      throw BudgetExceeded(
        'Bütçe doldu: harcanan \$${totalUsd.toStringAsFixed(4)}, '
        'sıradaki istek en fazla \$${worstCase.toStringAsFixed(4)} tutabilir, '
        'bütçe \$${budgetUsd.toStringAsFixed(2)}. Kredi yükledikten sonra '
        '--budget-usd değerini artırıp aynı komutu tekrar çalıştır; '
        'kaldığı yerden devam eder.',
      );
    }
  }

  /// Records the real usage from a response's `usageMetadata`.
  void record(Map<String, dynamic>? usage) {
    if (usage == null) return;
    final input = (usage['promptTokenCount'] as num?)?.toInt() ?? 0;
    final output = ((usage['candidatesTokenCount'] as num?)?.toInt() ?? 0) +
        ((usage['thoughtsTokenCount'] as num?)?.toInt() ?? 0);
    inputTokens += input;
    outputTokens += output;
    requests += 1;
    totalUsd += costOf(input, output);
    _save();
  }

  String summary() =>
      'Toplam harcama: \$${totalUsd.toStringAsFixed(4)} / '
      '\$${budgetUsd.toStringAsFixed(2)} (kalan '
      '\$${remainingUsd.toStringAsFixed(4)}), $requests istek, '
      '$inputTokens giriş + $outputTokens çıkış token';

  void _load() {
    final file = File(ledgerPath);
    if (!file.existsSync()) return;
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    totalUsd = (data['totalUsd'] as num?)?.toDouble() ?? 0;
    inputTokens = (data['inputTokens'] as num?)?.toInt() ?? 0;
    outputTokens = (data['outputTokens'] as num?)?.toInt() ?? 0;
    requests = (data['requests'] as num?)?.toInt() ?? 0;
  }

  void _save() {
    File(ledgerPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'totalUsd': totalUsd,
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'requests': requests,
      }),
    );
  }
}
