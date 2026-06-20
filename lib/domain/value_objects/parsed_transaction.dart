class ParsedTransaction {
  final double? amount;
  final String? payee;
  final String? account;
  final String? category;
  final String? direction;
  final String? note;
  final double confidence;

  const ParsedTransaction({
    this.amount,
    this.payee,
    this.account,
    this.category,
    this.direction,
    this.note,
    this.confidence = 0.0,
  });

  ParsedTransaction copyWith({
    double? Function()? amount,
    String? Function()? payee,
    String? Function()? account,
    String? Function()? category,
    String? Function()? direction,
    String? Function()? note,
    double? confidence,
  }) {
    return ParsedTransaction(
      amount: amount != null ? amount() : this.amount,
      payee: payee != null ? payee() : this.payee,
      account: account != null ? account() : this.account,
      category: category != null ? category() : this.category,
      direction: direction != null ? direction() : this.direction,
      note: note != null ? note() : this.note,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ParsedTransaction &&
      amount == other.amount &&
      payee == other.payee &&
      account == other.account &&
      category == other.category &&
      direction == other.direction &&
      note == other.note &&
      confidence == other.confidence;

  @override
  int get hashCode => Object.hash(amount, payee, account, category, direction,
      note, confidence);

  @override
  String toString() =>
      'ParsedTransaction(amount=$amount, payee=$payee, account=$account, '
      'category=$category, direction=$direction, note=$note, '
      'confidence=$confidence)';
}
