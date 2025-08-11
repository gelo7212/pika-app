# Facebook Login Setup Guide

This guide helps you configure Facebook Login for your Flutter app with Firebase Authentication.

## 1. Facebook Developer Setup

### Create Facebook App
1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Click "Create App" 
3. Choose "Consumer" as app type
4. Fill in app details:
   - App Name: "Pika - ESBI Delivery"
   - App Contact Email: your-email@domain.com

### Configure Facebook Login
1. In your Facebook app dashboard, go to "Add Products"
2. Find "Facebook Login" and click "Set Up"
3. Choose "Web" platform
4. Add your site URL: `https://your-domain.com` (for production)
5. For development, add: `http://localhost:3000` and `http://127.0.0.1:3000`

### Get App ID
1. In Facebook app dashboard, go to "Settings" > "Basic"
2. Copy your "App ID" (it looks like: 1234567890123456)
3. Copy your "App Secret" (for server-side if needed)

## 2. Flutter Configuration

### Update Facebook App ID
Replace the placeholder App ID in these files:

#### web/index.html
```html
<!-- Line 38: Update meta tag -->
<meta property="fb:app_id" content="YOUR_ACTUAL_FACEBOOK_APP_ID" />

<!-- Line 85: Update initialization -->
appId: 'YOUR_ACTUAL_FACEBOOK_APP_ID',
```

#### android/app/src/main/res/values/strings.xml
```xml
<string name="facebook_app_id">YOUR_ACTUAL_FACEBOOK_APP_ID</string>
<string name="fb_login_protocol_scheme">fbYOUR_ACTUAL_FACEBOOK_APP_ID</string>
```

#### ios/Runner/Info.plist
Add these entries:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>fbauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fbYOUR_ACTUAL_FACEBOOK_APP_ID</string>
        </array>
    </dict>
</array>
<key>FacebookAppID</key>
<string>YOUR_ACTUAL_FACEBOOK_APP_ID</string>
<key>FacebookDisplayName</key>
<string>Pika - ESBI Delivery</string>
```

## 3. Firebase Console Setup

### Enable Facebook Provider
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to "Authentication" > "Sign-in method"
4. Click on "Facebook"
5. Toggle "Enable"
6. Enter your Facebook App ID and App Secret
7. Copy the OAuth redirect URI
8. Click "Save"

### Add OAuth Redirect URI to Facebook
1. Go back to Facebook Developer console
2. Go to "Facebook Login" > "Settings"
3. Add the Firebase OAuth redirect URI to "Valid OAuth Redirect URIs"
4. Save changes

## 4. Domain Verification

### For Production
1. In Facebook app settings, add your production domain
2. Verify domain ownership if required
3. Update CORS settings if needed

### For Development
- `localhost:3000`
- `127.0.0.1:3000`
- Your local development server URL

## 5. Testing

### Web Testing
1. Serve your Flutter web app: `flutter run -d chrome --web-port 3000`
2. Navigate to login page
3. Click "Continue with Facebook"
4. Should open Facebook login dialog
5. After login, should redirect back to your app

### Mobile Testing
1. Run on device: `flutter run`
2. Click Facebook login button
3. Should open Facebook app or browser
4. Complete login flow

## 6. Troubleshooting

### Common Issues

#### "window.FB is undefined"
- Check Facebook SDK is loading in web/index.html
- Verify App ID is correctly set
- Check browser console for loading errors

#### "Invalid App ID"
- Double-check App ID in all configuration files
- Ensure App ID matches exactly (no extra spaces)
- Verify App ID is active in Facebook Developer console

#### "OAuth redirect URI mismatch"
- Add all possible redirect URIs in Facebook settings
- Include both development and production URLs
- Check Firebase Auth domain configuration

#### "App not setup for Facebook Login"
- Verify Facebook Login is added as a product
- Check app is not in development mode restrictions
- Ensure app review is complete if required

### Debug Steps
1. Check browser console for JavaScript errors
2. Verify network requests to Facebook APIs
3. Test Facebook SDK initialization
4. Check Firebase Auth configuration
5. Verify all configuration files have correct App ID

## 7. Production Deployment

### Before Going Live
1. Submit Facebook app for review if required
2. Update app from "Development" to "Live" mode
3. Add production domains to Facebook settings
4. Test on production environment
5. Monitor authentication flows

### Security Notes
- Never expose App Secret in client-side code
- Use HTTPS for all production URLs
- Regularly review Facebook app permissions
- Monitor authentication logs for suspicious activity

## 8. Example App IDs (Replace These!)

The current configuration uses placeholder IDs:
- Facebook App ID: `1234567890123456` (REPLACE THIS!)
- This is just an example - get your real App ID from Facebook Developer console

Remember to replace all instances of placeholder IDs with your actual Facebook App ID!
