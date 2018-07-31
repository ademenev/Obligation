import Foundation
import Obligation

import Nimble
import Quick

class CollectionTester {
}

let desiredConcurrency: UInt = 4
let concurrencyContext: DispatchQueue = DispatchQueue(label: "concurrency_queue", qos: .userInitiated)

class CollectionsTestSpec: QuickSpec {
    let context = createContext(label: ctxLabel)

    func mapper(_ value: Int) -> String {
        return "\(value)"
    }

    func promisedMapper(_ value: Int) -> Promise<String> {
        return Promise.fulfilled(mapper(value))
    }

    func filter(_ value: Int) -> Bool {
        return value < 5
    }

    func promisedFilter(_ value: Int) -> Promise<Bool> {
        return Promise.fulfilled(filter(value))
    }

    func filterOne(_ value: Int) -> Bool {
        return value == 5
    }

    func promisedFilterOne(_ value: Int) -> Promise<Bool> {
        return Promise.fulfilled(filterOne(value))
    }

    func reducer(_ acc: Int, _ value: Int) -> Int {
        return acc + value * 2
    }

    func promisedReducer(_ acc: Int, _ value: Int) -> Promise<Int> {
        return Promise.fulfilled(reducer(acc, value))
    }

    var values: [Int] {
        return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    }

    var filteredValues: [Int] {
        return values.filter(filter)
    }

    var mappedValues: [String] {
        return values.map(mapper)
    }

    var mappedPromises: [Promise<String>] {
        return values.map(promisedMapper)
    }

    var mappedOriginalPromises: [Promise<Int>] {
        return values.map { value in .fulfilled(value) }
    }

    var mappedOriginalPromisesPartiallyFailed: [Promise<Int>] {
        return values.map { value in self.filter(value) ? .fulfilled(value) : .rejected(MockError()) }
    }

    var partiallyFailedPromises: [Promise<String>] {
        return values.map { value in
            if self.filter(value) {
                return self.promisedMapper(value)
            }
            return .rejected(MockError(l: value))
        }
    }

    var oneFulfilledPromise: [Promise<String>] {
        return values.map { value in
            if self.filterOne(value) {
                return self.promisedMapper(value)
            }
            return .rejected(MockError())
        }
    }

    var allRejectedPromises: [Promise<String>] {
        return mappedPromises.map { _ in Promise<String>.rejected(MockError()) }
    }

    var reducedValue: Int {
        return values.reduce(0, reducer)
    }

    var reducedPromise: Promise<Int> {
        return Promise.fulfilled(values.reduce(0, reducer))
    }

    func partiallyFailingMapper(_ value: Int) -> Promise<String> {
        return filter(value) ? .fulfilled(mapper(value)) : .rejected(MockError())
    }

    func concurrencyTest<PromiseType, ResultType, ArgType>(concurrency: UInt = desiredConcurrency, failedPromise: Bool, failedMapper: Bool, expectation: @escaping (ResultType) -> Void, transform: @escaping (ArgType) -> PromiseType, promise: @escaping (@escaping (ArgType) -> Promise<PromiseType>) -> Promise<ResultType>) {
        var currentConcurrency: UInt = 0
        var maxConcurrency: UInt = 0
        func concurrentTransform(_ value: ArgType) -> Promise<PromiseType> {
            return Promise<PromiseType> { fulfill, reject in
                concurrencyContext.sync() {
                    currentConcurrency += 1
                    maxConcurrency = maxConcurrency < currentConcurrency ? currentConcurrency : maxConcurrency
                }
                concurrencyContext.asyncAfter(deadline: .now() + 0.02) {
                    if failedMapper {
                        reject(MockError())
                    } else {
                        fulfill(transform(value))
                    }
                    currentConcurrency -= 1
                }
            }
        }
        noErrors {
            return promise(concurrentTransform).then { (values: ResultType) -> Int in
                if !failedPromise && !failedMapper {
                    expect(maxConcurrency).to(equal(concurrency), description: "Concurrency is expected to be \(concurrency), got \(maxConcurrency)")
                    expectation(values)
                } else {
                    expect(false).to(beTrue(), description: "Promise must be rejected")
                }
                return 0
            }.recover { (error) -> Int in
                if failedPromise || failedMapper {
                    return 0
                } else {
                    throw error
                }
            }
        }
    }

