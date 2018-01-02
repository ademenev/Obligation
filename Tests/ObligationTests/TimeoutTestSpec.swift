import Obligation
import Foundation

import Quick
import Nimble

fileprivate let context = createContext(label: ctxLabel)

class TimeoutTestSpec: QuickSpec {

	override func spec() {

        describe("'delay'") {
			it("returns a promise that is fulfilled after specified time interval after original promise is fulfilled") {
                noErrors { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    let now : dispatch_time_t = DispatchTime.now().rawValue
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        promise.fulfill(100)
                    }
                    return promise.delay(0.02).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        expect(value).to(equal(100))
                        expect(fulfilledAfterDelayAt).to(beGreaterThanOrEqualTo(now + 30000000))
                        return value
                    }
                }
            }
			it("returns a promise that is rejected immediately after original promise is rejected") {
                expectError { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        promise.reject(MockError())
                    }
                    return promise.delay(0.02).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        expect(value).to(equal(100))
                        return value
                    }.catch {error in
                        expect(fulfilledAfterDelayAt).to(equal(0))
                        throw error
                    }
                }
            }
        }
        describe("'delay' with deadline") {
			it("returns a promise that is fulfilled as soon as original promise is fulfilled, but not before deadline") {
                noErrors { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    let deadline = DispatchTime.now() + 0.02
                    let fulfillAt = DispatchTime.now() + 0.01
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    DispatchQueue.main.asyncAfter(deadline: fulfillAt) {
                        promise.fulfill(100)
                    }
                    return promise.delay(deadline: deadline).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        expect(value).to(equal(100))
                        expect(fulfilledAfterDelayAt).to(beGreaterThanOrEqualTo(deadline.rawValue))
                        return value
                    }
                }
                noErrors { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    let deadline = DispatchTime.now() + 0.01
                    let fulfillAt = DispatchTime.now() + 0.02
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    DispatchQueue.main.asyncAfter(deadline: fulfillAt) {
                        promise.fulfill(100)
                    }
                    return promise.delay(deadline: deadline).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        expect(value).to(equal(100))
                        expect(fulfilledAfterDelayAt).to(beGreaterThanOrEqualTo(fulfillAt.rawValue))
                        return value
                    }
                }
            }
			it("returns a promise that is rejected immediately after original promise is rejected") {
                expectError { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    let deadline = DispatchTime.now() + 0.02
                    let rejectAt = DispatchTime.now() + 0.01
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    DispatchQueue.main.asyncAfter(deadline: rejectAt) {
                        promise.reject(MockError())
                    }
                    return promise.delay(deadline: deadline).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        expect(value).to(equal(100))
                        expect(fulfilledAfterDelayAt).to(beGreaterThanOrEqualTo(deadline.rawValue))
                        return value
                    }.catch { error in
                        expect(DispatchTime.now().rawValue).to(beGreaterThanOrEqualTo(rejectAt.rawValue))
                        expect(fulfilledAfterDelayAt).to(equal(0))
                        throw error
                    }
                }
            }
        }

        describe("'timeout'") {
			it("returns a promise that is fulfilled as soon as  original promise is fulfilled, within timeout") {
                noErrors { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    let now : dispatch_time_t = DispatchTime.now().rawValue
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        promise.fulfill(100)
                    }
                    return promise.timeout(0.02).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        expect(value).to(equal(100))
                        expect(fulfilledAfterDelayAt).to(beGreaterThanOrEqualTo(now + 10000000))
                        expect(fulfilledAfterDelayAt).to(beLessThan(now + 20000000))
                        return value
                    }
                }
            }
			it("returns a promise that is rejected with TimeoutError if original promise is not fulfilled within timeout") {
                expectError(type: TimeoutError.self) { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        promise.fulfill(100)
                    }
                    return promise.timeout(0.01).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        return value
                    }.catch { error in
                        expect(fulfilledAfterDelayAt).to(equal(0))
                        throw error
                    }
                }
            }
			it("can specify error to use instead of TimeoutError") {
                expectError(type: MockError.self) { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        promise.fulfill(100)
                    }
                    return promise.timeout(0.01, error: MockError()).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        return value
                    }.catch { error in
                        expect(fulfilledAfterDelayAt).to(equal(0))
                        throw error
                    }
                }
            }
        }

        describe("'timeout' with deadline") {
			it("returns a promise that is fulfilled as soon as  original promise is fulfilled before deadline") {
                noErrors { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    let now : dispatch_time_t = DispatchTime.now().rawValue
                    let deadline = DispatchTime.now() + 0.02

                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        promise.fulfill(100)
                    }
                    return promise.timeout(deadline: deadline).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        expect(value).to(equal(100))
                        expect(fulfilledAfterDelayAt).to(beGreaterThanOrEqualTo(now + 10000000))
                        expect(fulfilledAfterDelayAt).to(beLessThan(now + 20000000))
                        return value
                    }
                }
            }
			it("returns a promise that is rejected with TimeoutError if original promise is not fulfilled before dedline") {
                expectError(type: TimeoutError.self) { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    let deadline = DispatchTime.now() + 0.01
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        promise.fulfill(100)
                    }
                    return promise.timeout(deadline: deadline).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        return value
                    }.catch { error in
                        expect(fulfilledAfterDelayAt).to(equal(0))
                        throw error
                    }
                }
            }
			it("can specify error to use instead of TimeoutError") {
                expectError(type: MockError.self) { () -> Promise<Int> in
                    let promise = Promise<Int>(on: context)
                    var fulfilledAfterDelayAt : dispatch_time_t = 0
                    let deadline = DispatchTime.now() + 0.01
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        promise.fulfill(100)
                    }
                    return promise.timeout(deadline: deadline, error: MockError()).then { (value) -> Int in
                        fulfilledAfterDelayAt = DispatchTime.now().rawValue
                        return value
                    }.catch { error in
                        expect(fulfilledAfterDelayAt).to(equal(0))
                        throw error
                    }
                }
            }
        }
    }
}


