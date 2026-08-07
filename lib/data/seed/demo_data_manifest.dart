enum DemoEntityType {
  user('users'),
  account('accounts'),
  payee('payees'),
  transaction('transactions'),
  budget('budgets'),
  goal('goals'),
  debt('debt_records'),
  recurring('recurring_templates');

  final String tableName;

  const DemoEntityType(this.tableName);
}

class DemoRecordRef {
  final DemoEntityType entityType;
  final String entityId;

  const DemoRecordRef(this.entityType, this.entityId);
}

/// Exact IDs emitted by the current sample-data loader.
///
/// Legacy recovery must use this manifest instead of treating an arbitrary
/// `demo-` prefix as proof that a record belongs to Lootr.
class DemoDataManifest {
  static const seedVersion = 1;
  static const userId = 'demo-user-1';

  static const accountIds = [
    'demo-acc-bdo-savings',
    'demo-acc-gcash',
    'demo-acc-bpi-checking',
    'demo-acc-cash',
  ];

  static const payeeIds = [
    'demo-pay-jollibee',
    'demo-pay-mcdonalds',
    'demo-pay-mercury-drug',
    'demo-pay-sm-supermarket',
    'demo-pay-grab',
    'demo-pay-angkas',
    'demo-pay-meralco',
    'demo-pay-pldt',
    'demo-pay-converge',
    'demo-pay-landers',
    'demo-pay-shopee',
    'demo-pay-lazada',
    'demo-pay-7-eleven',
    'demo-pay-starbucks',
    'demo-pay-puregold',
    'demo-pay-netflix',
  ];

  static const budgetIds = [
    'demo-budget-food',
    'demo-budget-transport',
    'demo-budget-shopping',
    'demo-budget-entertainment',
  ];

  static const goalIds = ['demo-goal-emergency', 'demo-goal-japan'];

  static const debtIds = [
    'demo-debt-credit-card',
    'demo-debt-bnpl-phone',
    'demo-debt-lent-miguel',
  ];

  static const recurringIds = [
    'demo-rec-netflix',
    'demo-rec-meralco',
    'demo-rec-salary',
    'demo-rec-rent',
  ];

  static final transactionIds = List<String>.unmodifiable(
    List.generate(
      43,
      (index) => 'demo-txn-m${(index + 1).toString().padLeft(3, '0')}',
    ),
  );

  static List<DemoRecordRef> get knownRecords => [
    const DemoRecordRef(DemoEntityType.user, userId),
    for (final id in accountIds) DemoRecordRef(DemoEntityType.account, id),
    for (final id in payeeIds) DemoRecordRef(DemoEntityType.payee, id),
    for (final id in transactionIds)
      DemoRecordRef(DemoEntityType.transaction, id),
    for (final id in budgetIds) DemoRecordRef(DemoEntityType.budget, id),
    for (final id in goalIds) DemoRecordRef(DemoEntityType.goal, id),
    for (final id in debtIds) DemoRecordRef(DemoEntityType.debt, id),
    for (final id in recurringIds) DemoRecordRef(DemoEntityType.recurring, id),
  ];

  const DemoDataManifest._();
}
