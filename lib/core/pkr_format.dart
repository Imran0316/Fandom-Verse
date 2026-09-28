/// Normalises a seller-entered price label (`$59`, `Rs 1,200`, `PKR 999`)
/// into a PKR label. Any currency symbol/prefix is stripped first so the
/// amount is never double-prefixed.
String formatPkrPrice(String raw) {
  final amount = raw.replaceAll(RegExp(r'[^0-9.,]'), '').trim();
  return 'PKR ${amount.isEmpty ? '0' : amount}';
}
