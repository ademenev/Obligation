
extension Promise {

	// MARK: Promise chaining

	/**
      Executes callbacks after promise is fulfilled or rejected.

      Returns a promise that is fulfilled when original promise is fulfilled,
      with value returned from onFulfilled callback.

      If onRejected callback is not provided, original promise rejection will be
      silently ignored.

      If an error is thrown in a callback, resulting promise will be rejected.

      Callbacks are executed on provided context. If passed context is nil, promise's
      own `context` will be used.

      - parameter context: context for callbacks
      - parameter onFulfilled: callback to execute when promise is fulfilled
      - parameter onRejected: callback to execute when promise is rejected

	  */

    @discardableResult
	public func then<NewValue>(
        on context: Context? = nil,
        onFulfilled: @escaping (Value) throws -> NewValue,
        onRejected: @escaping (Error) throws -> Void = noop )
            -> Promise<NewValue> {

        return Promise<NewValue>(on: self.context) { fulfill, reject in
			self.conduit(on: context ?? self.context, fulfilled: {value in
				do {
					fulfill(try onFulfilled(value))
				} catch let error {
					reject(error)
				}
			}, rejected: { reason in 
				do {
					try onRejected(reason)
				} catch let error {
					reject(error)
				}
			})
		}
	}

	/**
      Executes callback after promise is fulfilled.

      Returns a promise that is fulfilled when original promise is fulfilled,
      with fulfilled value of promise returned from onFulfilled callback.

      If an error is thrown in the callback, or original promise is rejected,
      or promise returned from onFulfilled is rejected, resulting promise will
      be rejected.

      Callback is executed on provided context. If passed context is nil, promise's
      own `context` will be used.

      - parameter context: context for callback
      - parameter onFulfilled: callback to execute when promise is fulfilled

	  */

    @discardableResult
	public func then<NewValue>(
        on context: Context? = nil,
        _ onFulfilled: @escaping (Value) throws -> Promise<NewValue>)
            -> Promise<NewValue>  {

        return Promise<NewValue>(on: self.context, work: { fulfill, reject in
			self.conduit(on: context ?? self.context,
				fulfilled: { value in
					do {
						try onFulfilled(value).conduit(on: context ?? self.context, fulfilled: fulfill, rejected: reject)
					} catch {
						reject(error)
					}
				},
				rejected: reject
			)
		})
	}

	/**
      Executes callback after promise is fulfilled.

      Returns a promise that is fulfilled when original promise is fulfilled,
      with value returned from onFulfilled callback.

      If an error is thrown in the callback, or original promise is rejected,
      resulting promise will be rejected.

      Callback is executed on provided context. If passed context is nil, promise's
      own `context` will be used.

      - parameter context: context for callback
      - parameter onFulfilled: callback to execute when promise is fulfilled
	  */

    @discardableResult
	public func then<NewValue>(
        on context: Context? = nil,
        _ onFulfilled: @escaping (Value) throws -> NewValue)
            -> Promise<NewValue> {

        return Promise<NewValue>(on: self.context, work: { fulfill, reject in
			self.conduit(on: context ?? self.context,
					fulfilled: { value in
						do {
							fulfill(try onFulfilled(value))
						} catch {
							reject(error)
						}
					},
					rejected: reject
				)
		})
	}

	/**
      Executes callback after promise is rejected.

      Returns a promise that is fulfilled when original promise is fulfilled.

      If original promise is rejected, the onRejected callback will be executed,
      and resulting promise will remain in pending state, unless an error is
      thrown in the callback, in which case the resulting promise will be rejected.

      Callback is executed on provided context. If passed context is nil, promise's
      own `context` will be used.

      - parameter context: context for callback
      - parameter onRejected: callback to execute when promise is rejected
	  */

