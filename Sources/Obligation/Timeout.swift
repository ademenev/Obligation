import Foundation

extension Promise {

    // MARK: Delays and Timeouts

    /**
        Returns a new delayed promise.

        Returned promise is equivalent to original promise, with this difference:

        - once original promise fulfills, new promise will fulfill after specified delay.
        - if original promise is rejected, new promise is rejected immediately
      */
    public func delay(_ interval: Double) -> Promise<Value> {
        return Promise<Value>(on: self.context) { fulfill, reject in
			self.conduit(on: self.context, fulfilled: {value in
			    DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    fulfill(value)
                }
            }, rejected: reject)
        }
    }

    /**
        Returns a new delayed promise.

        Returned promise is fulfilled when original promise is fulfilled, but not before
        specified deadline.
      */
    public func delay(deadline: DispatchTime) -> Promise<Value> {
        return Promise<Value>(on: self.context) { fulfill, reject in
            var fulfillLater = false
			DispatchQueue.main.asyncAfter(deadline: deadline) {
                if self.isFulfilled { fulfill(self.value!) }
                else { fulfillLater = true }
            }
			self.conduit(on: DispatchQueue.main, fulfilled: {value in
                if (fulfillLater) { fulfill(value) }
            }, rejected: reject)
        }
    }

    /**
        Returns a promise that is rejected with TimeoutError if original promise is not fulfilled
        within specified interval, otherwise retured promise is fulfilled
      */
    public func timeout(_ interval: Double) -> Promise<Value> {
        return timeout(deadline: .now() + interval)
    }

    /**
        Returns a promise that is rejected with specified error if original promise is not fulfilled
        within specified interval, otherwise retured promise is fulfilled
      */
    public func timeout(_ interval: Double, error: @autoclosure @escaping () -> Error) -> Promise<Value> {
        return timeout(deadline: .now() + interval, error: error())
    }

    /**
        Returns a promise that is rejected with sepcified error if original promise is not fulfilled
        before specified deadline, otherwise retured promise is fulfilled
      */
    public func timeout(deadline: DispatchTime, error: @autoclosure @escaping () -> Error) -> Promise<Value> {
        return Promise<Value>(on: self.context) { fulfill, reject in
			DispatchQueue.main.asyncAfter(deadline: deadline) {
                reject(error())
            }
			self.conduit(on: self.context, fulfilled: fulfill, rejected: reject)
        }
    }

    /**
        Returns a promise that is rejected with TimeoutError if original promise is not fulfilled
        before specified deadline, otherwise retured promise is fulfilled
      */
    public func timeout(deadline: DispatchTime) -> Promise<Value> {
        return Promise<Value>(on: self.context) { fulfill, reject in
			DispatchQueue.main.asyncAfter(deadline: deadline) {
                reject(TimeoutError())
            }
			self.conduit(on: self.context, fulfilled: fulfill, rejected: reject)
        }
    }
}
