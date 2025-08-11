# Facebook Login Setup Guide

## 1. Facebook App Configuration

### Create Facebook App
1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create a new app
3. Add "Facebook Login" product to your app
4. Get your App ID and App Secret

### Configure Valid OAuth Redirect URIs
Add the following URIs in your Facebook app settings:
- For web: `https://your-domain.com`
- For Android: No special configuration needed
- For iOS: `fb{your-app-id}://authorize`

## 2. Update Configuration Files

### Android Configuration
Update the following values in `android/app/src/main/res/values/strings.xml`:
```xml
<string name="facebook_app_id">YOUR_ACTUAL_FACEBOOK_APP_ID</string>
<string name="fb_login_protocol_scheme">fbYOUR_ACTUAL_FACEBOOK_APP_ID</string>
<string name="facebook_client_token">YOUR_ACTUAL_FACEBOOK_CLIENT_TOKEN</string>
```

### Web Configuration
Update `web/index.html`:
```html
<meta property="fb:app_id" content="YOUR_ACTUAL_FACEBOOK_APP_ID" />
```

And in the JavaScript section:
```javascript
FB.init({
  appId: 'YOUR_ACTUAL_FACEBOOK_APP_ID',
  cookie: true,
  xfbml: true,
  version: 'v18.0'
});
```

### iOS Configuration
Add to `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>fblogin</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>fbYOUR_ACTUAL_FACEBOOK_APP_ID</string>
    </array>
  </dict>
</array>
<key>FacebookAppID</key>
<string>YOUR_ACTUAL_FACEBOOK_APP_ID</string>
<key>FacebookClientToken</key>
<string>YOUR_ACTUAL_FACEBOOK_CLIENT_TOKEN</string>
<key>FacebookDisplayName</key>
<string>Pika - ESBI Delivery</string>
```

## 3. Firebase Configuration

### Enable Facebook Authentication
1. Go to Firebase Console
2. Navigate to Authentication > Sign-in method
3. Enable Facebook provider
4. Add your Facebook App ID and App Secret
5. Copy the OAuth redirect URI and add it to your Facebook app settings

## 4. Testing

### Web Testing
- Facebook login works in all browsers including Safari
- Uses dialog-only mode for better compatibility

### Mobile Testing
- Android: Uses native Facebook app if available, fallback to web
- iOS: Uses native Facebook app if available, fallback to web

## 5. Security Notes

1. Never commit real Facebook App IDs and secrets to version control
2. Use environment variables for production
3. Configure proper domains in Facebook app settings
4. Test logout functionality thoroughly
5. Handle edge cases like user cancellation

## 6. Troubleshooting

### Common Issues
1. **Invalid app configuration**: Verify all IDs match exactly
2. **OAuth redirect mismatch**: Check Facebook app settings
3. **Web login fails**: Verify domain is added to Facebook app
4. **Mobile login fails**: Check bundle IDs and URL schemes

### Debug Steps
1. Enable debug logging in Flutter Facebook Auth
2. Check Firebase Authentication logs
3. Verify network connectivity
4. Test with different Facebook accounts
