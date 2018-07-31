import Foundation
import Obligation

import Nimble
import Quick

fileprivate let context = createContext(label: ctxLabel)

class PromiseTestSpec: QuickSpec {
    override func spec() {
        describe("'firstly'") {
            it("creates a promise") {
                noErrors {
                    firstly(on: context) {
                        50
                    }.then { value in
                        expect(value).to(equal(50))
                    }
                }
            }
            it("creates a rejected promise if block throws") {
                expectError {
                    firstly(on: context) { () -> Int in
                        throw MockError()
                    }
                }
            }
        }

        describe("Promise") {
            it("is initialized in pending state") {
                let promise1 = Promise<String>()
                expect(promise1.isPending).to(beTrue())
                let promise2 = Promise<String>() { _, _ in
                }
                expect(promise2.isPending).to(beTrue())
            }

            it("can be initialized in fulfilled state") {
                let promise = Promise.fulfilled("YES!")
                expect(promise.isFulfilled).to(beTrue())
            }
            it("can be initialized in rejected state") {
                let promise = Promise<String>.rejected(on: context, MockError())
                expectError {
                    return promise
                }
            }

            it("can be fulfilled later") {
                let promise = Promise<Int>(on: context)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    promise.fulfill(100)
                }
                noErrors {
                    return promise.then { value in
                        expect(value).to(equal(100))
                    }
                }
            }

            it("handles errors in 'catch'") {
                var catched1 = false
                Promise<Int> { _, _ in
                    throw MockError()
                }.catch { _ in
                    catched1 = true
                }
                expect(catched1).toEventually(beTrue())

                var catched2 = false
                Promise<Int> { _, reject in
                    reject(MockError())
                }.catch { _ in
                    catched2 = true
                }
                expect(catched2).toEventually(beTrue())
            }

            it("can recover from errors") {
                let promise = Promise<Int> { _, reject in
                    reject(MockError())
                }.recover { (_) -> Int in
                    return 200
                }.then { (_) -> Int in
                    throw MockError2()
                }.recover(type: MockError2.self) { (_) -> Int in
                    throw MockError()
                }.recover(type: MockError.self) { (_) -> Int in
                    return 100
                }
                expect(promise.value).toEventually(equal(100))
            }

            it("propagates context") {
                let mainContext = createContext(label: "mainContext")
                let otherContext = createContext(label: "otherContext")

                Promise<Int>(on: mainContext) { fulfill, _ in
                    checkContext("mainContext")
                    fulfill(1)
                }.then { (value) -> Int in
                    checkContext("mainContext")
                    return value
                }.then(on: otherContext) { (_) -> Int in
                    checkContext("otherContext")
                    throw MockError()
                }.recover { (_) -> Int in
                    checkContext("mainContext")
                    return 2
                }.then { _ in
                    checkContext("mainContext")
                }
            }

            it("can change context") {
                let firstContext = createContext(label: "firstContext")
                let secondContext = createContext(label: "secondContext")

                Promise<Int>(on: firstContext) { _, reject in
                    checkContext("firstContext")
                    reject(MockError())
                }.recover(on: secondContext) { (_) -> Int in
                    checkContext("secondContext")
                    return 100
                }.then { (value) -> Int in
                    checkContext("firstContext")
                    return value
                }.change(context: secondContext)
                    .then { (_) -> Int in
                        checkContext("secondContext")
                        throw MockError()
                    }.recover(on: firstContext) { (_) -> Int in
                        checkContext("firstContext")
                        return 1000
                    }.then { (value) -> Int in
                        checkContext("secondContext")
                        return value
                    }
            }

            it("can be fulfilled only once") {
                let promise = Promise.fulfilled(10)
                var fulfilledValue = 0
                promise.then { (value) -> Void in
                    fulfilledValue = value
                }
                promise.fulfill(200)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    expect(fulfilledValue).to(equal(10))
                }
            }
            it("can be rejected only once") {
                let promise = Promise<Int>.rejected(MockError())
                var invocationCount = 0
                promise.catch { _ in
                    invocationCount += 1
                }
                promise.reject(MockError())
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    expect(invocationCount).to(equal(1))
                }
            }

            it("can handle specific errors") {
                var handled1 = false
                var handled2 = false

                Promise<Int>.rejected(MockError())
                    .catch(type: MockError.self) { _ in
                        handled1 = true
                    }

                Promise<Int>.rejected(MockError())
                    .catch(type: MockError2.self) { _ in
                    }.catch { error in
                        if error is MockError {
                            handled2 = true
                        }
                    }

                expect(handled1).toEventually(beTrue())
                expect(handled2).toEventually(beTrue())
            }
        }

        describe("Fulfilled promise") {
            it("calls 'then' handlers") {
                let promise = Promise<Int>()
                var fulfilledValue = 0
                promise.fulfill(10)
                promise.then { value in
                    fulfilledValue = value
                }.then { _ in
                    fulfilledValue = 500
                }
                expect(fulfilledValue).toEventually(equal(500))
            }
        }
        describe("Rejected promise") {
            it("calls 'catch' handlers") {
                let promise = Promise<Int>()
                var fulfilledValue = 0
                promise.reject(MockError())
                promise.recover { _ in
                    return 500
                }.then { (value) -> Void in
                    fulfilledValue = value
                }
                expect(fulfilledValue).toEventually(equal(500))
            }
        }

        describe("promise returned from 'finally' with block returning Void") {
            describe("when original promise is fulfilled") {
                it("is fulfilled after passed block is executed") {
                    noErrors { () -> Promise<Void> in
                        var finallyModified = 0
                        let promise = Promise.fulfilled(on: context, 10)
                        return promise.finally {
                            finallyModified += 1
                        }.then { _ in
                            finallyModified += 1
                        }.then { _ in
                            expect(finallyModified).to(equal(2))
                        }
                    }
                }
                it("is rejected if block throws error") {
                    var finallyModified = 0
                    let promise = Promise.fulfilled(on: context, 10)
                    expectError {
                        return promise.finally {
                            throw MockError()
                        }.then { _ in
                            finallyModified += 1
                        }
                    }
                }
            }
            describe("when original promise is rejected") {
                it("is rejected after passed block is executed") {
                    expectError { () -> Promise<Int> in
                        var finallyModified = 0
                        let promise = Promise<Int>.rejected(on: context, MockError())
                        return promise.finally {
                            finallyModified += 1
                        }.catch { err in
                            expect(finallyModified).to(equal(1))
                            throw err
                        }
                    }
                }
                it("is rejected if block throws error") {
                    expectError(type: MockError2.self) { () -> Promise<Int> in
                        let promise = Promise<Int>.rejected(on: context, MockError())
                        return promise.finally {
                            throw MockError2()
                        }.catch { err in
                            throw err
                        }
                    }
                }
            }
        }

        describe("promise returned from 'finally' with block returning Promise") {
            describe("when original promise is fulfilled") {
                it("is fulfilled after returned promise is fulfilled") {
                    noErrors { () -> Promise<Void> in
                        var finallyModified = 0
                        let promise = Promise.fulfilled(on: context, 10)
                        return promise.finally {
                            Promise.fulfilled(1).then { _ in
                                finallyModified += 1
                            }
                        }.then { _ in
                            finallyModified += 1
                        }.then { _ in
                            expect(finallyModified).to(equal(2))
                        }
                    }
                }
                it("is rejected if block throws error") {
                    let promise = Promise.fulfilled(on: context, 10)
                    expectError {
                        return promise.finally { () -> Promise<Int> in
                            throw MockError()
                        }
                    }
                }
                it("is rejected after returned promise is rejected") {
                    expectError { () -> Promise<Int> in
                        var finallyModified = 0
                        let promise = Promise.fulfilled(on: context, 10)
                        return promise.finally { () -> Promise<Int> in
                            finallyModified += 1
                            return Promise<Int>.rejected(MockError())
                        }.finally {
                            expect(finallyModified).to(equal(1))
                        }
                    }
                }
            }
            describe("when original promise is rejected") {
                it("is rejected after returned promise is fulfilled") {
                    expectError { () -> Promise<Int> in
                        var finallyModified = 0
                        let promise = Promise<Int>.rejected(on: context, MockError())
                        return promise.finally {
                            Promise.fulfilled(1).then { _ in
                                finallyModified += 1
                            }
                        }.finally {
                            expect(finallyModified).to(equal(1))
                        }
                    }
                }
                it("is rejected with new error if block throws error") {
                    let promise = Promise<Int>.rejected(on: context, MockError())
                    expectError(type: MockError2.self) {
                        return promise.finally { () -> Promise<Int> in
                            throw MockError2()
                        }
                    }
                }
                it("is rejected after returned promise is rejected") {
                    expectError(type: MockError2.self) { () -> Promise<Int> in
                        var finallyModified = 0
                        let promise = Promise<Int>.rejected(on: context, MockError())
                        return promise.finally { () -> Promise<Int> in
                            finallyModified += 1
                            return Promise<Int>.rejected(MockError2())
                        }.finally {
                            expect(finallyModified).to(equal(1))
                        }
                    }
                }
            }
        }
    }
}
