import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../interfaces/token_service_interface.dart';
import '../di/service_locator.dart';

class AIAssistService {
  static const String _endpoint = '/ai/chat'; // dont change this path

  /// Sends a chat message to the AI service with conversation state tracking
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    Map<String, dynamic>? conversationState,
  }) async {
    try {
      // Get authentication headers
      final tokenService = serviceLocator<TokenServiceInterface>();
      final tokens = await tokenService.getStoredTokens();
      
      final headers = {
        'Content-Type': 'application/json',
        ...ApiConfig.getDefaultHeaders(),
        if (tokens?.userAccessToken != null) 
          'Authorization': 'Bearer ${tokens!.userAccessToken}',
      };

      // Prepare request body
      final requestBody = {
        'message': message,
        'conversationState': conversationState,
      };

      print('AI API Request: ${json.encode(requestBody)}');

      // Make API call
      final response = await http.post(
        Uri.parse('${ApiConfig.salesUrl}$_endpoint'),
        headers: headers,
        body: json.encode(requestBody),
      );

      print('AI API Response Status: ${response.statusCode}');
      print('AI API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final data = responseData['data'];
          
          // Validate enhanced AI response structure
          if (data['success'] == true) {
            // Validate that conversationState is included in response
            if (data['conversationState'] == null) {
              print('Warning: No conversationState in API response');
            }
            
            // Log enhanced features
            if (data['enhanced'] == true) {
              print('Enhanced AI Assistant enabled');
            }
            if (data['vectorSearchEnabled'] == true) {
              print('Vector search enabled');
            }
            
            return data;
          } else {
            throw Exception('Enhanced AI response success flag is false');
          }
        } else {
          throw Exception('Invalid API response format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        final errorBody = response.body;
        throw Exception('API call failed with status: ${response.statusCode}, body: $errorBody');
      }
    } catch (e) {
      print('AI API Error: $e');
      rethrow;
    }
  }

  /// Helper method to validate conversation state structure
  static bool isValidConversationState(Map<String, dynamic>? state) {
    if (state == null) return true; // null is valid for first request
    
    // Check for expected conversation state structure
    return state.containsKey('conversationPhase') || 
           state.containsKey('lastIntent') || 
           state.containsKey('userPreferences');
  }

  /// Creates a minimal conversation state for testing
  static Map<String, dynamic> createInitialState() {
    return {
      'conversationPhase': 'greeting',
      'lastIntent': '',
      'userPreferences': {},
      'recommendedProducts': [],
      'lastRecommendations': [],
    };
  }
}

class AIResponse {
  final bool success;
  final String message;
  final List<dynamic> recommendations;
  final Map<String, dynamic> conversationState;
  final List<String> suggestedFollowUps;
  final bool needsFollowUp;
  final String? searchContext;
  final bool enhanced;
  final bool vectorSearchEnabled;

  AIResponse({
    required this.success,
    required this.message,
    required this.recommendations,
    required this.conversationState,
    required this.suggestedFollowUps,
    required this.needsFollowUp,
    this.searchContext,
    this.enhanced = false,
    this.vectorSearchEnabled = false,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      recommendations: json['recommendations'] ?? [],
      conversationState: json['conversationState'] ?? {},
      suggestedFollowUps: List<String>.from(json['suggestedFollowUps'] ?? []),
      needsFollowUp: json['needsFollowUp'] ?? false,
      searchContext: json['searchContext'],
      enhanced: json['enhanced'] ?? false,
      vectorSearchEnabled: json['vectorSearchEnabled'] ?? false,
    );
  }
}
