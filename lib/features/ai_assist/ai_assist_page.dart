import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/services/ai_assist_service.dart';
import '../../core/routing/navigation_extensions.dart';

class AIAssistPage extends ConsumerStatefulWidget {
  const AIAssistPage({super.key});

  @override
  ConsumerState<AIAssistPage> createState() => _AIAssistPageState();
}

class _AIAssistPageState extends ConsumerState<AIAssistPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<AIMessage> _messages = [];
  bool _isTyping = false;
  Map<String, dynamic>? _conversationState;

  @override
  void initState() {
    super.initState();
    _initializeConversation();
  }

  void _initializeConversation() {
    setState(() {
      _messages = [
        AIMessage(
          content: "Hi! I'm your AI coffee assistant 🤖☕\n\nI can help you find the perfect drink for your mood today! What are you in the mood for?",
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: [
            "Coffee",
            "Frappe", 
            "Refresher",
            "Matcha",
            "Something sweet",
            "Energy boost"
          ],
        ),
      ];
      // Initialize conversation state as null for first request
      _conversationState = null;
    });
    
    print('Conversation initialized with null state');
  }

  void _debugConversationState() {
    print('Current conversation state: $_conversationState');
    if (_conversationState != null) {
      print('Phase: ${_conversationState!['conversationPhase']}');
      print('Last Intent: ${_conversationState!['lastIntent']}');
      print('User Preferences: ${_conversationState!['userPreferences']}');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    print('Sending message: "$message"');
    _debugConversationState();

    setState(() {
      _messages.add(AIMessage(
        content: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Call the AI API
      await _callAIApi(message);
    } catch (e) {
      // Handle error with fallback response
      setState(() {
        _messages.add(AIMessage(
          content: "I'm sorry, I'm having trouble connecting right now. Please try again in a moment. 😔",
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: ["Try again", "Browse menu"],
        ));
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _callAIApi(String message) async {
    try {
      final aiService = AIAssistService();
      
      // Validate conversation state before sending
      if (!AIAssistService.isValidConversationState(_conversationState)) {
        print('Warning: Invalid conversation state detected, resetting...');
        _conversationState = null;
      }
      
      final data = await aiService.sendChatMessage(
        message: message,
        conversationState: _conversationState,
      );

      // Update conversation state for next request
      final newConversationState = data['conversationState'];
      if (newConversationState != null) {
        _conversationState = newConversationState;
        print('Updated conversation state: ${_conversationState?['conversationPhase']}');
      } else {
        print('Warning: No conversation state returned from API');
      }
      
      // Convert API recommendations to local format
      final List<APIProductRecommendation> apiRecommendations = [];
      if (data['recommendations'] != null) {
        for (final rec in data['recommendations']) {
          apiRecommendations.add(APIProductRecommendation.fromJson(rec));
        }
      }
      
      // Extract suggestions from API response
      final List<String> suggestions = [];
      if (data['suggestedFollowUps'] != null) {
        suggestions.addAll(List<String>.from(data['suggestedFollowUps']));
      }
      suggestions.addAll(["Order now", "Tell me more", "Something else"]);
      
      setState(() {
        _messages.add(AIMessage(
          content: data['message'] ?? "I'm here to help you find the perfect drink!",
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: suggestions,
          apiRecommendations: apiRecommendations,
        ));
        _isTyping = false;
      });
    } catch (e) {
      print('AI API Error: $e');
      // Fallback to mock response
      _handleFallbackResponse(message);
    }
    
    _scrollToBottom();
  }

  void _handleFallbackResponse(String userMessage) {
    // Fallback mock response when API fails
    final lowerMessage = userMessage.toLowerCase();
    String response = "I'd love to help you find something perfect! What are you in the mood for today?";
    List<String> suggestions = [
      "Coffee",
      "Something sweet", 
      "Cold drink",
      "Hot drink",
      "Energizing",
      "Refreshing"
    ];

    if (lowerMessage.contains('coffee')) {
      response = "Great choice! ☕ Let me show you some coffee options:";
      suggestions = ["Balanced sweet and coffee", "Strong and bold", "Mild and smooth"];
    } else if (lowerMessage.contains('matcha')) {
      response = "Matcha is a wonderful choice! 🍵 Here are our matcha selections:";
      suggestions = ["Order now", "Coffee instead", "Tell me more"];
    }

    setState(() {
      _messages.add(AIMessage(
        content: response,
        isUser: false,
        timestamp: DateTime.now(),
        suggestions: suggestions,
      ));
      _isTyping = false;
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.safeGoBack(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  _isTyping ? 'typing...' : 'Online',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isTyping ? Colors.orange : Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isTyping) _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AIMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isUser 
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: message.isUser
                      ? Text(
                          message.content,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            strong: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                if (message.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...message.recommendations.map((rec) => _buildRecommendationCard(rec)),
                ],
                if (message.apiRecommendations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildAPIRecommendationsCarousel(message.apiRecommendations),
                ],
                if (message.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.suggestions.map((suggestion) => 
                      _buildSuggestionChip(suggestion)
                    ).toList(),
                  ),
                ],
              ],
            ),
          ),
          if (message.isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(ProductRecommendation recommendation) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  recommendation.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (recommendation.isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Popular',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            recommendation.description,
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                recommendation.price,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              ElevatedButton(
                onPressed: () => _orderProduct(recommendation),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Order Now',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAPIRecommendationsCarousel(List<APIProductRecommendation> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Recommended for you',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              final recommendation = recommendations[index];
              return _buildAPIRecommendationCard(recommendation);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAPIRecommendationCard(APIProductRecommendation recommendation) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder or actual image
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: recommendation.image != null && recommendation.image!.isNotEmpty
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      recommendation.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                    ),
                  )
                : _buildImagePlaceholder(),
          ),
          // Product details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recommendation.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recommendation.isPopular)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation.categoryText,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 11,
                    ),
                  ),
                  if (recommendation.size.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      recommendation.size,
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        recommendation.formattedPrice,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _orderAPIProduct(recommendation),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Order',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Icon(
        Icons.local_cafe_outlined,
        color: Colors.grey[400],
        size: 32,
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return GestureDetector(
      onTap: () => _sendMessage(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Text(
          suggestion,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF333333),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
              size: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 14,
                    ),
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendMessage(_messageController.text),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _orderProduct(ProductRecommendation recommendation) {
    // Show a confirmation message and navigate to menu
    _sendMessage("I'd like to order the ${recommendation.name}");
    
    // Add AI response for order confirmation
    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() {
        _messages.add(AIMessage(
          content: "Great choice! I'm taking you to the menu where you can customize your ${recommendation.name} and add it to your cart. 🛒",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      
      // Navigate to menu with the specific product ID
      Future.delayed(const Duration(milliseconds: 1500), () {
        context.go('/menu?item=${recommendation.globalId}');
      });
    });
  }

  void _orderAPIProduct(APIProductRecommendation recommendation) {
    // Show a confirmation message and navigate to menu
    _sendMessage("I'd like to order the ${recommendation.name}");
    
    // Add AI response for order confirmation
    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() {
        _messages.add(AIMessage(
          content: "Excellent choice! The ${recommendation.name} (${recommendation.size}) is a great pick! 🎉\n\nI'm taking you to the menu where you can customize your order and add it to your cart.",
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: ["Customize order", "Add to cart", "Browse similar"],
        ));
      });
      
      // Navigate to menu with the specific product ID
      Future.delayed(const Duration(milliseconds: 1500), () {
        context.go('/menu?item=${recommendation.id}');
      });
    });
  }
}

class AIMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestions;
  final List<ProductRecommendation> recommendations;
  final List<APIProductRecommendation> apiRecommendations;

  AIMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.suggestions = const [],
    this.recommendations = const [],
    this.apiRecommendations = const [],
  });
}

class ProductRecommendation {
  final String globalId;
  final String name;
  final String description;
  final String category;
  final String price;
  final bool isPopular;

  ProductRecommendation({
    required this.globalId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isPopular,
  });
}

class APIProductRecommendation {
  final String id;
  final String name;
  final String? description;
  final Map<String, dynamic> category;
  final double inHousePrice;
  final double grabPrice;
  final String size;
  final String? image;
  final bool availableForSale;
  final bool isPopular;

  APIProductRecommendation({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.inHousePrice,
    required this.grabPrice,
    required this.size,
    this.image,
    required this.availableForSale,
    this.isPopular = false,
  });

  factory APIProductRecommendation.fromJson(Map<String, dynamic> json) {
    return APIProductRecommendation(
      id: json['globalId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      category: json['category'] ?? {},
      inHousePrice: (json['inHousePrice'] ?? json['price'] ?? 0).toDouble(),
      grabPrice: (json['grabPrice'] ?? 0).toDouble(),
      size: json['size'] ?? '',
      image: json['image'],
      availableForSale: json['availableForSale'] ?? true,
      isPopular: json['isPopular'] ?? false,
    );
  }

  String get formattedPrice {
    final price = inHousePrice > 0 ? inHousePrice : grabPrice;
    return '₱${price.toStringAsFixed(0)}';
  }

  String get categoryText {
    final main = category['main'] ?? '';
    final sub = category['sub'] ?? '';
    return sub.isNotEmpty ? sub : main;
  }
}