    @discardableResult
	public func `catch`(
        on context: Context? = nil,
        _ onRejected: @escaping (Error) throws -> Void) 
            -> Promise<Value> {

        return Promise(on: self.context) { fulfill, reject in
			self.conduit(on: context ?? self.context, fulfilled: fulfill, rejected: { reason in
				do {
					try onRejected(reason)
				} catch let error {
					reject(error)
				}
			})
		}
	}

	/**
      Executes callback after promise is rejected.

      Returns a promise that is fulfilled when original promise is fulfilled.

      If original promise is rejected with an error of ErrorType type, the onRejected
      callback will be executed, and resulting promise will remain in rejected state,
      unless an error is thrown in the callback, in which case the resulting promise 
      will be rejected.

      If original promise is rejected with an error of type other than ErrorType,
      the resulting promise will be rejected.

      Callback is executed on provided context. If passed context is nil, promise's
      own `context` will be used.

      - parameter context: context for callback
      - parameter type: error type to catch
      - parameter onRejected: callback to execute when promise is rejected
	  */
	
    @discardableResult
    public func `catch`<ErrorType: Error>(
        on context: Context? = nil,
        type: ErrorType.Type,
        onRejected: @escaping (ErrorType) throws -> Void)
            -> Promise<Value>  {

        return Promise(on: self.context) { fulfill, reject in
			self.conduit(on: context ?? self.context, fulfilled: fulfill, rejected: { reason in
				if let specificError = reason as? ErrorType {
					do {
						try onRejected(specificError)
					} catch let error {
						reject(error)
					}
				} else {
					reject(reason)
				}
			})
		}
	}

	/**
      Executes callback after promise is rejected.

      Returns a promise that is fulfilled when original promise is fulfilled.

      If original promise is rejected with an error of ErrorType type, the onRejected
      callback will be executed, and resulting promise will be fulfilled with value returned
      from recover callback, unless an error is thrown in the callback, in which
      case the resulting promise will be rejected.

      If original promise is rejected with an error of type other than ErrorType,
      the resulting promise will be rejected.

      Callback is executed on provided context. If passed context is nil, promise's
      own `context` will be used.

      - parameter context: context for callback
      - parameter type: error type to catch
      - parameter recover: callback to execute when promise is rejected
	  */

    @discardableResult
    public func recover<ErrorType: Error>(
        on context: Context? = nil,
        type: ErrorType.Type,
        _ recover: @escaping (ErrorType) throws -> Value)
            -> Promise<Value>  {

        return Promise(on: self.context) {fulfill, reject in
			self.conduit(on: context ?? self.context, fulfilled: fulfill, rejected: { reason in
				if let specificError = reason as? ErrorType {
					do {
						fulfill(try recover(specificError))
					} catch let error {
						reject(error)
					}
				} else {
					reject(reason)
				}
			})
		}
	}

	/**
      Executes callback after promise is rejected.

      Returns a promise that is fulfilled when original promise is fulfilled.

      If original promise is rejected with an error of ErrorType type, the onRejected
      callback will be executed, and resulting promise will be fulfilled with fulfilled 
      value of promise returned from recover callback, unless an error is thrown in 
      the callback, in which case the resulting promise will be rejected.

      If an original promise is rejected with error other than ErrorType,
      or promise returned from onFulfilled is rejected, resulting promise will be 
      rejected.

      Callback is executed on provided context. If passed context is nil, promise's
      own `context` will be used.

      - parameter context: context for callback
      - parameter type: error type to catch
      - parameter recover: callback to execute when promise is rejected
	  */

    @discardableResult
	public func recover<ErrorType: Error>(
        on context: Context? = nil,
        type: ErrorType.Type,
        _ recover: @escaping (ErrorType) throws -> Promise<Value>)
            -> Promise<Value> {

        return Promise(on: self.context) {fulfill, reject in
			self.conduit(on: context ?? self.context, fulfilled: fulfill, rejected: { reason in
				if let specificError = reason as? ErrorType {
					do {
						try recover(specificError).conduit(on: context ?? self.context, fulfilled: fulfill, rejected: reject)
					} catch let error {
						reject(error)
					}
				} else {
					reject(reason)
				}
			})
		}
	}

