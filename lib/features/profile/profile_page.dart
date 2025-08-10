import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/user_profile_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
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
          children: [
            // Profile Header
            _buildProfileHeader(context, ref),

            const SizedBox(height: 24),

            // Profile Options
            _buildProfileOptions(context),

            const SizedBox(height: 24),

            // Account Actions
            _buildAccountActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: userProfileAsync.when(
        data: (userProfile) => Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                _getInitials(_getDisplayName(userProfile.name, userProfile.email)),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getDisplayName(userProfile.name, userProfile.email),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              userProfile.email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        loading: () => Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor,
              child: const CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
        error: (error, stackTrace) => Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(
                Icons.error,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please try again',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.refresh(userProfileProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    // If name is empty, extract from email
    String displayName = name.trim();
    if (displayName.isEmpty) {
      // Try to extract name from email (part before @)
      displayName = "User"; // Fallback
    }
    
    final words = displayName.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0].substring(0, 1).toUpperCase();
    return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'.toUpperCase();
  }

  String _getDisplayName(String name, String email) {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    
    // Extract name from email if name is empty
    final emailParts = email.split('@');
    if (emailParts.isNotEmpty && emailParts[0].isNotEmpty) {
      // Capitalize first letter
      final emailName = emailParts[0];
      return emailName[0].toUpperCase() + emailName.substring(1);
    }
    
    return 'User'; // Final fallback
  }

  Widget _buildProfileOptions(BuildContext context) {
    final options = [
      {
        'title': 'Edit Profile',
        'subtitle': 'Update your personal information',
        'icon': Icons.person_outline,
        'onTap': () => _showComingSoon(context, 'Edit Profile'),
      },
      {
        'title': 'Delivery Addresses',
        'subtitle': 'Manage your saved addresses',
        'icon': Icons.location_on_outlined,
        'onTap': () => context.go('/addresses'),
      },
      {
        'title': 'Payment Methods',
        'subtitle': 'Manage your payment options',
        'icon': Icons.payment_outlined,
        'onTap': () => _showComingSoon(context, 'Payment Methods'),
      },
      {
        'title': 'Notifications',
        'subtitle': 'Configure your notification preferences',
        'icon': Icons.notifications_outlined,
        'onTap': () => _showComingSoon(context, 'Notifications'),
      },
      {
        'title': 'Order Preferences',
        'subtitle': 'Set your default order settings',
        'icon': Icons.tune_outlined,
        'onTap': () => _showComingSoon(context, 'Order Preferences'),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...options.map((option) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(option['icon'] as IconData),
              title: Text(
                option['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(option['subtitle'] as String),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: option['onTap'] as VoidCallback,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAccountActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // Action Buttons
        Card(
          child: ListTile(
            leading: Icon(Icons.help_outline, color: Colors.blue[600]),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.go('/support'),
          ),
        ),

        Card(
          child: ListTile(
            leading: Icon(Icons.info_outline, color: Colors.green[600]),
            title: const Text('About'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showAboutDialog(context),
          ),
        ),

        const SizedBox(height: 16),

        // Logout Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature feature coming soon!')),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Pika - ESBI Delivery'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('A modern food ordering application built with Flutter.'),
            SizedBox(height: 8),
            Text('© 2024 Pika - ESBI Delivery. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content:
            const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
