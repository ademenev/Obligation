import Foundation


internal let stateContext: DispatchQueue = DispatchQueue(label: "promise_state_queue")

fileprivate func lockState<T>(work: () -> T) -> T {
    return stateContext.sync(execute: work)
}


/**
    A function that can be used in place of some callbacks

  */

public func noop<Value>(value: Value) -> Void {}

/**
    A function that can be used in place of some callbacks

    - returns: parameter passed to the function

 */

public func identity<Value>(value: Value) -> Value { return value}

internal var customRejectionHandler: Optional<(Error) throws -> Void>

/**
  Sets a custom function to catch all unhandled rejections.

  Only first call of this function changes the rejection handler,
  subsequent calls have no effect.

  Any error thrown inside custom handler will result in a fatal error.

  Default handler simply throws a fatal error.

  */
public func setRejectionHandler(_ handler: @escaping (Error) throws -> Void) {
    if customRejectionHandler == nil {
        customRejectionHandler = handler
    }
}

internal func unhandledRejection(error: Error) {
    guard let handler = customRejectionHandler else { fatalError("Unhandled rejection: \(error)") }
    do {
        try handler(error)
        return
    } catch let err {
        fatalError("Error in custom unhandled rejection handler: \(err)")
    }
}

internal class Callbacks<Value> {
    var firstCallback: Callback<Value>?
    var lastCallback: Callback<Value>?
    
    func add(callback: Callback<Value>) {
        if self.firstCallback == nil {
            self.firstCallback = callback
            self.lastCallback = callback
        } else {
            self.lastCallback?.next = callback
            self.lastCallback = callback
        }
    }

    func schedule(with state: State<Value>) {
        var cb: Callback<Value>? = self.firstCallback
        while cb != nil {
            cb!.call(with: state)
            cb = cb!.next
        }
        self.firstCallback = nil
        self.lastCallback = nil
    }
}

internal enum Resolution<Value> {
    case fulfilled(Value)
    case rejected(Error)

    func analisys(_ fulfilled: @escaping (Value) -> Void, _ rejected: (Error) -> Void) {
        switch self {
            case .fulfilled(let value):
                fulfilled(value)
            case .rejected (let error):
                rejected(error)
        }
    }
}

internal class RejectionTrace {
    var handled = false
    let error: Error
    init(_ error: Error) {
        self.error = error
    }
    deinit {
        if (!handled) {
            unhandledRejection(error: error)
        }
    }
}

enum State<Value> {
    case pending(Callbacks<Value>)
    case fulfilled(Value)
    case rejected(RejectionTrace)

    var isFulfilled: Bool {
        switch self {
            case .fulfilled(_):
                return true
            default:
                return false
        }
    }

    var isRejected: Bool {
        switch self {
            case .rejected(_):
                return true
            default:
                return false
        }
    }

    var isPending: Bool {
        switch self {
            case .pending:
                return true
            default:
                return false
        }
    }

    var value: Value? {
        switch self {
            case let .fulfilled(value):
                return value
            default:
                return nil
        }
    }

    var error: Error? {
        switch self {
            case let .rejected(trace):
                return trace.error
            default:
                return nil
        }
    }

    fileprivate func conduit(on context: Context, _ handler: @escaping (Resolution<Value>) -> Void) {
            switch self {
                case .fulfilled(let value):
                    context.execute {
                        handler(.fulfilled(value))
                    }
                    break
                case .rejected(let trace):
                    context.execute {
                        trace.handled = true
                        handler(.rejected(trace.error))
                    }
                    break
                case .pending(let callbacks):
                    callbacks.add(
                        callback: Callback(
                            context: context,
                            action: handler
                        )
                    )
                    break
            }
    }
}

internal class Callback<Value> {
    let context: Context
    let action: (Resolution<Value>) -> Void
    var next: Callback?
                
    internal init(context: Context, action: @escaping (Resolution<Value>) -> Void) {
        self.context = context
        self.action = action
    }

    func call(with state: State<Value>) {
        context.execute() {
            switch (state) {
                case .fulfilled(let value):
                    self.action(.fulfilled(value))
                    break;
                case .rejected(let trace):
                    trace.handled = true
                    self.action(.rejected(trace.error))
                    break
                default:
                    break
            }
        }
    }
}


/**
    Promise represents the result of an asynchronous operation.
*/
    
public final class Promise<Value> : PromiseProtocol {

    fileprivate var state: State<Value>

    /**
      Method required by PromiseProtocol

      Returns this promise
      */
    public func toPromise() -> Promise<Value> {
        return self
    }

    /**
      Context for this promise
      */
    public let context: Context

    /**
      Type alias required by PromiseProtocol.

      Represents the type this Promise fulfills to
      */
    public typealias ValueType = Value

    /**
      callback used by promised operation to fulfill the promise
      */
    public typealias FulfillCallback = (Value) -> Void
    /**
      callback used by promised operation to reject the promise
      */
    public typealias RejectCallback = (Error) -> Void

    // MARK: Initializers

    /**
      Creates a pending promise.

      - parameter context: context to execute the promise on

      */
    public init(on context: Context = DispatchQueue.main) {
        state = .pending(Callbacks())
        self.context = context
    }

