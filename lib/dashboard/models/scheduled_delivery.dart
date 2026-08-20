class ScheduledDelivery {
  const ScheduledDelivery({
    required this.deliveryId,
    required this.scheduleDate,
    required this.vehicle,
    required this.plateNo,
    required this.driverName,
    required this.drNo,
    required this.totalAmount,
  });

  final int deliveryId;
  final DateTime? scheduleDate;
  final String vehicle;
  final String plateNo;
  final String driverName;
  final String drNo;
  final double totalAmount;

  factory ScheduledDelivery.fromJson(Map<String, dynamic> json) {
    return ScheduledDelivery(
      deliveryId: int.tryParse(json['deliveryid']?.toString() ?? '') ?? 0,
      scheduleDate: DateTime.tryParse(json['scheduledate']?.toString() ?? ''),
      vehicle: json['vehicle']?.toString().trim() ?? '',
      plateNo: json['plateno']?.toString().trim() ?? '',
      driverName: json['drivername']?.toString().trim() ?? '',
      drNo: json['drno']?.toString().trim() ?? '',
      totalAmount: double.tryParse(json['totalamount']?.toString() ?? '') ?? 0,
    );
  }
}