    func mapTest(failedPromise: Bool, failedMapper: Bool, _ promise: @escaping (@escaping (Int) -> Promise<String>) -> Promise<[String]>) {
        concurrencyTest(
            failedPromise: failedPromise,
            failedMapper: failedMapper,
            expectation: { (values: [String]) in
                expect(values).to(equal(self.mappedValues))
            },
            transform: { (value: Int) -> String in
                self.mapper(value)
            },
            promise: promise
        )
    }

    func filterTest(failedPromise: Bool, failedMapper: Bool, _ promise: @escaping (@escaping (Int) -> Promise<Bool>) -> Promise<[Int]>) {
        concurrencyTest(
            failedPromise: failedPromise,
            failedMapper: failedMapper,
            expectation: { (values: [Int]) in
                expect(values).to(equal(self.filteredValues))
            },
            transform: { (value: Int) -> Bool in
                self.filter(value)
            },
            promise: promise
        )
    }

    func reduceTest(failedPromise: Bool, failedMapper: Bool, _ promise: @escaping (@escaping ((Int, Int)) -> Promise<Int>) -> Promise<Int>) {
        concurrencyTest(
            concurrency: 1,
            failedPromise: failedPromise,
            failedMapper: failedMapper,
            expectation: { (value: Int) in
                expect(value).to(equal(self.reducedValue))
            },
            transform: { (value: (Int, Int)) -> Int in
                self.reducer(value.0, value.1)
            },
            promise: promise
        )
    }

