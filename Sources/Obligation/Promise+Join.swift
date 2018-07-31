
/**
 Result of joining 2 promises
 */

public struct JoinOf2<V1, V2> {
    let p1: Promise<V1>
    let p2: Promise<V2>

    /**
     Returns a promise that is fulfilled after both promises are fulfilled.

     Returned promise fulfills to value returned by provided callback

     If any of joined promises is rejected, or an error is thrown in the
     callback, the resulting promise is rejected.

     `context` is used for running the callback.
     If `nil` is passed, the context of first joined promise will be used.

     */

    public func fulfill<NewValue>(
        on context: Context? = nil,
        _ transform: @escaping (V1, V2) throws -> NewValue)
        -> Promise<NewValue> {
        let promise = p1.then { v1 in return self.p2.then(on: context ?? self.p1.context) { try transform(v1, $0) } }
        return promise
    }

    /**
     Returns a promise that is fulfilled after both promises are fulfilled.

     Returned promise fulfills to fulfilled value of promise returned by provided callback

     If any of joined promises is rejected, or an error is thrown in the
     callback, or the promise returned from the callback is rejected,
     the resulting promise is rejected.

     `context` is used for running the callback.
     If `nil` is passed, the context of first joined promise will be used.
     */

    public func fulfill<NewValue>(
        on context: Context? = nil,
        _ transform: @escaping (V1, V2) throws -> Promise<NewValue>)
        -> Promise<NewValue> {
        let promise = p1.then { v1 in return self.p2.then(on: context ?? self.p1.context) { try transform(v1, $0) } }
        return promise
    }

    /**
     Joins another promise, returning an instance of JoinOf3
     */

    public func join<V3>(_ promise: Promise<V3>) -> JoinOf3<V1, V2, V3> {
        return JoinOf3(parent: self, promise: promise)
    }
}

/**
 Result of joining 3 promises
 */
public struct JoinOf3<V1, V2, V3> {
    let parent: JoinOf2<V1, V2>
    let promise: Promise<V3>

    /**
     Returns a promise that is fulfilled after all 3 promises are fulfilled.

     Returned promise fulfills to value returned by provided callback.

     If any of joined promises is rejected, or an error is thrown in the
     callback, the resulting promise is rejected.

     `context` is used for running the callback.
     If `nil` is passed, the context of first joined promise will be used.
     */
    public func fulfill<NewValue>(
        on context: Context? = nil,
        _ transform: @escaping (V1, V2, V3) throws -> NewValue)
        -> Promise<NewValue> {
        return parent.fulfill(on: context) { ($0, $1) }.then { values in
            let promise = self.promise.then(on: context) { return try transform(values.0, values.1, $0) }
            return promise
        }
    }

    /**
     Returns a promise that is fulfilled after all 3 promises are fulfilled.

     Returned promise fulfills to value returned by provided callback.

     If any of joined promises is rejected, or an error is thrown in the
     callback, the resulting promise is rejected.

     `context` is used for running the callback.
     If `nil` is passed, the context of first joined promise will be used.
     */
    public func fulfill<NewValue>(
        on context: Context? = nil,
        _ transform: @escaping (V1, V2, V3) throws -> Promise<NewValue>)
        -> Promise<NewValue> {
        return parent.fulfill(on: context) { ($0, $1) }.then { values in
            let promise = self.promise.then(on: context) { return try transform(values.0, values.1, $0) }
            return promise
        }
    }

    /**
     Joins another promise, returning an instance of JoinOf3
     */

    public func join<V4>(_ promise: Promise<V4>) -> JoinOf4<V1, V2, V3, V4> {
        return JoinOf4(parent: self, promise: promise)
    }
}

/**
 Result of joining 4 promises
 */
public struct JoinOf4<V1, V2, V3, V4> {
    let parent: JoinOf3<V1, V2, V3>
    let promise: Promise<V4>

    /**
     Returns a promise that is fulfilled after all 4 promises are fulfilled.

     Returned promise fulfills to value returned by provided callback.

     If any of joined promises is rejected, or an error is thrown in the
     callback, the resulting promise is rejected.

     `context` is used for running the callback.
     If `nil` is passed, the context of first joined promise will be used.
     */
    public func fulfill<NewValue>(
        on context: Context? = nil,
        _ transform: @escaping (V1, V2, V3, V4) throws -> NewValue)
        -> Promise<NewValue> {
        return parent.fulfill(on: context) { ($0, $1, $2) }.then { values in
            let promise = self.promise.then(on: context) { return try transform(values.0, values.1, values.2, $0) }
            return promise
        }
    }

    /**
     Returns a promise that is fulfilled after all 4 promises are fulfilled.

     Returned promise fulfills to value returned by provided callback.

     If any of joined promises is rejected, or an error is thrown in the
     callback, the resulting promise is rejected.

     `context` is used for running the callback.
     If `nil` is passed, the context of first joined promise will be used.
     */
    public func fulfill<NewValue>(
        on context: Context? = nil,
        _ transform: @escaping (V1, V2, V3, V4) throws -> Promise<NewValue>)
        -> Promise<NewValue> {
        return parent.fulfill(on: context) { ($0, $1, $2) }.then { values in
            let promise = self.promise.then(on: context) { return try transform(values.0, values.1, values.2, $0) }
            return promise
        }
    }

    /**
     Joins another promise, returning an instance of JoinOf5
     */

