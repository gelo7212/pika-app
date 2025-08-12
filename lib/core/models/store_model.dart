class Store {
  final String id;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String email;
  final bool isActive;
  final StoreLocation location;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? isClosed;
  final List<StoreHours>? hours;
  final String? contactNumber;

  const Store({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    required this.email,
    required this.isActive,
    required this.location,
    this.createdAt,
    this.updatedAt,
    this.isClosed,
    this.hours,
    this.contactNumber,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      isActive: json['isActive'] ?? true,
      location: StoreLocation.fromJson(json['coordinates'] ?? json['location'] ?? {}),
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isClosed: json['isClosed'] ?? false,
      hours: json['hours'] != null 
          ? (json['hours'] as List).map((h) => StoreHours.fromJson(h)).toList()
          : null,
      contactNumber: json['contactNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'email': email,
      'isActive': isActive,
      'location': location.toJson(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'isClosed': isClosed ?? false,
      if (hours != null) 'hours': hours!.map((h) => h.toJson()).toList(),
      if (contactNumber != null) 'contactNumber': contactNumber,
    };
  }

  // Method to check if store is currently open
  bool get isCurrentlyOpen {
    if (isClosed == true) return false;
    if (hours == null || hours!.isEmpty) return true; // Default to open if no hours specified

    final now = DateTime.now();
    final currentDay = now.weekday % 7; // Convert to 0=Sunday format
    final currentMinutes = now.hour * 60 + now.minute;

    final todayHours = hours!.firstWhere(
      (h) => h.day == currentDay,
      orElse: () => const StoreHours(day: -1, intervals: []),
    );

    if (todayHours.day == -1 || todayHours.intervals.isEmpty) {
      return false; // Closed if no hours for today
    }

    // Check if current time falls within any interval
    return todayHours.intervals.any((interval) =>
        currentMinutes >= interval.startM && currentMinutes <= interval.endM);
  }

  // Method to get formatted hours for display
  String getFormattedHours() {
    if (hours == null || hours!.isEmpty) return 'Hours not available';

    final buffer = StringBuffer();
    for (final hour in hours!) {
      if (hour.intervals.isEmpty) {
        buffer.writeln('${hour.dayName}: Closed');
      } else {
        final intervals = hour.intervals.map((i) => i.timeRange).join(', ');
        buffer.writeln('${hour.dayName}: $intervals');
      }
    }
    return buffer.toString().trim();
  }
}

class StoreLocation {
  final String type;
  final List<double> coordinates;

  const StoreLocation({
    required this.type,
    required this.coordinates,
  });

  double get longitude => coordinates.isNotEmpty ? coordinates[0] : 0.0;
  double get latitude => coordinates.length > 1 ? coordinates[1] : 0.0;

  factory StoreLocation.fromJson(Map<String, dynamic> json) {
    return StoreLocation(
      type: json['type'] ?? 'Point',
      coordinates: (json['coordinates'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [0.0, 0.0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
    };
  }
}

class StoreHours {
  final int day; // 0 = Sunday, 1 = Monday, etc.
  final List<HourInterval> intervals;

  const StoreHours({
    required this.day,
    required this.intervals,
  });

  factory StoreHours.fromJson(Map<String, dynamic> json) {
    return StoreHours(
      day: json['day'] ?? 0,
      intervals: (json['intervals'] as List<dynamic>?)
              ?.map((i) => HourInterval.fromJson(i))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'intervals': intervals.map((i) => i.toJson()).toList(),
    };
  }

  // Helper method to get day name
  String get dayName {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[day % 7];
  }

  // Helper method to check if store is open on this day
  bool get isOpen => intervals.isNotEmpty;
}

class HourInterval {
  final int startM; // Start time in minutes from midnight
  final int endM;   // End time in minutes from midnight

  const HourInterval({
    required this.startM,
    required this.endM,
  });

  factory HourInterval.fromJson(Map<String, dynamic> json) {
    return HourInterval(
      startM: json['startM'] ?? 0,
      endM: json['endM'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startM': startM,
      'endM': endM,
    };
  }

  // Helper method to format time
  String formatTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    return '${displayHours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')} $period';
  }

  // Get formatted time range
  String get timeRange => '${formatTime(startM)} - ${formatTime(endM)}';
}