	/**
      Executes callback after promise is rejected.

      Returns a promise that is fulfilled when original promise is fulfilled.

      If original promise is rejected the onRejected
      callback will be executed, and resulting promise will be fulfilled with
      value returned from recover callback, unless an error is thrown in 
      the callback, in which case the resulting promise will be rejected.

      Callback is executed on provided context. If passed context is nil, promise's
      own `context` will be used.

      - parameter context: context for callback
      - parameter onRejected: callback to execute when promise is rejected
	  */
    @discardableResult
	public func recover(
        on context: Context? = nil,
        _ recover: @escaping (Error) throws -> Value)
            -> Promise<Value> {

        return Promise(on: self.context) {fulfill, reject in
			self.conduit(on: context ?? self.context, fulfilled: fulfill, rejected: {reason in
				do {
					fulfill(try recover(reason))
				} catch let error {
					reject(error)
				}
			})
		}
	}

	/**
      Executes callback after promise is rejected.

      Returns a promise that is fulfilled when original promise is fulfilled.

      If original promise is rejected the onRejected
      callback will be executed, and resulting promise will be fulfilled with fulfilled 
      value of promise returned from recover callback, unless an error is thrown in 
      the callback, in which case the resulting promise will be rejected.

      If promise returned from onFulfilled is rejected, resulting promise will be 
      rejected.

      Callback is executed on provided context. If passed context is nil, promise's
      own `context` will be used.

      - parameter context: context for callback
      - parameter onRejected: callback to execute when promise is rejected
	  */

    @discardableResult
	public func recover(
        on context: Context? = nil,
        _ recover: @escaping (Error) throws -> Promise<Value>)
            -> Promise<Value> {

        return Promise(on: self.context) {fulfill, reject in
			self.conduit(on: context ?? self.context, fulfilled: fulfill, rejected: { reason in
				do {
					try recover(reason).conduit(on: context ?? self.context, fulfilled: fulfill, rejected: reject)
				} catch let error {
					reject(error)
				}
			})
		}
	}

    /**
    Returns a promise that is fulfilled after original promise is fulfilled,
    or rejected after original promise is rejected.

    Regardless of original promise settlement, specified code block is executed
    before returned promise is fulfilled or rejected.

    If the block throws, resulting promise is rejected.

      */

    @discardableResult
    public func finally(
        on context: Context? = nil,
        _ finally: @escaping () throws -> Void)
            -> Promise<Value> {

        
        return Promise(on: self.context) {fulfill, reject in
			self.conduit(on: context ?? self.context, fulfilled: { value in
                            do {
                                try finally()
                                fulfill(value)
                            } catch let error {
                                reject(error)
                            }
                        },
                
                        rejected: { reason in
                            do {
                                try finally()
                                reject(reason)
                            } catch let error {
                                reject(error)
                            }
			})

        }
    }

    /**
    Returns a promise that is fulfilled after original promise is fulfilled,
    or rejected after original promise is rejected.

    Regardless of original promise settlement, specified code block is executed
    before returned promise is fulfilled or rejected.

    Value returned from the block is used to fulfill returned promise.

    If the block throws, resulting promise is rejected.
      */

    @discardableResult
    public func finally<FinalType>(
        on context: Context? = nil,
        _ finally: @escaping () throws -> Promise<FinalType>)
            -> Promise<Value> {

        
        return Promise(on: self.context) {fulfill, reject in
			self.conduit(on: context ?? self.context) { (resolution : Resolution<Value>) in
                do {
                    try finally().conduit(on: context ?? self.context) { (finalResolution: Resolution<FinalType>) in
                        if case .rejected(let error) = finalResolution {
                            reject(error)
                        } else {
                            resolution.analisys(fulfill, reject)
                        }
                    } 
                } catch {
                    reject(error)
                }
			}
        }
    }

}

