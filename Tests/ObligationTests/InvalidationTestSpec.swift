import Foundation
import Obligation

import Nimble
import Quick

fileprivate let context = createContext(label: ctxLabel)

class InvalidationTestSpec: QuickSpec {
    override func spec() {
        describe("InvalidationToken") {
            it("can invalidate context") {
                let token = InvalidationToken(context)
                let promise = Promise<Int>(on: token.context)
                var fulfilledValue = 0
                var finished = false
                promise.then { value in
                    fulfilledValue = value
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    token.invalidate()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    promise.fulfill(100)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    expect(fulfilledValue).to(equal(0))
                    finished = true
                }
                expect(finished).toEventually(beTrue())
            }
        }
    }
}
