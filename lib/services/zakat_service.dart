/// Zakat on wealth (zakat al-mal), mainstream fiqh:
/// - Nisab: 85 g of pure gold or 595 g of silver (user chooses the standard).
/// - Rate: 2.5% (1/40) of net zakatable wealth held for a full lunar year.
/// Gold of lower purity is converted to pure-gold weight (karat / 24).
class ZakatInput {
  const ZakatInput({
    this.cash = 0,
    this.goldGrams = 0,
    this.goldKarat = 24,
    this.silverGrams = 0,
    this.investments = 0,
    this.receivables = 0,
    this.debts = 0,
    this.goldPricePerGram = 0,
    this.silverPricePerGram = 0,
    this.useSilverNisab = false,
  });

  final double cash;
  final double goldGrams;
  final int goldKarat; // 24 | 21 | 18
  final double silverGrams;
  final double investments; // trade goods, shares, savings
  final double receivables; // money owed to you that you expect to recover
  final double debts; // debts due now
  final double goldPricePerGram; // price of 24k gold per gram
  final double silverPricePerGram;
  final bool useSilverNisab;
}

class ZakatResult {
  const ZakatResult({
    required this.goldValue,
    required this.silverValue,
    required this.total,
    required this.net,
    required this.nisab,
    required this.zakat,
    required this.nisabKnown,
  });
  final double goldValue;
  final double silverValue;
  final double total;
  final double net;
  final double nisab;
  final double zakat;

  /// False when the price needed for the chosen nisab was not entered.
  final bool nisabKnown;
  bool get due => nisabKnown && net >= nisab && net > 0;
}

class ZakatService {
  ZakatService._();
  static const goldNisabGrams = 85.0;
  static const silverNisabGrams = 595.0;
  static const rate = 0.025;

  static ZakatResult compute(ZakatInput i) {
    final pureGold = i.goldGrams * (i.goldKarat / 24);
    final goldValue = pureGold * i.goldPricePerGram;
    final silverValue = i.silverGrams * i.silverPricePerGram;
    final total = i.cash + goldValue + silverValue + i.investments + i.receivables;
    final net = total - i.debts;
    final price = i.useSilverNisab ? i.silverPricePerGram : i.goldPricePerGram;
    final nisab = (i.useSilverNisab ? silverNisabGrams : goldNisabGrams) * price;
    final known = price > 0;
    final due = known && net >= nisab && net > 0;
    return ZakatResult(
      goldValue: goldValue,
      silverValue: silverValue,
      total: total,
      net: net,
      nisab: nisab,
      zakat: due ? net * rate : 0,
      nisabKnown: known,
    );
  }
}
