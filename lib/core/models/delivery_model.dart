class DeliveryDetails {
  final String? selectedAddressId;
  final String? address;
  final String contactNumber;
  final String? deliveryNotes;
  final String? customerName;
  final String? orderComment;

  const DeliveryDetails({
    this.selectedAddressId,
    this.address,
    required this.contactNumber,
    this.deliveryNotes,
    this.customerName,
    this.orderComment,
  });

  factory DeliveryDetails.fromJson(Map<String, dynamic> json) {
    return DeliveryDetails(
      selectedAddressId: json['selectedAddressId'],
      address: json['address'],
      contactNumber: json['contactNumber'] ?? '',
      deliveryNotes: json['deliveryNotes'],
      customerName: json['customerName'],
      orderComment: json['orderComment'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (selectedAddressId != null) 'selectedAddressId': selectedAddressId,
      if (address != null) 'address': address,
      'contactNumber': contactNumber,
      if (deliveryNotes != null) 'deliveryNotes': deliveryNotes,
      if (customerName != null) 'customerName': customerName,
      if (orderComment != null) 'orderComment': orderComment,
    };
  }

  DeliveryDetails copyWith({
    String? selectedAddressId,
    String? address,
    String? contactNumber,
    String? deliveryNotes,
    String? customerName,
    String? orderComment,
  }) {
    return DeliveryDetails(
      selectedAddressId: selectedAddressId ?? this.selectedAddressId,
      address: address ?? this.address,
      contactNumber: contactNumber ?? this.contactNumber,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      customerName: customerName ?? this.customerName,
      orderComment: orderComment ?? this.orderComment,
    );
  }

  bool get hasAddress => selectedAddressId != null || address != null;
}
