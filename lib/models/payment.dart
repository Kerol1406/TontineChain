/// Modèle pour représenter un paiement
class Payment {
  final String id;
  final String tontineId;
  final String memberId;
  final double amount;
  final DateTime paymentDate;
  final String status; // 'pending', 'completed', 'failed'
  final String transactionId;

  Payment({
    required this.id,
    required this.tontineId,
    required this.memberId,
    required this.amount,
    required this.paymentDate,
    required this.status,
    required this.transactionId,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      tontineId: json['tontineId'] as String,
      memberId: json['memberId'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(json['paymentDate'] as String),
      status: json['status'] as String,
      transactionId: json['transactionId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tontineId': tontineId,
      'memberId': memberId,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'status': status,
      'transactionId': transactionId,
    };
  }
}
