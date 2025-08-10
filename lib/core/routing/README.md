# Enhanced App Router for Web and Mobile

This routing system has been optimized to work seamlessly across both web and mobile platforms using Flutter's GoRouter package.

## Features

### 🌐 Platform-Aware Routing
- **Web**: Direct URL navigation, no splash screen, better SEO
- **Mobile**: Traditional splash screen flow, deep linking support
- **Responsive**: Adapts navigation UI based on screen size

### 🎯 Type-Safe Navigation
- Named routes with constants
- Type-safe parameter passing
- Route validation and error handling

### 📱 Responsive Layout
- Automatic sidebar/drawer switching
- Platform-appropriate transitions
- Responsive grid layouts

## File Structure

```
lib/core/
├── routing/
│   ├── app_router.dart           # Main router configuration
│   ├── route_utils.dart          # Routing utilities and constants
│   └── navigation_extensions.dart # Navigation helper extensions
└── layout/
    └── platform_layout_utils.dart # Responsive layout utilities
```

## Usage Examples

### Basic Navigation

```dart
// Navigate to dashboard
context.goNamed('dashboard');

// Navigate with parameters
context.goNamed('orderDetail', pathParameters: {'orderId': '123'});

// Navigate with query parameters
context.goNamed('orders', queryParameters: {'status': 'pending'});
```

### Using Route Constants

```dart
// Instead of hardcoded strings
context.go('/dashboard');

// Use constants
context.go(AppRoutes.dashboard);

// Or named navigation (preferred)
context.goNamed('dashboard');
```

### Type-Safe Parameters

```dart
// Navigate to order detail
context.goNamed('orderDetail', 
  pathParameters: RouteParams.orderDetail('order-123'));

// Navigate with query filters
context.goNamed('orders', 
  queryParameters: QueryParams.withFilter(
    search: 'pizza',
    status: 'pending',
    page: 1,
  ));
```

### Responsive Layout

```dart
// Check platform and layout
if (context.shouldShowSidebar) {
  // Show sidebar navigation
} else if (context.shouldShowBottomNav) {
  // Show bottom navigation
}

// Use responsive widgets
ResponsiveLayout(
  mobile: MobileView(),
  tablet: TabletView(),
  desktop: DesktopView(),
)
```

## Route Configuration

### Available Routes

- `/` - Splash page (mobile only)
- `/login` - Login page
- `/dashboard` - Main dashboard
- `/menu` - Menu listing
- `/menu/category/:categoryId` - Menu category detail
- `/orders` - Orders listing  
- `/orders/:orderId` - Order detail
- `/profile` - User profile
- `/settings` - Settings page
- `/settings/account` - Account settings
- `/settings/notifications` - Notification settings

### Authentication Guards

The router automatically handles authentication:

- **Web**: Redirects unauthenticated users to `/login`
- **Mobile**: Shows splash screen, then login if needed
- **Protected routes**: All routes except `/` and `/login` require authentication

## Platform Differences

### Web Behavior
- No splash screen (direct to login/dashboard)
- URL bar integration
- Breadcrumb navigation
- SEO-friendly page titles
- Mouse hover tooltips
- Faster transitions (200ms)

### Mobile Behavior  
- Splash screen on app start
- Deep linking support
- Touch-optimized navigation
- Bottom navigation for small screens
- Drawer navigation for medium screens
- Standard mobile transitions (300ms)

## Customization

### Adding New Routes

1. Add route constant to `AppRoutes`:
```dart
static const String newRoute = '/new-route';
```

2. Add route to router configuration:
```dart
GoRoute(
  path: AppRoutes.newRoute,
  name: 'newRoute',
  pageBuilder: (context, state) => AppRouteUtils.getPageTransition(
    state,
    const NewPage(),
    name: 'newRoute',
  ),
),
```

3. Update route utilities if needed:
```dart
// Add to breadcrumbs
case 'new-route':
  breadcrumbs.add('New Route');
  break;

// Add to page titles  
// Add to requiresAuth if protected
```

### Customizing Layout

Modify `PlatformLayoutUtils` to change:
- Breakpoints for responsive design
- Sidebar widths and behavior
- Padding and spacing
- Animation durations

### Authentication Integration

Update `_checkAuthenticationStatus()` in `app_router.dart`:

```dart
bool _checkAuthenticationStatus(Ref ref) {
  // Get auth state from your auth provider
  final authState = ref.read(authProvider);
  return authState.isAuthenticated;
}
```

## Best Practices

1. **Always use named navigation** for better maintainability
2. **Use route constants** instead of hardcoded strings  
3. **Leverage type-safe parameters** for complex navigation
4. **Test on both web and mobile** to ensure proper behavior
5. **Use responsive utilities** for platform-appropriate UI

## Testing Navigation

```dart
// Test route navigation
testWidgets('should navigate to dashboard', (tester) async {
  final router = GoRouter(routes: [...]);
  
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
    ),
  );
  
  // Test navigation
  router.goNamed('dashboard');
  await tester.pumpAndSettle();
  
  expect(find.byKey(const ValueKey('dashboard')), findsOneWidget);
});
```

## SEO Considerations (Web)

The router automatically provides:
- Dynamic page titles based on current route
- Breadcrumb navigation for better UX
- Proper URL structure for search engines
- Meta tags support (can be extended)

## Performance

- **Web**: No-transition pages for faster navigation
- **Mobile**: Material page transitions for native feel
- **Lazy loading**: Routes are only built when visited
- **Minimal rebuilds**: Uses efficient state management