    /**
      Creates a pending promise.

      The promised operation is performed by `work` function on specified context.
      When operation is completed, it must report success or failure by calling `fulfilled`
      or `rejected` respectively, to fulfill or reject the promise.

      Any errors thrown in `work` will reject the promise.


        - parameter context: promise context
        - parameter work: promised operation

      */
    public convenience init(
        on context : Context = DispatchQueue.main,
        work: @escaping (_ fulfilled: @escaping FulfillCallback, _ rejected: @escaping RejectCallback ) throws -> Void ) {

        self.init(on: context)
        context.execute() {
            do {
                try work(self.fulfill, self.reject)
            } catch {
                self.reject(error)
            }
        }
    }

    internal convenience init(on context: Context = DispatchQueue.main, fulfilled value: Value) {
        self.init(on: context)
        state = .fulfilled(value)
    }

    internal convenience init(on context: Context = DispatchQueue.main, rejected reason: Error) {
        self.init(on: context)
        state = .rejected(RejectionTrace(reason))
    }

    // MARK: Promise state

    /**
      True if the promise is fulfilled
     */

    public var isFulfilled : Bool {
        return lockState {self.state.isFulfilled}
    }

    /**
      True if the promise is rejected
     */
    public var isRejected : Bool {
        return lockState {self.state.isRejected}
    }

    /**
      True if the promise is pending
     */
    public var isPending : Bool {
        return lockState {self.state.isPending}
    }

    /**
      Operation result if promise is fulfilled, nil otherwise
     */
    public var value: Value? {
        return lockState {self.state.value}
    }

    /**
      Rejection reason if promise is rejected, nil otherwise
     */
    public var error: Error? {
        return lockState {self.state.error}
    }

    // MARK: Fulfilling and rejecting

    /**
      Fulfills the promise with provided value
      
      - parameter value: fulfilled promise value
      */
    public func fulfill(_ value: Value) {
        changeState(.fulfilled(value)) 
    }

    /**
      Rejects the promise with provided reason

      - parameter error: rejection reason
      */
    public func reject(_ reason: Error) {
        changeState(.rejected(RejectionTrace(reason)))
    }

    // MARK: Context management

    /**
      Changes promise context

      - parameter newContext: new context
      - returns: a new promise that is same as this promise, but with a different context
      */
    public func change(context newContext: Context) -> Promise<Value> {
        return Promise(on: newContext, work: { fulfill, reject in
            self.conduit (on: self.context, fulfilled: fulfill, rejected: reject)
        })
    }

    // MARK: Static methods

    /**
      Creates a fulfilled promise.

      - parameter context: promise context
      - parameter value: fulfilled value

     */

    public static func fulfilled(on context: Context = DispatchQueue.main, _ value: Value)
            -> Promise<Value> {

        return Promise(on: context, fulfilled: value)
    }

    /**
      Creates a rejected promise.

      - parameter context: promise context
      - parameter reason: rejection reason

     */

    public static func rejected(on context: Context = DispatchQueue.main, _ reason: Error)
            -> Promise<Value> {

        return Promise(on: context, rejected: reason)
    }

    internal func changeState(_ newState: State<Value>) {
        lockState {
            if case .pending(let callbacks) = self.state {
                callbacks.schedule(with: newState)
                self.state = newState
            } else if case .rejected(let trace) = newState {
                trace.handled = true
            }
        }
    }


    func conduit(on context: Context,  _ handler: @escaping (Value) -> Void) {
        conduit(on: context) { (resolution: Resolution<Value>) in
            if case .fulfilled(let value) = resolution {
                handler(value)
            }
        }
    }

    func conduit(on context: Context, _ handler: @escaping (Error) -> Void) {
        conduit(on: context) { (resolution: Resolution<Value>) in
            if case .rejected(let error) = resolution {
                handler(error)
            }
        }
    }

    func conduit(on context: Context, fulfilled: @escaping (Value) -> Void, rejected: @escaping (Error) -> Void) {
        conduit(on: context) { (resolution: Resolution<Value>) in
            switch resolution {
                case .fulfilled(let value):
                    fulfilled(value)
                    break
                case .rejected(let error):
                    rejected(error)
                    break
            }
        }
    }

    func conduit(on context: Context, _ handler: @escaping (Resolution<Value>) -> Void) {
        lockState {
            self.state.conduit(on : context, handler)
        }
    }

}

/**
    Returns a promise that is fulfilled to the result returned by passed
    block. If the block throws an error, returned promise is rejected.
  */
public func firstly<Value>(
    on context: Context = DispatchQueue.main, 
    _ work : @escaping () throws -> Value)
        -> Promise<Value> {

    return Promise(on: context) { fulfill, reject in
        do {
            fulfill(try work())
        } catch {
            reject(error)
        }
    }
}

/**
    Alias of `firstly(on:_:)`
  */

public func attempt<Value>(
    on context: Context = DispatchQueue.main,
    _ work : @escaping () throws -> Value)
        -> Promise<Value> {

    return firstly(on: context, work);
}

