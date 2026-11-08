/// The customer's booking deposit for an accepted trip. While it is awaited,
/// the driver does not set off; once paid, it counts toward the fare and is
/// not collected in cash.
class TripDeposit {
  final double amount;
  final String status;
  final DateTime? dueAt;
  final DateTime? paidAt;
  final double appliedAmount;
  final double driverShare;

  /// Server clock minus this phone's clock when it was read.
  final Duration clockOffset;

  TripDeposit({
    required this.amount,
    required this.status,
    this.dueAt,
    this.paidAt,
    this.appliedAmount = 0,
    this.driverShare = 0,
    this.clockOffset = Duration.zero,
  });

  bool get isAwaiting => status == 'awaiting';
  bool get isPaid => status == 'paid';
  bool get isApplied => status == 'applied';

  Duration get timeLeft {
    if (dueAt == null) return Duration.zero;
    final left = dueAt!.difference(DateTime.now().add(clockOffset));
    return left.isNegative ? Duration.zero : left;
  }

  static DateTime? _time(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());
  static double _num(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

  static TripDeposit? fromJson(dynamic json) {
    if (json is! Map) return null;
    final server = _time(json['server_time']);
    return TripDeposit(
      amount: _num(json['amount']),
      status: json['status']?.toString() ?? '',
      dueAt: _time(json['due_at']),
      paidAt: _time(json['paid_at']),
      appliedAmount: _num(json['applied_amount']),
      driverShare: _num(json['driver_share']),
      clockOffset: server == null ? Duration.zero : server.difference(DateTime.now()),
    );
  }
}
