import Foundation
import Obligation

import Nimble
import Quick

fileprivate let context = createContext(label: ctxLabel)

class PromisesAsValuesTestSpec: QuickSpec {
    override func spec() {
        describe("'then'") {
            it("accepts both Value and Promise from callback") {
                noErrors {
                    Promise.fulfilled(on: context, 10).then { (_) -> Int in
                        20
                    }.then { _ in
                        Promise.fulfilled(30)
                    }.then { value in
                        expect(value).to(equal(30))
                    }
                }
            }
        }

        describe("'recover'") {
            it("accepts both Value and Promise from callback") {
                noErrors {
                    Promise<Int>.rejected(on: context, MockError()).recover { (_) -> Int in
                        throw MockError2()
                    }.recover { _ in
                        10
                    }.then { _ in
                        700
                    }.recover { _ in
                        Promise.fulfilled(30)
                    }
                }
            }
        }
    }
}
