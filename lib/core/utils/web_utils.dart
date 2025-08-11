// Conditional imports for web utilities
// This file provides a safe way to access web APIs without breaking mobile builds

// Web implementation for web, stub for mobile
import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

export 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';
