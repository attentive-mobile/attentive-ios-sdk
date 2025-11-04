# Testing Guide: New V2 AddToCart Event

This guide will help you test the new AddToCart event format in the iOS simulator.

## Prerequisites

- Xcode installed
- iOS Simulator available
- Network debugging tool (Charles Proxy, Proxyman, or Xcode Network Instruments)

## Option 1: Using Xcode to Run the App

### Step 1: Open the Bonni App in Xcode

```bash
open /Users/adelag/workspace/attentive-ios-sdk/Bonni/Bonni.xcodeproj
```

### Step 2: Select Simulator

1. In Xcode, at the top toolbar, select a simulator (e.g., "iPhone 16")
2. Make sure the scheme is set to "AttentiveExample"

### Step 3: Build and Run

1. Press `Cmd + R` or click the Play button to build and run the app
2. Wait for the app to launch in the simulator

### Step 4: Navigate to a Product

1. Once the app launches, you'll see the "All Products" screen
2. Tap on any product to open the Product Detail screen

### Step 5: Test the V2 AddToCart Event

You'll see **two buttons** on the Product Detail screen:

1. **"Add to Cart (Legacy)"** (Blue button)
   - This sends the old format event
   - Uses the legacy `/e` endpoint

2. **"Add to Cart (V2 - New Format)"** (Green button) ⭐ **NEW**
   - This sends the new format matching Android SDK
   - Uses the new `/mobile` endpoint
   - Sends form-urlencoded data with JSON in the `d` parameter

### Step 6: Tap the Green Button

1. Tap **"Add to Cart (V2 - New Format)"** (green button)
2. You should see a toast message: "✅ V2 AddToCart event sent!"

---

## Option 2: Using Command Line to Run the App

### Build and Launch in Simulator

```bash
# Build the app
xcodebuild -project /Users/adelag/workspace/attentive-ios-sdk/Bonni/Bonni.xcodeproj \
  -scheme AttentiveExample \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
  build

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "AttentiveExample.app" | head -1)

# Launch simulator
open -a Simulator

# Install and launch the app
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.attentive.bonni
```

---

## Verifying the Network Request

### Method 1: Using Xcode Network Instruments

1. In Xcode, go to **Product > Profile** (or press `Cmd + I`)
2. Select **Network** instrument
3. Click Record
4. In the app, tap the **"Add to Cart (V2 - New Format)"** button
5. Look for a request to `https://events.attentivemobile.com/mobile`

### Method 2: Using Charles Proxy or Proxyman

1. Configure your Mac to use Charles Proxy/Proxyman
2. Configure the simulator to use the proxy:
   ```bash
   # Get your Mac's IP
   ipconfig getifaddr en0

   # Configure simulator proxy (example with Charles on port 8888)
   # Open Settings app in simulator > Wi-Fi > Configure Proxy > Manual
   # Server: your-mac-ip
   # Port: 8888
   ```
3. In the app, tap the **"Add to Cart (V2 - New Format)"** button
4. Look for the request in Charles/Proxyman

### Method 3: View Logs in Xcode Console

1. In Xcode, open the Console (View > Debug Area > Show Debug Area)
2. Tap the **"Add to Cart (V2 - New Format)"** button
3. Look for log messages like:
   ```
   ---- Sending /mobile Event ----
   URL: https://events.attentivemobile.com/mobile
   JSON Payload: {"visitorId":"...","eventType":"AddToCart",...}
   Form Body: d=%7B%22visitorId%22%3A...
   ```

---

## Expected Request Format

### URL
```
POST https://events.attentivemobile.com/mobile
```

### Headers
```
Content-Type: application/x-www-form-urlencoded; charset=utf-8
x-datadog-sampling-priority: 1
```

### Body (URL-encoded)
```
d=%7B%22visitorId%22%3A%22...%22%2C%22version%22%3A%22...%22%2C...%7D
```

### Body (Decoded JSON)
```json
{
  "visitorId": "d486315e97d44d6da3cfad1407b23247",
  "version": "2.0.5",
  "attentiveDomain": "games",
  "eventType": "AddToCart",
  "timestamp": "2025-11-03T20:40:08.981Z",
  "identifiers": {
    "encryptedEmail": "ZnNhZmZzQGFzYWRmZGwuY29t",
    "encryptedPhone": null,
    "otherIdentifiers": null
  },
  "eventMetadata": {
    "eventType": "AddToCart",
    "product": {
      "productId": "productId1",
      "variantId": "variantId1",
      "name": "The Stick",
      "variantName": null,
      "imageUrl": null,
      "categories": null,
      "price": "20.00",
      "quantity": 1,
      "productUrl": null
    },
    "currency": "USD"
  },
  "sourceType": "mobile",
  "referrer": "",
  "locationHref": null,
  "genericMetadata": null,
  "appSdk": "iOS"
}
```

---

## Key Differences from Legacy Format

### Legacy Format (Blue Button)
- **Endpoint**: `https://events.attentivemobile.com/e?...`
- **Method**: GET with query parameters
- **Event Type**: `"c"` (abbreviated)
- **Format**: Query string parameters

### New V2 Format (Green Button) ✅
- **Endpoint**: `https://events.attentivemobile.com/mobile`
- **Method**: POST with form-urlencoded body
- **Event Type**: `"AddToCart"` (full string)
- **Format**: JSON encoded as form data parameter `d`
- **Null Handling**: Explicit `null` values for optional fields
- **Matches Android SDK**: Exact same payload format

---

## Troubleshooting

### App doesn't build
```bash
# Clean and rebuild
xcodebuild clean -project /Users/adelag/workspace/attentive-ios-sdk/Bonni/Bonni.xcodeproj -scheme AttentiveExample

# Rebuild
xcodebuild -project /Users/adelag/workspace/attentive-ios-sdk/Bonni/Bonni.xcodeproj \
  -scheme AttentiveExample \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
  build
```

### Green button doesn't show
- Make sure you rebuilt the app after making the changes
- Pull to refresh or restart the app

### No network request visible
- Check that you're tapping the **green button** (V2), not the blue button (Legacy)
- Ensure your network debugging tool is properly configured
- Check Xcode console for log messages

### "SDK not initialized" error
- This shouldn't happen as the SDK is initialized in AppDelegate
- Check the Xcode console for SDK initialization logs

---

## Testing Other Events

The refactored architecture also supports:

### ProductView Event
- Automatically sent when opening a Product Detail screen
- Uses the new V2 format via `tracker.recordProductView()`

### Purchase Event
You can test this programmatically by calling:
```swift
let tracker = ATTNEventTracker.sharedInstance()
tracker?.recordPurchase(
    orderId: "order123",
    currency: "USD",
    orderTotal: "63.00",
    cart: cart,
    products: [product1, product2]
)
```

---

## Next Steps

1. Test the V2 AddToCart event in simulator
2. Verify the network request matches the Android SDK format
3. Compare with the Android SDK payload (provided in original request)
4. Test in different scenarios (with/without email, with/without phone)
5. Test with different product configurations

## Questions?

If you encounter any issues, check:
- Xcode Console logs
- Build errors
- Network request details
- This guide's troubleshooting section