    override func spec() {
        describe("'all'") {
            it("fulfills to an array of values after all promises are fulfilled") {
                noErrors {
                    self.mappedPromises.all(on: self.context).then { (value) -> Void in
                        expect(value).to(equal(self.mappedValues))
                    }
                }
            }

            it("is rejected if any af promises is rejected") {
                expectError {
                    self.partiallyFailedPromises.all(on: self.context)
                }
            }
        }

        describe("'some'") {
            it("fulfills after enough promises are fulfilled") {
                noErrors {
                    self.partiallyFailedPromises.some(on: self.context, max: 3).then { (value) -> Void in
                        expect(value.count).to(equal(3))
                    }
                }
            }

            it("is rejected if too many promises are rejected") {
                expectError(type: AggregateError.self) { () -> Promise<Int> in
                    let expectedRejectionsCount = 5
                    return self.partiallyFailedPromises.some(on: self.context, max: 6)
                        .then { _ in 0 }
                        .recover(type: AggregateError.self) { (error) -> Int in
                            expect(error.endIndex)
                                .to(equal(
                                    expectedRejectionsCount),
                                description: "Expected the promise to be rejected after \(expectedRejectionsCount) rejections, got \(error.endIndex)"
                                )
                            throw error
                        }
                }
            }
        }

        describe("'any'") {
            it("fulfills after one promise is fulfilled") {
                noErrors {
                    self.oneFulfilledPromise.any(on: self.context).then { (value) -> Void in
                        expect(value).to(equal("5"))
                    }
                }
            }

            it("is rejected if all promises are rejected") {
                let expectedRejectionsCount = 10
                expectError(type: AggregateError.self) {
                    return self.allRejectedPromises.any(on: self.context).then { (_) -> Int in
                        0
                    }.recover(type: AggregateError.self) { (error) -> Int in
                        expect(error.endIndex)
                            .to(equal(
                                expectedRejectionsCount),
                            description: "Expected the promise to be rejected after \(expectedRejectionsCount) rejections, got \(error.endIndex)"
                            )
                        throw error
                    }
                }
            }
        }

        describe("'map'") {
            describe("maps a collection of promises to a promise resolving to collection") {
                describe("with mapper returning a value") {
                    it("and is fulfilled if all promises are fulfilled") {
                        noErrors { () -> Promise<Int> in
                            self.mappedOriginalPromises.map(on: self.context, self.mapper).then { (values) -> Int in
                                expect(values).to(equal(self.mappedValues))
                                return 0
                            }
                        }
                    }
                    it("and is rejected if any promises are rejected") {
                        expectError {
                            self.mappedOriginalPromisesPartiallyFailed.map(on: self.context, self.mapper)
                        }
                    }

                    it("and is rejected if mapper throws an error") {
                        expectError {
                            self.mappedOriginalPromisesPartiallyFailed.map(on: self.context) { (_) -> String in
                                throw MockError()
                            }
                        }
                    }
                }
                describe("with mapper returning a promise") {
                    it("and is fulfilled if all promises are fulfilled") {
                        self.mapTest(failedPromise: false, failedMapper: false) { mapper in
                            self.mappedOriginalPromises.map(on: self.context, concurrency: desiredConcurrency, mapper)
                        }
                    }
                    it("and is rejected if any promises are rejected") {
                        self.mapTest(failedPromise: true, failedMapper: false) { mapper in
                            self.mappedOriginalPromisesPartiallyFailed.map(on: self.context, concurrency: desiredConcurrency, mapper)
                        }
                    }
                    it("and is rejected if mapper is rejected") {
                        self.mapTest(failedPromise: false, failedMapper: true) { mapper in
                            self.mappedOriginalPromises.map(on: self.context, concurrency: desiredConcurrency, mapper)
                        }
                    }

                    it("and is rejected if mapper is mapper thows an error") {
                        self.mapTest(failedPromise: false, failedMapper: true) { _ in
                            self.mappedOriginalPromises.map(on: self.context, concurrency: desiredConcurrency) { _ in
                                throw MockError()
                            }
                        }
                    }
                }
            }

            describe("can map collection of values") {
                it("and is fulfilled if mapper is fulfilled") {
                    self.mapTest(failedPromise: false, failedMapper: false) { mapper in
                        self.values.map(on: self.context, concurrency: desiredConcurrency, mapper)
                    }
                }
                it("and is rejected if mapper is rejected") {
                    self.mapTest(failedPromise: false, failedMapper: true) { mapper in
                        self.values.map(on: self.context, concurrency: desiredConcurrency, mapper)
                    }
                }
                it("and is rejected if mapper throws error") {
                    self.mapTest(failedPromise: false, failedMapper: true) { _ in
                        self.values.map(on: self.context, concurrency: desiredConcurrency) { _ in
                            throw MockError()
                        }
                    }
                }
            }
        }

        describe("'reduce'") {
            describe("reduces a collection of values") {
                it("fulfilling if reducer is fulfilled") {
                    self.reduceTest(failedPromise: false, failedMapper: false) { reducer in
                        self.values.reduce(on: self.context, 0) { value in
                            return reducer(value)
                        }
                    }
                }
                it("rejecting if reducer is rejected") {
                    self.reduceTest(failedPromise: false, failedMapper: true) { reducer in
                        self.values.reduce(on: self.context, 0) { value in
                            return reducer(value)
                        }
                    }
                }
                it("rejecting if reducer thows error") {
                    expectError {
                        self.mappedOriginalPromises.reduce(on: self.context, 0) { (_, _) -> Int in
                            throw MockError()
                        }
                    }
                }
            }

            describe("reduces a collection of promises") {
                describe("with reducer returning a value") {
                    it("fulfilling if all promises are fulfilled") {
                        noErrors {
                            self.mappedOriginalPromises.reduce(on: self.context, 0, self.reducer).then { value in
                                expect(value).to(equal(self.reducedValue))
                            }
                        }
                    }
                    it("rejecting if any of promises are rejected") {
                        expectError {
                            self.mappedOriginalPromisesPartiallyFailed.reduce(on: self.context, 0, self.reducer).then { value in
                                expect(value).to(equal(self.reducedValue))
                            }
                        }
                    }
                    it("rejecting if reducer throws an error") {
                        expectError {
                            self.mappedOriginalPromises.reduce(on: self.context, 0) { (_, _) -> Int in
                                throw MockError()
                            }
                        }
                    }
                }
            }

            describe("reduces a collection of promises") {
                describe("with reducer returning a promise") {
                    it("fulfilling if all promises are fulfilled") {
                        noErrors {
                            self.mappedOriginalPromises.reduce(on: self.context, 0, self.promisedReducer).then { value in
                                Promise.fulfilled(on: self.context, value).then { value in
                                    expect(value).to(equal(self.reducedValue))
                                }
                            }
                        }
                    }
                    it("rejecting if any of promises are rejected") {
                        expectError {
                            self.mappedOriginalPromisesPartiallyFailed.reduce(on: self.context, 0, self.promisedReducer).then { (value: Int) -> Promise<Int> in
                                Promise.fulfilled(on: self.context, value).then { (value) -> Int in
                                    expect(value).to(equal(self.reducedValue))
                                    return value
                                }
                            }
                        }
                    }
                    it("rejecting if reducer throws an error") {
                        expectError {
                            self.mappedOriginalPromises.reduce(on: self.context, 0) { (_, _) -> Promise<Int> in
                                throw MockError()
                            }
                        }
                    }
                }
            }
        }

        describe("'filter'") {
            describe("filters a collection of promises") {
                describe("with filter returning a value") {
                    it("fulfilling if all promises are fulfilled") {
                        noErrors {
                            self.mappedOriginalPromises.filter(on: self.context, self.filter)
                        }
                    }
                    it("rejecting if any promises are rejected") {
                        expectError {
                            self.mappedOriginalPromisesPartiallyFailed.filter(on: self.context, self.filter)
                        }
                    }
                    it("rejecting if filter throws error") {
                        expectError {
                            self.mappedOriginalPromises.filter(on: self.context) { _ in
                                throw MockError()
                            }
                        }
                    }
                }
                describe("with filter returning a promise") {
                    it("fulfilling if all promises are fulfilled") {
                        self.filterTest(failedPromise: false, failedMapper: false) { filter in
                            self.mappedOriginalPromises.filter(on: self.context, concurrency: desiredConcurrency, filter)
                        }
                    }
                    it("rejecting if any promises are rejected") {
                        self.filterTest(failedPromise: true, failedMapper: false) { filter in
                            self.mappedOriginalPromisesPartiallyFailed.filter(on: self.context, concurrency: desiredConcurrency, filter)
                        }
                    }
                    it("rejecting if filter is rejected") {
                        self.filterTest(failedPromise: true, failedMapper: true) { filter in
                            self.mappedOriginalPromises.filter(on: self.context, concurrency: desiredConcurrency, filter)
                        }
                    }
                    it("rejecting if filter throws error") {
                        self.filterTest(failedPromise: true, failedMapper: true) { _ in
                            self.mappedOriginalPromises.filter(on: self.context, concurrency: desiredConcurrency) { _ in
                                throw MockError()
                            }
                        }
                    }
                }
            }
            describe("filters a collection of values") {
                describe("with filter returning a promise") {
                    it("fulfilling if filter is fulfilled") {
                        self.filterTest(failedPromise: false, failedMapper: false) { filter in
                            self.values.filter(on: self.context, concurrency: desiredConcurrency, filter)
                        }
                    }
                    it("rejecting if filter is rejected") {
                        self.filterTest(failedPromise: false, failedMapper: true) { filter in
                            self.values.filter(on: self.context, concurrency: desiredConcurrency, filter)
                        }
                    }
                    it("rejecting if filter throws error") {
                        self.filterTest(failedPromise: false, failedMapper: true) { _ in
                            self.values.filter(on: self.context, concurrency: desiredConcurrency) { _ in
                                throw MockError()
                            }
                        }
                    }
                }
            }
        }
    }
}
