import Foundation

internal func concurrencyLimiter<C, Source, PromiseArg, PromiseType, Transformed, Result>(
    concurrency: UInt,
    sources: C,
    preProcess: @escaping (Int, Source, @escaping (PromiseArg) throws -> Void, @escaping (Error) throws -> Void) -> Void,
    getPromise: @escaping (Int, PromiseArg) throws -> Promise<PromiseType>,
    transform: @escaping (Int, PromiseArg, PromiseType) -> Transformed?,
    postProcess: @escaping ([Transformed?]) -> Result,
    on context: Context
) -> Promise<Result> where C: Collection, C.Iterator.Element == Source {
    guard !sources.isEmpty else { return .fulfilled(postProcess([])) }
    let concurrency = concurrency == 0 ? UInt.max : concurrency
    let sources = sources.map { $0 }
    var running: UInt = 0
    var later: [(Int, PromiseArg)] = []
    var results: [Transformed?] = Array(repeating: nil, count: sources.count)
    var count = sources.count

    return Promise<Result>(on: context) { fulfill, reject in

        var cancel = false

        func rejectAll(_ error: Error) {
            guard !cancel else { return }
            cancel = true
            reject(error)
        }

        func processPending() {
            guard !later.isEmpty && running < concurrency else { return }
            let (idx, source) = later.removeFirst()
            processNext(idx, source)
        }

        func processNext(_ idx: Int, _ arg: PromiseArg) {
            let promise: Promise<PromiseType>
            do {
                running += 1
                promise = try getPromise(idx, arg)
            } catch let error {
                cancel = true
                reject(error)
                return
            }
            promise.then(on: context) { value in
                running -= 1
                results[idx] = transform(idx, arg, value)
                count -= 1
                if count != 0 {
                    context.execute(processPending)
                } else {
                    fulfill(postProcess(results))
                }
            }.catch(on: context) { error in
                cancel = true
                reject(error)
            }
        }

        sources.enumerated().forEach { s in
            let (idx, source) = s
            preProcess(idx, source, { promiseArg in
                if running < concurrency {
                    processNext(idx, promiseArg)
                } else {
                    later.append((idx, promiseArg))
                }
            }, rejectAll)
        }
    }
}

extension Collection where IndexDistance == Int {
    // MARK: Collection of values

    /**

     - Note: this method applies only to

     ```swift
     Collection where IndexDistance == Int
     ```

     Returns a promise of values from collection mapped using provided mapper.

     Promises returned by the mapper function are awaited for and the resulting promise doesn't
     fulfill until all mapped promises have fulfilled.

     The `concurrency` limit applies to Promises returned by the mapper function and it limits
     the number of promises created. For example, if concurrency is 3 and the mapper
     has been called enough so that there are 3 returned promises currently pending,
     no further calls to mapper are made until one of the pending promises fulfills.

     If any of promises returned by the mapper are rejected, resulting
     promise is rejected as well.

     - parameter context: context for new promise
     - parameter concurrency: maximum concurrency
     - parameter mapper: code block to map original values from collection
     */

    public func map<NewValue>(
        on context: Context = DispatchQueue.main,
        concurrency: UInt,
        _ mapper: @escaping (Iterator.Element) throws -> Promise<NewValue>)
        -> Promise<[NewValue]> {
        return concurrencyLimiter(
            concurrency: concurrency,
            sources: self,
            preProcess: { _, value, done, _ in try! done(value) },
            getPromise: { _, value in try mapper(value) },
            transform: { _, _, value in value },
            postProcess: { values in values.map { $0! } },
            on: context
        )
    }

