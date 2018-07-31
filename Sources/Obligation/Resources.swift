import Foundation

/**
 A type representing a resource that can disposed

 */
public protocol Disposable {
    /**
     Disposes the resource
     */
    func dispose() throws
}

/**
 Composition of Disposable and PromiseProtocol
 */
public protocol DisposablePromise: Disposable, PromiseProtocol {
}

extension Promise {
    // MARK: Resource management

    /**
     Performs an asynchronous  operation on disposable resource, and disposes the resource
     after operation is finished, regardless of operation outcome.

     Both operation and disposal are executed on specified context,
     defaulting to original promise context.

     Returns a promise representing operation outcome
     */
    public static func using<NewValue, PromiseType>(
        on context: Context? = nil,
        _ disposable: PromiseType,
        _ work: @escaping (Value) throws -> Promise<NewValue>)
        -> Promise<NewValue>
        where PromiseType: DisposablePromise, PromiseType.ValueType == Value {
        return Promise<NewValue>(on: disposable.toPromise().context) { fulfill, reject in
            func dispose() throws {
                try disposable.dispose()
            }
            let promise = disposable.toPromise()
            promise.conduit(on: context ?? promise.context, fulfilled: { resource in
                do {
                    let newPromise = try work(resource)
                    newPromise.then { value in
                        do {
                            try dispose()
                            fulfill(value)
                        } catch let err {
                            reject(err)
                        }
                    }.catch { error in
                        do {
                            try dispose()
                            reject(error)
                        } catch let err {
                            reject(err)
                        }
                    }
                } catch {
                    do {
                        try dispose()
                        reject(error)
                    } catch let err {
                        reject(err)
                    }
                }
            },
            rejected: reject)
        }
    }

    /**
     Performs an asynchronous  operation on disposable resource, and disposes the resource
     after operation is finished, regardless of operation outcome.

     Both operation and disposal are executed on specified context,
     defaulting to original promise context.

     Returns a promise representing operation outcome
     */
    public static func using<NewValue, PromiseType>(
        on context: Context? = nil,
        _ disposable: PromiseType,
        _ work: @escaping (Value) throws -> NewValue)
        -> Promise<NewValue>
        where PromiseType: DisposablePromise, PromiseType.ValueType == Value {
        return Promise<NewValue>(on: disposable.toPromise().context) { fulfill, reject in
            func dispose() throws {
                try disposable.dispose()
            }
            let promise = disposable.toPromise()
            promise.conduit(on: context ?? promise.context, fulfilled: { resource in
                do {
                    let newValue = try work(resource)
                    do {
                        try dispose()
                        fulfill(newValue)
                    } catch let err {
                        reject(err)
                    }
                } catch {
                    do {
                        try dispose()
                        reject(error)
                    } catch let err {
                        reject(err)
                    }
                }
            },
            rejected: reject)
        }
    }
}
