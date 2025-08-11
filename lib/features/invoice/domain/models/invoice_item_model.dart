import 'package:equatable/equatable.dart';

class InvoiceItem extends Equatable {
  final String id;
  final String name;
  final String hsn;
  final int quantity;
  final double rate;
  final double amount;

  const InvoiceItem({
    required this.id,
    required this.name,
    required this.hsn,
    required this.quantity,
    required this.rate,
    required this.amount,
  });

  @override
  List<Object?> get props => [id, name, hsn, quantity, rate, amount];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hsn': hsn,
        'quantity': quantity,
        'rate': rate,
        'amount': amount,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        id: json['id'],
        name: json['name'],
        hsn: json['hsn'],
        quantity: json['quantity'],
        rate: json['rate'],
        amount: json['amount'],
      );
}