    /**
     - Note: this method applies only to

     ```swift
     Collection where IndexDistance == Int
     ```

     Reduces a collection of values to a promise fulfilled to a single value, using provided reducer.

     If any promise returned by reducer is rejected, resulting promise is rejected as well.

     - parameter context: context for new promise
     - parameter initial: initial value for reducer
     - parameter reducer: code block to reduce the values from collection

     */
    public func reduce<NewValue>(
        on context: Context = DispatchQueue.main,
        _ initial: NewValue,
        _ reducer: @escaping (NewValue, Iterator.Element) throws -> Promise<NewValue>)
        -> Promise<NewValue> {
        guard !isEmpty else { return .fulfilled(on: context, initial) }
        var values = map { $0 }
        var acc: NewValue = initial
        return Promise<NewValue>(on: context) { fulfill, reject in
            func reduceStep() {
                let value = values.removeFirst()
                do {
                    let reducerPromise = try reducer(acc, value)
                    reducerPromise.then(on: context) { value in
                        acc = value
                        if values.isEmpty {
                            fulfill(acc)
                        } else {
                            reduceStep()
                        }
                    }.catch(on: context) { error in
                        reject(error)
                    }
                } catch let error {
                    reject(error)
                }
            }
            reduceStep()
        }
    }

    /**

     - Note: this method applies only to

     ```swift
     Collection where IndexDistance == Int
     ```

     Returns a promise fulfilled to an array of values from the collection
     satisfying provided filter.

     The `concurrency` limit applies to Promises returned by the filter function and it limits
     the number of promises created. For example, if concurrency is 3 and the filter
     has been called enough so that there are 3 returned promises currently pending,
     no further calls to filter are made until one of the pending promises fulfills.

     If any promise returned from filter is rejected, resulting promise is rejected as well.

     - parameter context: context for new promise
     - parameter concurrency: maximum concurrency
     - parameter filter: code block to filter the values from collection
     */
    public func filter(
        on context: Context = DispatchQueue.main,
        concurrency: UInt = UInt.max,
        _ filter: @escaping (Iterator.Element) throws -> Promise<Bool>)
        -> Promise<[Iterator.Element]> {
        return concurrencyLimiter(
            concurrency: concurrency,
            sources: self,
            preProcess: { _, value, done, _ in try! done(value) },
            getPromise: { _, value in try filter(value) },
            transform: { (_, arg, value) -> Iterator.Element? in value ? arg : nil },
            postProcess: { values in values.filter { $0 != nil }.map { $0! } },
            on: context
        )
    }
}

extension Collection where Iterator.Element: PromiseProtocol, IndexDistance == Int {
    // MARK: Collection of Promises

    /**

     - Note: this method applies only to

     ```swift
     Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
     ```

     Returns a new promise that is fulfilled
     when all promises in collection are fulfilled, or rejected if any of promises
     is rejected.

     Returned promise fulfills to an array of values, in same order as corresponding
     promises in original collection.

     - parameter context: context for new promise
     */
    public func all(on context: Context = DispatchQueue.main)
        -> Promise<[Iterator.Element.ValueType]> {
        return Promise<[Iterator.Element.ValueType]>(on: context) { fulfill, reject in
            guard !self.isEmpty else { fulfill([]); return }
            var count = self.count
            var cancel = false
            var values: [Iterator.Element.ValueType?] = Array(repeating: nil, count: count)
            for (idx, promise) in self.enumerated() {
                promise.toPromise().then(on: context) { (value) -> Void in
                    guard !cancel else { return }
                    values[idx] = value
                    count -= 1
                    if count == 0 {
                        fulfill(values.map { $0! })
                    }
                }.catch(on: context) { error in
                    cancel = true
                    reject(error)
                }
            }
        }
    }

