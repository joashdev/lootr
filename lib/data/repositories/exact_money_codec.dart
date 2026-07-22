import '../../domain/value_objects/exact_money.dart';
import '../database/app_database.dart';

/// Converts legacy `REAL` projections at the repository boundary.
///
/// New and imported rows carry coefficient/scale/currency columns. Existing
/// pre-v3 rows are promoted once, using their account precision, before any
/// ledger mutation is applied.
class ExactMoneyCodec {
  const ExactMoneyCodec._();

  static const int legacyScale = 2;

  static ExactMoney accountBalance(AccountData account) {
    final scale = account.currencyPrecision ?? legacyScale;
    final atoms = account.balanceAtoms;
    if (atoms != null) {
      return ExactMoney(
        coefficient: BigInt.parse(atoms),
        scale: scale,
        currencyCode: account.currencyCode,
      );
    }
    return fromLegacyDouble(account.balance, account.currencyCode, scale);
  }

  static ExactMoney transactionAmount(
    TransactionData transaction,
    AccountData account, {
    bool preferLegacyProjection = false,
  }) {
    if (!preferLegacyProjection &&
        transaction.amountAtoms != null &&
        transaction.amountScale != null &&
        transaction.currencyCode != null) {
      final amount = ExactMoney(
        coefficient: BigInt.parse(transaction.amountAtoms!),
        scale: transaction.amountScale!,
        currencyCode: transaction.currencyCode!,
      );
      _requireAccountCurrency(amount, account);
      return amount;
    }
    return fromLegacyDouble(
      transaction.amount,
      account.currencyCode,
      account.currencyPrecision ?? legacyScale,
    );
  }

  static ExactMoney transferSourceAmount(
    TransferData transfer,
    AccountData source, {
    bool preferLegacyProjection = false,
  }) {
    if (!preferLegacyProjection &&
        transfer.sourceAmountAtoms != null &&
        transfer.sourceAmountScale != null &&
        transfer.sourceCurrencyCode != null) {
      final amount = ExactMoney(
        coefficient: BigInt.parse(transfer.sourceAmountAtoms!),
        scale: transfer.sourceAmountScale!,
        currencyCode: transfer.sourceCurrencyCode!,
      );
      _requireAccountCurrency(amount, source);
      return amount;
    }
    return fromLegacyDouble(
      transfer.amount,
      source.currencyCode,
      source.currencyPrecision ?? legacyScale,
    );
  }

  static ExactMoney transferDestinationAmount(
    TransferData transfer,
    AccountData destination, {
    bool preferLegacyProjection = false,
  }) {
    if (!preferLegacyProjection &&
        transfer.destinationAmountAtoms != null &&
        transfer.destinationAmountScale != null &&
        transfer.destinationCurrencyCode != null) {
      final amount = ExactMoney(
        coefficient: BigInt.parse(transfer.destinationAmountAtoms!),
        scale: transfer.destinationAmountScale!,
        currencyCode: transfer.destinationCurrencyCode!,
      );
      _requireAccountCurrency(amount, destination);
      return amount;
    }
    return fromLegacyDouble(
      transfer.amount,
      destination.currencyCode,
      destination.currencyPrecision ?? legacyScale,
    );
  }

  static ExactMoney transferFee(
    TransferData transfer,
    AccountData source, {
    bool preferLegacyProjection = false,
  }) {
    if (!preferLegacyProjection &&
        transfer.feeAmountAtoms != null &&
        transfer.feeAmountScale != null &&
        transfer.feeCurrencyCode != null) {
      final fee = ExactMoney(
        coefficient: BigInt.parse(transfer.feeAmountAtoms!),
        scale: transfer.feeAmountScale!,
        currencyCode: transfer.feeCurrencyCode!,
      );
      _requireAccountCurrency(fee, source);
      return fee;
    }
    return fromLegacyDouble(
      transfer.feeAmount ?? 0,
      source.currencyCode,
      source.currencyPrecision ?? legacyScale,
    );
  }

  static ExactMoney fromLegacyDouble(
    double value,
    String currencyCode,
    int scale,
  ) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    return ExactMoney.parse(value.toStringAsFixed(scale), currencyCode);
  }

  static double legacyProjection(ExactMoney value) =>
      double.parse(value.toDecimalString());

  static void requirePositive(ExactMoney value, String field) {
    if (value.coefficient <= BigInt.zero) {
      throw ArgumentError.value(value.toDecimalString(), field, 'must be > 0');
    }
  }

  static ExactMoney atAccountScale(ExactMoney value, AccountData account) {
    _requireAccountCurrency(value, account);
    return value.rescale(account.currencyPrecision ?? legacyScale);
  }

  static void _requireAccountCurrency(ExactMoney value, AccountData account) {
    if (value.currencyCode != account.currencyCode) {
      throw ArgumentError('Money currency does not match the account currency');
    }
  }
}
