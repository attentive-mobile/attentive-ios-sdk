# iOS SDK Refactoring Summary

## Overview
Successfully refactored the iOS SDK to emit AddToCart (and other) events with the same payload format as the Android SDK, following proper SDK architecture patterns.

## Key Changes

### 1. Architecture Pattern (Following SDK Standards)

**Before:**
```swift
// ❌ Exposed internal details, required passing private properties
sdk.sendNewEvent(
    event: event,
    eventRequest: eventRequest,
    userIdentity: userIdentity  // Private property exposed
)
```

**After:**
```swift
// ✅ Clean API through EventTracker, no internal details exposed
tracker.recordAddToCart(product: product, currency: "USD")
```

### 2. File Changes

#### `Sources/Public/ATTNEventTracker.swift`
Added new public methods that follow the existing pattern:
- `recordAddToCart(product:currency:)` - Records AddToCart events
- `recordProductView(product:currency:)` - Records ProductView events
- `recordPurchase(orderId:currency:orderTotal:cart:products:)` - Records Purchase events

#### `Sources/Helpers/Extension/ATTNSDK+Extension.swift`
Added internal methods that handle event creation and access private properties:
- `sendAddToCartEvent(product:currency:)`
- `sendProductViewEvent(product:currency:)`
- `sendPurchaseEvent(orderId:currency:orderTotal:cart:products:)`
- `sendNewEventInternal(eventType:metadata:)` - Private helper that accesses `userIdentity` and `domain`

#### `Sources/Helpers/Extension/ATTNUserIdentity+Extension.swift`
Added computed properties for base64 encoding:
- `encryptedEmail` - Returns base64 encoded email from identifiers
- `encryptedPhone` - Returns base64 encoded phone from identifiers

#### `Sources/Public/SDK/ATTNSDK.swift`
- Changed `domain` from `private` to `internal` to allow access within the module
- Removed the public `sendNewEvent` method (no longer needed)

#### `Sources/API/ATTNEventTypes.swift`
- Fixed `ATTNEventType` enum to use full strings: `"AddToCart"`, `"ProductView"`, `"Purchase"` (instead of abbreviations)
- Added explicit null encoding for optional fields in `ATTNIdentifiers` and `ATTNProduct`
- Added `ATTNGenericMetadata` struct to match OpenAPI spec
- Added `genericMetadata` field to `ATTNBaseEvent`

#### `Sources/API/ATTNAPI.swift`
- Modified `sendNewEvent` to use `application/x-www-form-urlencoded` content type
- JSON payload is URL-encoded and sent as form data with key `d`
- Added explicit null value handling

#### `Sources/API/ATTNEventRequest.swift`
- Made `ATTNEventRequest` public with `@objc` annotations (required for public API)

#### `Sources/API/ATTNAPIProtocol.swift`
- Added `sendNewEvent` method signature to protocol

## Usage Examples

### Simple AddToCart Event
```swift
// Get the EventTracker instance
guard let tracker = ATTNEventTracker.sharedInstance() else {
    return
}

// Create product
let product = ATTNProduct(
    productId: "productId1",
    variantId: "variantId1",
    name: "The Stick",
    price: "20.00",
    quantity: 1
)

// Record the event - SDK handles all internal details
tracker.recordAddToCart(product: product, currency: "USD")
```

### ProductView Event
```swift
guard let tracker = ATTNEventTracker.sharedInstance() else {
    return
}

let product = ATTNProduct(
    productId: "12345",
    variantId: "12345-A",
    name: "Wireless Controller",
    variantName: "Midnight Edition",
    imageUrl: "https://cdn.store.com/controller.jpg",
    categories: ["Electronics", "Gaming"],
    price: "59.99",
    quantity: 1,
    productUrl: "https://store.com/p/12345"
)

tracker.recordProductView(product: product, currency: "USD")
```

### Purchase Event
```swift
guard let tracker = ATTNEventTracker.sharedInstance() else {
    return
}

let product1 = ATTNProduct(
    productId: "productId1",
    variantId: "variantId1",
    name: "Product 1",
    price: "20.00",
    quantity: 2
)

let product2 = ATTNProduct(
    productId: "productId2",
    variantId: "variantId2",
    name: "Product 2",
    price: "30.00",
    quantity: 1
)

let cart = ATTNCartPayload(
    cartId: "cart123",
    cartTotal: "70.00",
    cartCoupon: "SAVE10",
    cartDiscount: "7.00"
)

tracker.recordPurchase(
    orderId: "order123",
    currency: "USD",
    orderTotal: "63.00",
    cart: cart,
    products: [product1, product2]
)
```

## Payload Format

The iOS SDK now sends payloads that match the Android SDK:

### HTTP Request
```
POST https://events.attentivemobile.com/mobile
Content-Type: application/x-www-form-urlencoded; charset=utf-8

d=%7B%22visitorId%22%3A%22...%22%2C%22version%22%3A%22...%22%2C...%7D
```

### Decoded JSON
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

## Key Architectural Benefits

1. **Encapsulation**: All internal logic is hidden within the SDK
2. **Consistency**: Follows the same pattern as existing `record(event:)` method
3. **Private Property Access**: `userIdentity` and `domain` remain private to ATTNSDK
4. **Clean API**: Users only interact with EventTracker, not internal classes
5. **Automatic Handling**: Timestamps, identifiers, and encoding handled automatically
6. **Type Safety**: Strongly typed Product and Cart models
7. **Null Safety**: Explicit null encoding matches Android behavior

## Migration Guide

### Before (Old Pattern - DO NOT USE)
```swift
// This no longer works - sendNewEvent is removed from ATTNSDK
let event = ATTNBaseEvent(...)
sdk.sendNewEvent(event: event, eventRequest: ..., userIdentity: ...)
```

### After (New Pattern - RECOMMENDED)
```swift
// Use EventTracker methods
tracker.recordAddToCart(product: product, currency: "USD")
```

## Build Status
✅ Build succeeded with only non-critical warnings
✅ All events now match Android SDK payload format
✅ Follows iOS SDK architectural patterns
✅ Private properties remain encapsulated