    /**
     - Note: this method applies only to

     ```swift
     Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
     ```

     Returns a promise that is fulfilled
     after as many as possible, but no more than `max` and no less than `min` promises
     from the collection are fulfilled. Fulfilled value is an array with
     values in the order they were fulfilled. If `min` is nil, it is considered to
     be equal to `max`.

     If `min` is nil or equals to `max`, the resulting promise is fulfilled only after
     exactly `max` promises from collection are fulfilled.

     If too many promises from collection are rejected so that the resulting promise
     can never become fulfilled (that is, number of rejected promises plus `min` is greater
     than collection size),  it will be immediately rejected with an `AggregateError`
     of the rejection reasons in the order they were thrown in.

     If the collection size if less than `min`, resulting promise will be immediatelt rejected
     with empty `AggregateError`.

     - Precondition: if `min` is not nil, it must be less than or equal to `max`

     - parameter context: context for new promise
     - parameter min: minimum number of promises
     - parameter max: maximum number of promises
     */
    public func some(
        on context: Context = DispatchQueue.main,
        min: UInt? = nil,
        max: UInt)
        -> Promise<[Iterator.Element.ValueType]> {
        return Promise<[Iterator.Element.ValueType]>(on: context) { fulfill, reject in
            precondition(min == nil || min! <= max, "min must be less than or equal to max")
            let min = min ?? max
            guard self.count >= Int(min) else { reject(AggregateError()); return }
            var errors = AggregateError()
            guard !self.isEmpty else {
                fulfill([])
                return
            }
            let totalPromises = self.count
            let maxErrors = totalPromises - Int(min)
            var cancel = false
            var values: [Iterator.Element.ValueType] = []

            func maybeFulfillOrReject() {
                if errors.endIndex > maxErrors {
                    cancel = true
                    reject(errors)
                } else if values.count == Int(max) || errors.endIndex + values.count == totalPromises {
                    cancel = true
                    fulfill(values)
                }
            }

            for promise in self {
                promise.toPromise().conduit(on: context) { (resolution: Resolution<Iterator.Element.ValueType>) in
                    guard !cancel else { return }
                    switch resolution {
                    case let .fulfilled(value):
                        values.append(value)
                    case let .rejected(error):
                        errors.append(error)
                    }
                    maybeFulfillOrReject()
                }
            }
        }
    }

    /**
     - Note: this method applies only to

     ```swift
     Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
     ```

     Similar to `some` with 1 as `min` and max`. However, resulting promise is fulfilled
     not with array of 1 element, but with  fulfilled value directly

     - parameter context: context for new promise

     */
    public func any(on context: Context = DispatchQueue.main)
        -> Promise<Iterator.Element.ValueType> {
        return some(on: context, min: 1, max: 1).then { (value) -> Iterator.Element.ValueType in
            value[0]
        }
    }

    /**

     - Note: this method applies only to

     ```swift
     Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
     ```

     Returns a promise resolving to array of fulfilled
     values mapped using provided mapper

     ### Example

     ```swift
     func doubler(promises: [Promise<Int>]) -> Promise<[Int]> {
     return Promise.map(promises) { $0 + $0 }
     }
     doubler(promises: [.fulfilled(1), .fulfilled(2)]).then { doubled in
     print(doubled) // prints [2, 4]
     }
     ```

     ### Example: changing type

     ```swift
     func toString(promises: [Promise<Int>]) -> Promise<[String]> {
     return Promise.map(promises) { number in return String(number) }
     }
     toString(promises: [.fulfilled(1), .fulfilled(2)]).then { strings in
     print(strings) // prints ["1", "2"]
     }
     ```
     - parameter context: context for new promise
     - parameter mapper: code block to map values from collection

     */
    public func map<NewValue>(
        on context: Context = DispatchQueue.main,
        _ mapper: @escaping (Iterator.Element.ValueType) throws -> NewValue
    ) -> Promise<[NewValue]> {
        return Promise<[NewValue]>(on: context) { fulfill, reject in
            var count = self.count
            var values: [NewValue?] = Array(repeating: nil, count: count)
            var cancel = false
            for (idx, promise) in self.enumerated() {
                promise.toPromise().conduit(on: context) { (resolution: Resolution<Iterator.Element.ValueType>) in
                    guard !cancel else { return }
                    do {
                        switch resolution {
                        case let .fulfilled(value):
                            values[idx] = try mapper(value)
                            count -= 1
                            if count == 0 {
                                cancel = true
                                fulfill(values.map { $0! })
                            }
                        case let .rejected(error):
                            cancel = true
                            reject(error)
                        }
                    } catch let error {
                        cancel = true
                        reject(error)
                    }
                }
            }
        }
    }

