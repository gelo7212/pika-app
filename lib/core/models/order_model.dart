import '../models/address_model.dart';
import '../models/delivery_model.dart';
import '../models/addon_model.dart';
import '../providers/cart_provider.dart';

class OrderItem {
  final String itemName;
  final String itemId;
  final double price;
  final int qty;
  final String status;
  final double totalAmount;
  final double amountDue;
  final OrderDiscount discount;
  final String size;
  final List<Addon> addons;
  final String comment;
  final double totalDiscount;

  const OrderItem({
    required this.itemName,
    required this.itemId,
    required this.price,
    required this.qty,
    required this.status,
    required this.totalAmount,
    required this.amountDue,
    required this.discount,
    required this.size,
    required this.addons,
    required this.comment,
    required this.totalDiscount,
  });

  factory OrderItem.fromCartItem(CartItem cartItem) {
    // CartItem now already has List<Addon> addons
    return OrderItem(
      itemName: cartItem.product['name'] ?? 'Unknown Product', // Use just the product name, not displayName
      itemId: cartItem.variant['_id'] ?? cartItem.variant['id'] ?? '',
      price: cartItem.basePrice / cartItem.quantity,
      qty: cartItem.quantity,
      status: 'Pending',
      totalAmount: cartItem.totalPrice,
      amountDue: cartItem.totalPrice,
      discount: const OrderDiscount.none(),
      size: cartItem.variant['size'] ?? '',
      addons: cartItem.addons, // Direct assignment since it's already List<Addon>
      comment: '',
      totalDiscount: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'itemId': itemId,
      'price': price,
      'qty': qty,
      'status': status,
      'totalAmount': totalAmount,
      'amountDue': amountDue,
      'discount': discount.toJson(),
      'size': size,
      'addons': addons.map((addon) => addon.toJson()).toList(),
      'comment': comment,
      'totalDiscount': totalDiscount,
    };
  }
}

class OrderDiscount {
  final String type;
  final double value;
  final String id;
  final String name;

  const OrderDiscount({
    required this.type,
    required this.value,
    required this.id,
    required this.name,
  });

  const OrderDiscount.none()
      : type = 'none',
        value = 0,
        id = '',
        name = '';

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'id': id,
      'name': name,
    };
  }
}

class CustomerLocation {
  final String id;
  final LocationCoordinates coordinates;
  final String address;

  const CustomerLocation({
    required this.id,
    required this.coordinates,
    required this.address,
  });

  factory CustomerLocation.fromAddress(Address address) {
    return CustomerLocation(
      id: address.id ?? 'LOC001',
      coordinates: LocationCoordinates(
        type: 'Point',
        coordinates: [address.longitude, address.latitude],
      ),
      address: address.address,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coordinates': coordinates.toJson(),
      'address': address,
    };
  }
}

class LocationCoordinates {
  final String type;
  final List<double> coordinates;

  const LocationCoordinates({
    required this.type,
    required this.coordinates,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
    };
  }
}

class Quotation {
  final String quotationId;
  final DateTime expiresAt;

  const Quotation({
    required this.quotationId,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'quotationId': quotationId,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}
class OrderDeliveryDetails {
  final CustomerLocation customerLocation;
  final String status;
  final Quotation? quotation;

  const OrderDeliveryDetails({
    required this.customerLocation,
    required this.status,
    this.quotation,
  });

  Map<String, dynamic> toJson() {
    return {
      'customerLocation': customerLocation.toJson(),
      'status': status,
      'quotation': quotation?.toJson(),
    };
  }
}

class OrderDeliveryInfo {
  final String address;
  final String contactNumber;
  final String deliveryNotes;
  final OrderDeliveryDetails deliveryDetails;

  const OrderDeliveryInfo({
    required this.address,
    required this.contactNumber,
    required this.deliveryNotes,
    required this.deliveryDetails,
  });

  factory OrderDeliveryInfo.fromDeliveryDetailsAndAddress(
    DeliveryDetails deliveryDetails,
    Address address,
  ) {
    return OrderDeliveryInfo(
      address: address.address,
      contactNumber: deliveryDetails.contactNumber,
      deliveryNotes: deliveryDetails.deliveryNotes ?? '',
      deliveryDetails: OrderDeliveryDetails(
        customerLocation: CustomerLocation.fromAddress(address),
        status: 'en route',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'contactNumber': contactNumber,
      'deliveryNotes': deliveryNotes,
      'deliveryDetails': deliveryDetails.toJson(),
    };
  }
}

class PaymentMethod {
  final String method;

  const PaymentMethod({
    required this.method,
  });

  Map<String, dynamic> toJson() {
    return {
      'method': method,
    };
  }
}

class Order {
  final String storeId;
  final List<OrderItem> items;
  final String customerName;
  final String orderComment;
  final OrderDeliveryInfo deliveryInfo;
  final List<PaymentMethod> paymentMethod;

  const Order({
    required this.storeId,
    required this.items,
    required this.customerName,
    required this.orderComment,
    required this.deliveryInfo,
    required this.paymentMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'storeId': storeId,
      'items': items.map((item) => item.toJson()).toList(),
      'customerName': customerName,
      'orderComment': orderComment,
      'deliveryInfo': deliveryInfo.toJson(),
      'paymentMethod': paymentMethod.map((pm) => pm.toJson()).toList(),
    };
  }
}
