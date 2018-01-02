import Obligation
import Foundation

import Quick
import Nimble

fileprivate let context = createContext(label: ctxLabel)


class MockDisposable<Value> : DisposablePromise {
    var disposed = false
    let promise: Promise<Value>
    let throwing : Bool

    init(throwing : Bool = false, _ promise: Promise<Value>) {
        self.promise = promise
        self.throwing = throwing
    }

    func toPromise() -> Promise<Value> {
        return promise
    }

    func dispose() throws -> () {
        if throwing {
            throw MockError2()
        }
        disposed = true
    }
}


func UsingHelper(promise: MockDisposable<Int>, rejected: Bool, throwing: Bool, usePromise: Bool) -> Promise<Int> {
    if usePromise {
        return Promise.using(promise) { (value) -> Promise<Int> in
            expect(value).to(equal(10));
            if throwing { throw MockError() }
            return rejected ? .rejected(MockError()) : .fulfilled(20)
        }
    } else {
        return Promise.using(promise) { (value) -> Int in
            expect(value).to(equal(10));
            if throwing { throw MockError() }
            return 20
        }
    }
}

class ResourcesTestSpec: QuickSpec {

	override func spec() {
        describe("Promise.using") {
            for usePromise in [true, false] {
                describe("when block returns a " + (usePromise ? "Promise" : "value") + ", returns a promise") {
                    it ("that fulfills to value " +  (usePromise ? "of promise " : "") + "returned by block") {
                        noErrors { () -> Promise<Int> in
                            let promise = MockDisposable(Promise.fulfilled(on: context, 10))
                            return UsingHelper(promise: promise, rejected: false, throwing: false, usePromise: usePromise)
                            .finally {
                                expect(promise.disposed).to(beTrue())
                            }.then { (value) -> Int in
                                expect(value).to(equal(20))
                                return value
                            }
                        }
                    }
                    if (usePromise) {
                        it ("that is rejected if promise returned from block is rejected") {
                            expectError { () -> Promise<Int> in
                                let promise = MockDisposable(Promise<Int>.fulfilled(on: context, 10))
                                return UsingHelper(promise: promise, rejected: true, throwing: false, usePromise: usePromise)
                                .finally {
                                    expect(promise.disposed).to(beTrue())
                                }
                            }
                        }
                    }
                    it ("that is rejected if original promise is rejected") {
                        expectError { () -> Promise<Int> in
                            let promise = MockDisposable(Promise<Int>.rejected(on: context, MockError()))
                            return UsingHelper(promise: promise, rejected: false, throwing: false, usePromise: usePromise)
                            .finally {
                                // original promise is rejected, so no resource created - nothing to dispose
                                expect(promise.disposed).to(beFalse())
                            }.then { (value) -> Int in
                                expect(value).to(equal(20))
                                return value
                            }
                        }
                    }
                    it ("that is rejected if block throws error") {
                        expectError { () -> Promise<Int> in
                            let promise = MockDisposable(Promise<Int>.fulfilled(on: context, 10))
                            return UsingHelper(promise: promise, rejected: false, throwing: true, usePromise: usePromise)
                            .finally {
                                expect(promise.disposed).to(beTrue())
                            }.then { (value) -> Int in
                                expect(value).to(equal(20))
                                return value
                            }
                        }
                    }
                    it ("that is rejected if disposer throws error") {
                        expectError(type: MockError2.self) { () -> Promise<Int> in
                            let promise = MockDisposable(throwing: true, Promise<Int>.fulfilled(on: context, 10))
                            return UsingHelper(promise: promise, rejected: false, throwing: false, usePromise: usePromise)
                            .finally {
                                // disposer failed
                                expect(promise.disposed).to(beFalse())
                            }.then { (value) -> Int in
                                expect(value).to(equal(20))
                                return value
                            }
                        }
                    }
                }
            }
        }
    }
}