    public func join<V5>(_ promise: Promise<V5>) -> JoinOf5<V1, V2, V3, V4, V5> {
        return JoinOf5(parent: self, promise: promise)
    }
}

/**
 Result of joining 5 promises
 */
public struct JoinOf5<V1, V2, V3, V4, V5> {
    let parent: JoinOf4<V1, V2, V3, V4>
    let promise: Promise<V5>

    /**
     Returns a promise that is fulfilled after all 5 promises are fulfilled.

     Returned promise fulfills to value returned by provided callback.

     If any of joined promises is rejected, or an error is thrown in the
     callback, the resulting promise is rejected.

     `context` is used for running the callback.
     If `nil` is passed, the context of first joined promise will be used.
     */
    public func fulfill<NewValue>(
        on context: Context? = nil,
        _ transform: @escaping (V1, V2, V3, V4, V5) throws -> NewValue)
        -> Promise<NewValue> {
        return parent.fulfill(on: context) { ($0, $1, $2, $3) }.then { values in
            let promise = self.promise.then(on: context) { return try transform(values.0, values.1, values.2, values.3, $0) }
            return promise
        }
    }

    /**
     Returns a promise that is fulfilled after all 5 promises are fulfilled.

     Returned promise fulfills to value returned by provided callback.

     If any of joined promises is rejected, or an error is thrown in the
     callback, the resulting promise is rejected.

     `context` is used for running the callback.
     If `nil` is passed, the context of first joined promise will be used.
     */
    public func fulfill<NewValue>(
        on context: Context? = nil,
        _ transform: @escaping (V1, V2, V3, V4, V5) throws -> Promise<NewValue>)
        -> Promise<NewValue> {
        return parent.fulfill { ($0, $1, $2, $3) }.then { values in
            let promise = self.promise.then(on: context) { return try transform(values.0, values.1, values.2, values.3, $0) }
            return promise
        }
    }
}

extension Promise {
    // MARK: Promise joining, instance methods

    /**
     Joins this promise with another, returning an instance of `JoinOf2`

     While `all` and `reduce` are good for handling a collection of uniform promises,
     `join` is much easier to use when you have a small fixed amount of
     heterogenous discrete promises that you want to coordinate concurrently.

     Returns an instance of `JoinOf2` struct that can be used to join more
     promises, or to handle the result of promise join.

     ### Example:

     ```swift
     func joinHandler(int: Int, uint: UInt) -> String {
     // jazzy output is broken when using string interpolation :(
     return "int: " + String(int) + " uint: " + String(uint)
     }
     promiseResolvingToInt().join(promiseResolvingToUInt())
     .fulfill(joinHandler).then { str in
     print(str);
     }.done()
     ```

     Calls to `join` can be chained to join up to 5 promises.

     */

    public func join<V2>(_ p2: Promise<V2>) -> JoinOf2<Value, V2> {
        return JoinOf2(p1: self, p2: p2)
    }

    /**
     Joins this promise with another 2 promises, returning an instance of `JoinOf3`
     */
    public func join<V2, V3>(
        _ p2: Promise<V2>, _ p3: Promise<V3>)
        -> JoinOf3<Value, V2, V3> {
        return join(p2).join(p3)
    }

    /**
     Joins this promise with another 3 promises, returning an instance of `JoinOf4`
     */
    public func join<V2, V3, V4>(
        _ p2: Promise<V2>, _ p3: Promise<V3>, _ p4: Promise<V4>)
        -> JoinOf4<Value, V2, V3, V4> {
        return join(p2).join(p3).join(p4)
    }

    /**
     Joins this promise with another 4 promises, returning an instance of `JoinOf5`
     */
    public func join<V2, V3, V4, V5>(
        _ p2: Promise<V2>, _ p3: Promise<V3>, _ p4: Promise<V4>, _ p5: Promise<V5>)
        -> JoinOf5<Value, V2, V3, V4, V5> {
        return join(p2).join(p3).join(p4).join(p5)
    }

    // MARK: Promise joining, static methods

    /**
     Joins 2 promises, returning an instance of `JoinOf2`
     */
    public static func join<V2>(
        _ p1: Promise<Value>, _ p2: Promise<V2>)
        -> JoinOf2<Value, V2> {
        return p1.join(p2)
    }

    /**
     Joins 3 promises, returning an instance of `JoinOf3`
     */
    public static func join<V2, V3>(
        _ p1: Promise<Value>, _ p2: Promise<V2>, _ p3: Promise<V3>)
        -> JoinOf3<Value, V2, V3> {
        return p1.join(p2).join(p3)
    }

    /**
     Joins 4 promises, returning an instance of `JoinOf4`
     */
    public static func join<V2, V3, V4>(
        _ p1: Promise<Value>, _ p2: Promise<V2>, _ p3: Promise<V3>, _ p4: Promise<V4>)
        -> JoinOf4<Value, V2, V3, V4> {
        return p1.join(p2).join(p3).join(p4)
    }

    /**
     Joins 5 promises, returning an instance of `JoinOf5`
     */
    public static func join<V2, V3, V4, V5>(
        _ p1: Promise<Value>, _ p2: Promise<V2>, _ p3: Promise<V3>,
        _ p4: Promise<V4>, _ p5: Promise<V5>)
        -> JoinOf5<Value, V2, V3, V4, V5> {
        return p1.join(p2).join(p3).join(p4).join(p5)
    }
}