    /**

     - Note: this method applies only to

     ```swift
     Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
     ```

     Returns a promise resolving to array of fulfilled
     values mapped using provided mapper

     Promises returned by the mapper function are awaited for and the resulting promise doesn't
     fulfill until all mapped promises have fulfilled as well.

     The `concurrency` limit applies to Promises returned by the mapper function and it limits
     the number of promises created. For example, if concurrency is 3 and the mapper
     has been called enough so that there are 3 returned promises currently pending,
     no further calls to mapper are made until one of the pending promises fulfills.

     If original promise or any of promises returned by the mapper are rejected, resulting
     promise is rejected as well.

     - parameter context: context for new promise
     - parameter concurrency: maximum concurrency
     - parameter mapper: code block to map values from collection
     */

    public func map<NewValue>(
        on context: Context = DispatchQueue.main,
        concurrency: UInt,
        _ mapper: @escaping (Iterator.Element.ValueType) throws -> Promise<NewValue>)
        -> Promise<[NewValue]> {
        return concurrencyLimiter(
            concurrency: concurrency,
            sources: self,
            preProcess: { _, promise, done, error in
                promise.toPromise().then(on: context, onFulfilled: done, onRejected: error)
            },
            getPromise: { (_, value: Iterator.Element.ValueType) -> Promise<NewValue> in try mapper(value) },
            transform: { (_, _, value: NewValue) -> NewValue in value },
            postProcess: { values in values.map { $0! } },
            on: context
        )
    }

    /**
     - Note: this method applies only to

     ```swift
     Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
     ```

     Reduces a collection of promises to a promise fulfilled to a single value, using provided reducer.

     If any of promises from the collection is rejected, resulting promise is rejected as well.

     Basically equivalent of `Promise.all(on: contex, promises: promises).then {values in return values.reduce(initial, reducer) }`

     - parameter context: context for new promise
     - parameter initial: initial value for reducer
     - parameter reducer: code block to reduce the values from collection

     */
    public func reduce<NewValue>(
        on context: Context = DispatchQueue.main,
        _ initial: NewValue,
        _ reducer: @escaping (NewValue, Iterator.Element.ValueType) throws -> NewValue)
        -> Promise<NewValue> {
        guard !isEmpty else { return .fulfilled(on: context, initial) }
        var promises = map { $0 }
        var acc: NewValue = initial
        return Promise<NewValue>(on: context) { fulfill, reject in
            func ignoreRejected() {
                for promise in promises {
                    promise.toPromise().conduit(on: context, fulfilled: noop, rejected: noop)
                }
            }
            func reduceStep() {
                let promise = promises.removeFirst()
                promise.toPromise().then(on: context) { value in
                    do {
                        acc = try reducer(acc, value)
                        if promises.isEmpty {
                            fulfill(acc)
                        } else {
                            reduceStep()
                        }
                    } catch let error {
                        ignoreRejected()
                        reject(error)
                    }
                }.catch(on: context) { error in
                    ignoreRejected()
                    reject(error)
                }
            }
            reduceStep()
        }
    }

