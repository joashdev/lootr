enum SyncStatus { localOnly, pendingSync, synced, syncFailed }

enum TransactionDirection { expense, income, transfer }

enum TransactionMode { oneTime, recurring, installment, debt }

enum TransactionSubtype { salary, refund, transferFee, subscription, loanPayment, debtPayment, openingBalance }

enum AccountType { cash, bank, ewallet, savings, investment, crypto, creditCard, loan, bnpl }

enum CategoryGroup { expense, income, transfer }

enum MemberRole { owner, member, viewer }

enum DebtDirection { lent, borrowed }

enum DebtStatus { active, partiallyPaid, settled }

enum GoalType { emergencyFund, savings, travel, debtPayoff, custom }

enum NotificationType { recurringReminder, billDue, installmentDue, debtReminder, subscriptionReminder }

enum AiSourceType { ocr, nlp, categorization }
