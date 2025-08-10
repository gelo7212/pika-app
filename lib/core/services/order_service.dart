import 'package:dio/dio.dart';
import '../models/order_model.dart';
import '../models/addon_model.dart';
import '../config/api_config.dart';
import '../interfaces/token_service_interface.dart';
import '../di/service_locator.dart';

class OrderResponse {
  final String orderNo;
  final String customerName;
  final String orderComment;
  final DateTime orderDate;
  final double basePrice;
  final OrderDiscount discount;
  final double totalDiscount;
  final String orderType;
  final List<PaymentMethodResponse> paymentMethod;
  final String status;
  final double totalAmountDue;
  final double totalAmountPay;
  final List<OrderItem> items;
  final String deliveryProvider;
  final OrderDeliveryInfo deliveryInfo;
  final List<AdditionalFee> additionalFee;
  final String monitoringStatus;
  final double grossSales;
  final String storeId;
  final String platform;
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? isPaid;

  const OrderResponse({
    required this.orderNo,
    required this.customerName,
    required this.orderComment,
    required this.orderDate,
    required this.basePrice,
    required this.discount,
    required this.totalDiscount,
    required this.orderType,
    required this.paymentMethod,
    required this.status,
    required this.totalAmountDue,
    required this.totalAmountPay,
    required this.items,
    required this.deliveryProvider,
    required this.deliveryInfo,
    required this.additionalFee,
    required this.monitoringStatus,
    required this.grossSales,
    required this.storeId,
    required this.platform,
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.isPaid,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      isPaid: json['isPaid'] ?? false,
      orderNo: json['orderNo'] ?? '',
      customerName: json['customerName'] ?? '',
      orderComment: json['orderComment'] ?? '',
      orderDate: json['orderDate'] != null
          ? DateTime.parse(json['orderDate'])
          : DateTime.now(),
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      discount: json['discount'] != null
          ? OrderDiscount(
              type: json['discount']['type'] ?? 'none',
              value: (json['discount']['value'] ?? 0).toDouble(),
              id: json['discount']['id'] ?? '',
              name: json['discount']['name'] ?? '',
            )
          : const OrderDiscount(type: 'none', value: 0, id: '', name: ''),
      totalDiscount: (json['totalDiscount'] ?? 0).toDouble(),
      orderType: json['orderType'] ?? '',
      paymentMethod: (json['paymentMethod'] as List?)
              ?.map((pm) => PaymentMethodResponse.fromJson(pm))
              .toList() ??
          [],
      status: json['status'] ?? '',
      totalAmountDue: (json['totalAmountDue'] ?? 0).toDouble(),
      totalAmountPay: (json['totalAmountPay'] ?? 0).toDouble(),
      items: (json['items'] as List?)
              ?.map((item) => OrderItem(
                    itemName: item['itemName'] ?? '',
                    itemId: item['itemId'] ?? '',
                    price: (item['price'] ?? 0).toDouble(),
                    qty: item['qty'] ?? 0,
                    status: item['status'] ?? '',
                    totalAmount: (item['totalAmount'] ?? 0).toDouble(),
                    amountDue: (item['amountDue'] ?? 0).toDouble(),
                    discount: item['discount'] != null
                        ? OrderDiscount(
                            type: item['discount']['type'] ?? 'none',
                            value: (item['discount']['value'] ?? 0).toDouble(),
                            id: item['discount']['id'] ?? '',
                            name: item['discount']['name'] ?? '',
                          )
                        : const OrderDiscount(
                            type: 'none', value: 0, id: '', name: ''),
                    size: item['size'] ?? '',
                    addons: (item['addons'] as List?)
                            ?.map((addon) => Addon.fromJson(addon))
                            .toList() ??
                        [],
                    comment: item['comment'] ?? '',
                    totalDiscount: (item['totalDiscount'] ?? 0).toDouble(),
                  ))
              .toList() ??
          [],
      deliveryProvider: json['deliveryProvider'] ?? '',
      deliveryInfo: json['deliveryInfo'] != null
          ? OrderDeliveryInfo(
              address: json['deliveryInfo']['address'] ?? '',
              contactNumber: json['deliveryInfo']['contactNumber'] ?? '',
              deliveryNotes: json['deliveryInfo']['deliveryNotes'] ?? '',
              deliveryDetails: json['deliveryInfo']['deliveryDetails'] != null
                  ? OrderDeliveryDetails(
                      customerLocation: json['deliveryInfo']['deliveryDetails']
                                  ['customerLocation'] !=
                              null
                          ? CustomerLocation(
                              id: json['deliveryInfo']['deliveryDetails']
                                      ['customerLocation']['id'] ??
                                  '',
                              coordinates: json['deliveryInfo']
                                              ['deliveryDetails']
                                          ['customerLocation']['coordinates'] !=
                                      null
                                  ? LocationCoordinates(
                                      type: json['deliveryInfo']
                                                      ['deliveryDetails']
                                                  ['customerLocation']
                                              ['coordinates']['type'] ??
                                          'Point',
                                      coordinates: (json['deliveryInfo'][
                                                              'deliveryDetails']
                                                          ['customerLocation']
                                                      ['coordinates']
                                                  ['coordinates'] as List?)
                                              ?.cast<double>() ??
                                          [],
                                    )
                                  : const LocationCoordinates(
                                      type: 'Point', coordinates: []),
                              address: json['deliveryInfo']['deliveryDetails']
                                      ['customerLocation']['address'] ??
                                  '',
                            )
                          : const CustomerLocation(
                              id: '',
                              coordinates: LocationCoordinates(
                                  type: 'Point', coordinates: []),
                              address: ''),
                      status: json['deliveryInfo']['deliveryDetails']
                              ['status'] ??
                          '',
                    )
                  : const OrderDeliveryDetails(
                      customerLocation: CustomerLocation(
                          id: '',
                          coordinates: LocationCoordinates(
                              type: 'Point', coordinates: []),
                          address: ''),
                      status: ''),
            )
          : const OrderDeliveryInfo(
              address: '',
              contactNumber: '',
              deliveryNotes: '',
              deliveryDetails: OrderDeliveryDetails(
                  customerLocation: CustomerLocation(
                      id: '',
                      coordinates:
                          LocationCoordinates(type: 'Point', coordinates: []),
                      address: ''),
                  status: '')),
      additionalFee: (json['additionalFee'] as List?)
              ?.map((fee) => AdditionalFee.fromJson(fee))
              .toList() ??
          [],
      monitoringStatus: json['monitoringStatus'] ?? '',
      grossSales: (json['grossSales'] ?? 0).toDouble(),
      storeId: json['storeId'] ?? '',
      platform: json['platform'] ?? '',
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}

class PaymentMethodResponse {
  final String method;
  final bool bypass;
  final double amount;
  final String referenceNumber;
  final double serviceFee;
  final double totalAmountDue;
  final bool isPaid;
  final String status;
  final DateTime? paymentDate;
  final DateTime updatedAt;
  final String id;
  final DateTime createdAt;
  final PaymentProcessor? paymentProcessor;

  const PaymentMethodResponse({
    required this.method,
    required this.bypass,
    required this.amount,
    required this.referenceNumber,
    required this.serviceFee,
    required this.totalAmountDue,
    required this.isPaid,
    required this.status,
    this.paymentDate,
    required this.updatedAt,
    required this.id,
    required this.createdAt,
    this.paymentProcessor,
  });

  factory PaymentMethodResponse.fromJson(Map<String, dynamic> json) {
    return PaymentMethodResponse(
      method: json['method'] ?? '',
      bypass: json['bypass'] ?? false,
      amount: (json['amount'] ?? 0).toDouble(),
      referenceNumber: json['referenceNumber'] ?? '',
      serviceFee: (json['serviceFee'] ?? 0).toDouble(),
      totalAmountDue: (json['totalAmountDue'] ?? 0).toDouble(),
      isPaid: json['isPaid'] ?? false,
      status: json['status'] ?? '',
      paymentDate: json['paymentDate'] != null
          ? DateTime.parse(json['paymentDate'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      id: json['_id'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      paymentProcessor: json['paymentProcessor'] != null
          ? PaymentProcessor.fromJson(json['paymentProcessor'])
          : null,
    );
  }
}

class PaymentProcessor {
  final String requestReferenceNumber;
  final String processorName;
  final String paymentId;
  final String redirectUrl;
  final String qrCodeBody;

  const PaymentProcessor({
    required this.requestReferenceNumber,
    required this.processorName,
    required this.paymentId,
    required this.redirectUrl,
    required this.qrCodeBody,
  });

  factory PaymentProcessor.fromJson(Map<String, dynamic> json) {
    return PaymentProcessor(
      requestReferenceNumber: json['requestReferenceNumber'] ?? '',
      processorName: json['processorName'] ?? '',
      paymentId: json['paymentId'] ?? '',
      redirectUrl: json['redirectUrl'] ?? '',
      qrCodeBody: json['qrCodeBody'] ?? '',
    );
  }
}

class AdditionalFee {
  final String name;
  final double amount;
  final String type;
  final bool isPercentage;

  const AdditionalFee({
    required this.name,
    required this.amount,
    required this.type,
    required this.isPercentage,
  });

  factory AdditionalFee.fromJson(Map<String, dynamic> json) {
    return AdditionalFee(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'] ?? '',
      isPercentage: json['isPercentage'] ?? false,
    );
  }
}

class PaymentMethodOption {
  final String id;
  final String name;
  final String method;
  final double serviceFee;
  final String storeId;
  final bool isPercentage;
  final bool enableOnlineDelivery;
  final bool enablePos;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentMethodOption({
    required this.id,
    required this.name,
    required this.method,
    required this.serviceFee,
    required this.storeId,
    required this.isPercentage,
    required this.enableOnlineDelivery,
    required this.enablePos,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    return PaymentMethodOption(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      method: json['method'] ?? '',
      serviceFee: (json['serviceFee'] ?? 0).toDouble(),
      storeId: json['storeId'] ?? '',
      isPercentage: json['isPercentage'] ?? false,
      enableOnlineDelivery: json['enableOnlineDelivery'] ?? false,
      enablePos: json['enablePos'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}

class OrderService {
  final Dio _dio;
  final String _baseUrl;

  OrderService({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final tokenService = serviceLocator<TokenServiceInterface>();
    final tokens = await tokenService.getStoredTokens();

    if (tokens == null || tokens.userAccessToken.isEmpty) {
      throw Exception('No authentication token available');
    }

    return {
      ...ApiConfig.getDefaultHeaders(),
      'Authorization': 'Bearer ${tokens.userAccessToken}',
    };
  }

  Future<OrderResponse> createCustomerOrder(Order order) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.post(
        '$_baseUrl/customer/orders',
        data: order.toJson(),
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Check if the response has a 'data' field (wrapped response)
        final orderData = response.data['data'] ?? response.data;
        print('Order data received: ${orderData.toString()}');
        print('Order ID from _id: ${orderData['_id']}');
        print('Order ID from id: ${orderData['id']}');
        return OrderResponse.fromJson(orderData);
      } else {
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage =
            e.response?.data['message'] ?? 'Failed to create order';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }

  Future<OrderResponse> getCustomerOrder(String orderId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/customer/orders/$orderId',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        // Check if the response has a 'data' field (wrapped response)
        final orderData = response.data['data'] ?? response.data;
        return OrderResponse.fromJson(orderData);
      } else {
        throw Exception('Failed to get order: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage =
            e.response?.data['message'] ?? 'Failed to get order';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting order: $e');
    }
  }

  Future<OrderResponse> getCustomerOrderMasked(String orderId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/customer/orders/masked/$orderId',
      );

      if (response.statusCode == 200) {
        // Check if the response has a 'data' field (wrapped response)
        final orderData = response.data['data'] ?? response.data;
        return OrderResponse.fromJson(orderData);
      } else {
        throw Exception('Failed to get order: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage =
            e.response?.data['message'] ?? 'Failed to get order';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting order: $e');
    }
  }

  Future<OrderResponse> updateCustomerOrderPayment(
      String orderId, String paymentMethodId, String storeId) async {
    try {
      final headers = await _getHeaders();

      // Prepare payment method data based on the selected payment method
      Map<String, dynamic> paymentData = {};

      // Handle other payment methods
      paymentData = {
        'storeId': storeId,
        'paymentMethod': [
          {
            '_id': paymentMethodId,
            'bypass': false,
          }
        ]
      };

      final paymentMethod = await getStorePaymentMethods(storeId);
      if (!(paymentMethod.isNotEmpty && paymentMethodId.isNotEmpty)) {
        throw Exception('Payment method not found or invalid');
      }

      if (paymentMethod
          .where((pm) => pm.id == paymentMethodId && pm.method == 'QRPH_XENDIT')
          .isNotEmpty) {
        final response = await _dio.patch(
          '$_baseUrl/customer/orders/$orderId/checkout/xendit/qrph',
          data: paymentData,
          options: Options(headers: headers),
        );

        if (response.statusCode == 200) {
          // Check if the response has a 'data' field (wrapped response)
          final orderData = response.data['data'] ?? response.data;
          return OrderResponse.fromJson(orderData);
        } else {
          throw Exception(
              'Failed to update order payment: ${response.statusCode}');
        }
      } else if (paymentMethod
          .where((pm) => pm.id == paymentMethodId && pm.method == 'QRPH')
          .isNotEmpty) {
        final response = await _dio.patch(
          '$_baseUrl/customer/orders/$orderId/checkout',
          data: paymentData,
          options: Options(headers: headers),
        );

        if (response.statusCode == 200) {
          // Check if the response has a 'data' field (wrapped response)
          final orderData = response.data['data'] ?? response.data;
          return OrderResponse.fromJson(orderData);
        } else {
          throw Exception(
              'Failed to update order payment: ${response.statusCode}');
        }
      } else {
        throw Exception('Payment method not supported');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage =
            e.response?.data['message'] ?? 'Failed to update order payment';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error updating order payment: $e');
    }
  }

  /// Get recent pending orders for the customer
  Future<OrderResponse?> getRecentPendingOrder() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/customer/orders/recent/pending',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null && data is List && data.isNotEmpty) {
          // Return the first pending order
          return OrderResponse.fromJson(data[0]);
        }
        return null; // No pending orders
      } else {
        throw Exception(
            'Failed to get recent pending orders: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage = e.response?.data['message'] ??
            'Failed to get recent pending orders';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting recent pending orders: $e');
    }
  }

  /// Get recent pending orders for the customer
  Future<List<OrderResponse>?> getAllOrders() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/customer/orders',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null && data is List && data.isNotEmpty) {
          // Return the list of orders
          return data.map((order) => OrderResponse.fromJson(order)).toList();
        }
        return null; // No pending orders
      } else {
        throw Exception(
            'Failed to get recent pending orders: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage = e.response?.data['message'] ??
            'Failed to get recent pending orders';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting recent pending orders: $e');
    }
  }

  /// Update an existing customer order
  Future<OrderResponse> updateCustomerOrder(String orderId, Order order) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.patch(
        '$_baseUrl/customer/orders/$orderId',
        data: order.toJson(),
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Check if the response has a 'data' field (wrapped response)
        final orderData = response.data['data'] ?? response.data;
        print('Order updated successfully: ${orderData.toString()}');
        print('Order ID from _id: ${orderData['_id']}');
        print('Order ID from id: ${orderData['id']}');
        return OrderResponse.fromJson(orderData);
      } else {
        throw Exception('Failed to update order: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage =
            e.response?.data['message'] ?? 'Failed to update order';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error updating order: $e');
    }
  }

  /// Get available payment methods for a store
  Future<List<PaymentMethodOption>> getStorePaymentMethods(
      String storeId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/payments/stores/$storeId/methods',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data
            .map((method) => PaymentMethodOption.fromJson(method))
            .toList();
      } else {
        throw Exception(
            'Failed to get payment methods: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final errorMessage =
            e.response?.data['message'] ?? 'Failed to get payment methods';
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting payment methods: $e');
    }
  }
}
