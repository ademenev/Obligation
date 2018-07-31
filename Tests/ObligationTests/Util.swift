import Foundation
import Nimble
import Obligation

let ctxLabel = "TestsContext"

struct MockError: Error {
    let f: String
    let l: Int
    init(f: String = #file, l: Int = #line) {
        self.f = f
        self.l = l
    }
}

struct MockError2: Error {
}

let contextKey = DispatchSpecificKey<String>()

func checkContext(_ label: String) {
    let value = DispatchQueue.getSpecific(key: contextKey)
    expect(value).to(equal(label), description: "Current context is expected to be \(label), got \(value)")
}

func createContext(label: String) -> Context {
    let queue = DispatchQueue(label: label, qos: .userInitiated)
    queue.setSpecific(key: contextKey, value: label)
    return queue
}

func noErrors<Value>(_ createPromise: () -> Promise<Value>) {
    let promise = createPromise().then { (_) -> Int in
        return 0
    }.recover { (error) -> Int in
        expect("\(error)").to(equal(""))
        expect(false).to(beTrue(), description: "No errors expected")
        return 0
    }.then(testContext)
    expect(promise.isPending).toEventually(beFalse(), description: "Promise returned to noErrors() still pending")
}

func expectError<Value>(_ createPromise: () -> Promise<Value>) {
    let promise = createPromise().then { (_) -> Int in
        expect(false).to(beTrue(), description: "Promise is expected to be rejected")
        return 0
    }.recover { (_) -> Int in
        return 0
    }.then(testContext)
    expect(promise.isPending).toEventually(beFalse(), description: "Promise returned to expectError() still pending")
}

func expectError<Value, ErrorType: Error>(type: ErrorType.Type, _ createPromise: () -> Promise<Value>) {
    let promise = createPromise().then { (_) -> Int in
        expect(false).to(beTrue(), description: "Promise is expected to be rejected")
        return 0
    }.recover(type: type) { (_) -> Int in
        return 0
    }.recover { (error) -> Int in
        let actualType = type(of: error)
        expect(false).to(beTrue(), description: "Expected \(type) to be thrown, but \(actualType) was thrown ")
        return 0
    }.then(testContext)
    expect(promise.isPending).toEventually(beFalse(), description: "Promise returned to expectError() still pending")
}

func testContext<Value>(_: Value) {
    checkContext(ctxLabel)
}
