# Migration Guide

This guide documents public API renames and deprecations in the Attentive iOS SDK, with the steps needed to move off deprecated symbols before they are removed in the next major version.

## `ATTNPrice.price` → `ATTNPrice.amount`

`ATTNPrice` is the SDK's money-pair value type (amount + currency). Its amount field was originally named `price`, which stutters with the enclosing type at every call site (`item.price.price`). The field is now named `amount`; the old accessor and initializer remain functional but deprecated, and will be removed in the next major version.

### Swift

```swift
// Before
let price = ATTNPrice(price: NSDecimalNumber(string: "15.99"), currency: "USD")
let amount = item.price.price

// After
let price = ATTNPrice(amount: NSDecimalNumber(string: "15.99"), currency: "USD")
let amount = item.price.amount
```

Xcode offers an automatic fix-it for both the accessor and the initializer via `@available(*, deprecated, renamed:)`.

### Objective-C

```objc
// Before
ATTNPrice *price = [[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"];
NSDecimalNumber *amount = item.price.price;

// After
ATTNPrice *price = [[ATTNPrice alloc] initWithAmount:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"];
NSDecimalNumber *amount = item.price.amount;
```

### Notes

- `ATTNItem.price` (the `ATTNPrice` value on an item) is **not** renamed — only the inner amount field on `ATTNPrice`.
- Behavior is unchanged: the deprecated `price` accessor returns `amount`, and `init(price:currency:)` forwards to `init(amount:currency:)`.
