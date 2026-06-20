class TransactionDirection {
  const TransactionDirection._();
  static const expense = 'expense';
  static const income = 'income';
  static const transfer = 'transfer';
}

class TransactionMode {
  const TransactionMode._();
  static const oneTime = 'one_time';
  static const recurring = 'recurring';
  static const installment = 'installment';
  static const debt = 'debt';
}

class TransactionSubtype {
  const TransactionSubtype._();
  static const salary = 'salary';
  static const refund = 'refund';
  static const transferFee = 'transfer_fee';
  static const subscription = 'subscription';
  static const loanPayment = 'loan_payment';
  static const debtPayment = 'debt_payment';
  static const openingBalance = 'opening_balance';
}

class AccountType {
  const AccountType._();
  static const cash = 'cash';
  static const bank = 'bank';
  static const ewallet = 'ewallet';
  static const savings = 'savings';
  static const investment = 'investment';
  static const crypto = 'crypto';
  static const creditCard = 'credit_card';
  static const loan = 'loan';
  static const bnpl = 'bnpl';
}

class CategoryGroup {
  const CategoryGroup._();
  static const expense = 'expense';
  static const income = 'income';
  static const transfer = 'transfer';
}

class DebtDirection {
  const DebtDirection._();
  static const lent = 'lent';
  static const borrowed = 'borrowed';
}

class DebtStatus {
  const DebtStatus._();
  static const active = 'active';
  static const partiallyPaid = 'partially_paid';
  static const settled = 'settled';
}

class GoalType {
  const GoalType._();
  static const emergencyFund = 'emergency_fund';
  static const savings = 'savings';
  static const travel = 'travel';
  static const debtPayoff = 'debt_payoff';
  static const custom = 'custom';
}

class HouseholdRole {
  const HouseholdRole._();
  static const owner = 'owner';
  static const member = 'member';
  static const viewer = 'viewer';
}

class SyncStatus {
  const SyncStatus._();
  static const localOnly = 'local_only';
  static const pendingSync = 'pending_sync';
  static const synced = 'synced';
  static const syncFailed = 'sync_failed';
}
