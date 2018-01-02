Obligation provides a number of extensions to standard Collection protocol.

These extensions are divided into categories: **Collection of values** and **Collection of promises**.

Collection of values is a collection conforming to

```swift
Collection where IndexDistance == Int
```

Collection of promises is a more specialized collection conforming to

```swift
Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
```

In each category, a number of methods is provided, such as `map`, `reduce`, `filter`.
See `Collection` documentation for more information.


