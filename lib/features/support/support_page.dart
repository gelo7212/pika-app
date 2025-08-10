import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Options
            const Text(
              'Contact Us',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildContactOptions(context),
            
            const SizedBox(height: 32),
            
            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFAQSection(),
            
            const SizedBox(height: 32),
            
            // App Info
            const Text(
              'App Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAppInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOptions(BuildContext context) {
    final contactOptions = [
      {
        'title': 'Call Us',
        'subtitle': '',
        'icon': Icons.phone,
        'color': Colors.green,
        'onTap': () => _launchPhone('+15551234567'),
      },
      {
        'title': 'Email Support',
        'subtitle': 'esbibrew@outlook.com',
        'icon': Icons.email,
        'color': Colors.blue,
        'onTap': () => _launchEmail('esbibew@outlook.com'),
      },
      {
        'title': 'Live Chat',
        'subtitle': 'Available soon',
        'icon': Icons.chat_bubble,
        'color': Colors.purple,
        'onTap': () => _showChatComingSoon(context),
      },
      {
        'title': 'Visit Store',
        'subtitle': 'Crossing Calumpit Poblacion, Bulacan',
        'icon': Icons.location_on,
        'color': Colors.red,
        'onTap': () => _launchMaps(),
      },
    ];

    return Column(
      children: contactOptions.map((option) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (option['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                option['icon'] as IconData,
                color: option['color'] as Color,
              ),
            ),
            title: Text(
              option['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(option['subtitle'] as String),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: option['onTap'] as VoidCallback,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFAQSection() {
    final faqs = [
      {
        'question': 'How do I place an order?',
        'answer': 'You can place an order by browsing our menu, selecting items, and adding them to your cart. Then proceed to checkout.',
      },
      {
        'question': 'What are your delivery hours?',
        'answer': 'We deliver from 11:00 AM to 10:00 PM, Monday through Sunday.',
      },
      {
        'question': 'How can I track my order?',
        'answer': 'Once your order is placed, you can track it in the Order History section of the app.',
      },
      {
        'question': 'What payment methods do you accept?',
        'answer': 'We accept credit cards, debit cards, PayPal, and cash on delivery.',
      },
      {
        'question': 'How do I earn loyalty points?',
        'answer': 'You earn points with every purchase. Check the Loyalty section for more details.',
      },
    ];

    return ExpansionPanelList.radio(
      children: faqs.map((faq) {
        return ExpansionPanelRadio(
          value: faq['question']!,
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(
                faq['question']!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          },
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              faq['answer']!,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Version'),
          subtitle: const Text('1.0.0'),
        ),
        ListTile(
          leading: const Icon(Icons.description),
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showComingSoon(context, 'Terms of Service'),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showComingSoon(context, 'Privacy Policy'),
        ),
        ListTile(
          leading: const Icon(Icons.star_rate),
          title: const Text('Rate This App'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showComingSoon(context, 'App Rating'),
        ),
        ListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: const Text('Send Feedback'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showFeedbackDialog(context),
        ),
      ],
    );
  }

  void _launchPhone(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchEmail(String email) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Customer Support Request',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchMaps() async {
    final Uri uri = Uri.parse('https://maps.app.goo.gl/9LvYAzNaEk9a8xR96');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showChatComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Chat'),
        content: const Text('Live chat feature is coming soon! In the meantime, please contact us via phone or email.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature feature coming soon!')),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We value your feedback! Please let us know how we can improve.'),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your feedback here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