    /**
     - Note: this method applies only to

     ```swift
     Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
     ```

     Reduces a collection of promises to a promise fulfilled to a single value, using provided reducer.

     If any of promises from the collection is rejected, or any promise returned by reducer is rejected,
     resulting promise is rejected as well.

     - parameter context: context for new promise
     - parameter initial: initial value for reducer
     - parameter reducer: code block to reduce the values from collection

     */
    public func reduce<NewValue>(
        on context: Context = DispatchQueue.main,
        _ initial: NewValue,
        _ reducer: @escaping (NewValue, Iterator.Element.ValueType) throws -> Promise<NewValue>)
        -> Promise<NewValue> {
        guard !isEmpty else { return .fulfilled(on: context, initial) }
        var promises = map { $0 }
        var acc: NewValue = initial
        return Promise<NewValue>(on: context) { fulfill, reject in
            func ignoreRejected() {
                for promise in promises {
                    promise.toPromise().conduit(on: context, fulfilled: noop, rejected: noop)
                }
            }
            func reduceStep() {
                let promise = promises.removeFirst()
                promise.toPromise().then(on: context) { value in
                    do {
                        let reducerPromise = try reducer(acc, value)
                        reducerPromise.then(on: context) { value in
                            acc = value
                            if promises.isEmpty {
                                fulfill(acc)
                            } else {
                                reduceStep()
                            }
                        }.catch(on: context) { error in
                            ignoreRejected()
                            reject(error)
                        }
                    } catch let error {
                        ignoreRejected()
                        reject(error)
                    }
                }.catch(on: context) { error in
                    ignoreRejected()
                    reject(error)
                }
            }
            reduceStep()
        }
    }

    /**

     - Note: this method applies only to

     ```swift
     Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
     ```

     Returns a promise fulfilled to an array of values from collection
     satisfying provided filter.

     If any promise from the collection is rejected, resulting promise is
     rejected as well.

     - parameter context: context for new promise
     - parameter filter: code block to filter the values from collection
     */

    public func filter(
        on context: Context = DispatchQueue.main,
        _ filter: @escaping (Iterator.Element.ValueType) throws -> Bool)
        -> Promise<[Iterator.Element.ValueType]> {
        guard !isEmpty else { return .fulfilled([]) }
        var count = self.count
        var cancel = false
        var values: [Iterator.Element.ValueType?] = Array(repeating: nil, count: count)
        return Promise<[Iterator.Element.ValueType]>(on: context) { fulfill, reject in
            for (idx, promise) in self.enumerated() {
                promise.toPromise().then(on: context) { value in
                    guard !cancel else { return }
                    do {
                        if try filter(value) {
                            values[idx] = value
                        }
                        count -= 1
                        if count == 0 {
                            fulfill(values.filter { $0 != nil }.map { $0! })
                        }
                    } catch let error {
                        cancel = true
                        reject(error)
                    }
                }.catch(on: context) { error in
                    guard !cancel else { return }
                    cancel = true
                    reject(error)
                }
            }
        }
    }

    /**

     - Note: this method applies only to

     ```swift
     Collection where Iterator.Element : PromiseProtocol, IndexDistance == Int
     ```

     Returns a promise fulfilled to an array of values from collection
     satisfying provided filter.

     The `concurrency` limit applies to Promises returned by the filter function and it limits
     the number of promises created. For example, if concurrency is 3 and the filter
     has been called enough so that there are 3 returned promises currently pending,
     no further calls to filter are made until one of the pending promises fulfills.

     If any promise from the collection is rejected, or any promise returned from filter
     is rejected, resulting promise is rejected as well.

     - parameter context: context for new promise
     - parameter concurrency: maximum concurrency
     - parameter filter: code block to filter the values from collection
     */
    public func filter(
        on context: Context = DispatchQueue.main,
        concurrency: UInt,
        _ filter: @escaping (Iterator.Element.ValueType) throws -> Promise<Bool>)
        -> Promise<[Iterator.Element.ValueType]> {
        return concurrencyLimiter(
            concurrency: concurrency,
            sources: self,
            preProcess: { _, promise, done, error in
                promise.toPromise().then(on: context, onFulfilled: done, onRejected: error)
            },
            getPromise: { _, value in try filter(value) },
            transform: { (_, arg, value) -> Iterator.Element.ValueType? in value ? arg : nil },
            postProcess: { values in values.filter { $0 != nil }.map { $0! } },
            on: context
        )
    }
}
