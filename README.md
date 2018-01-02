# Obligation

Obligation is Promise library in Swift language

Promise represents the result of an asynchronous operation. A promise can be in one of three different states:

* pending - Operation is not completed, result is unknown
* fulfilled - Operation was successful, result can be obtained from the promise
* rejected - Operation was unsuccessful, error can be obtained from the promise


Once a promise is fulfilled or rejected, it is immutable (i.e. it can never change its state again).
This is called a settled promise.

Each promise has an associated `Context` on which promised operation is executed.

## Installation


The key pattern for working with promises is *promise chaining*. You chain promises by calling
`then`, `catch`, `recover` methods and providing callbacks to be executed when the promise is
fulfilled or rejected. Each of these methods returns a new promise that is fulfilled or rejected
after provided callbacks are finished.

```swift
    Promise { fulfill, reject in
        fulfill(someLongOperationReturningInt())
    }.then { value in
        // value is Int
        return "\(value)"
    }.then { value in
        throw SomeError()
    }.recover { error in
        return "recovered"
    }.then { value in
        // value is String
        print(value)
    }.done()
```

