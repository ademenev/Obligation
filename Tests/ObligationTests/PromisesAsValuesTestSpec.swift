import Obligation
import Foundation

import Quick
import Nimble
        
fileprivate let context = createContext(label: ctxLabel)

class PromisesAsValuesTestSpec: QuickSpec {

	override func spec() {

		describe("'then'") {
			it("accepts both Value and Promise from callback") {
                noErrors {
    				return Promise.fulfilled(on: context, 10).then() { (value) -> Int in
	    				return 20
		    		}.then() { value in
			    		return Promise.fulfilled(30)
		    		}.then() { value in
				        expect(value).to(equal(30))
				    }
                }
			}
		}

		describe("'recover'") {
			it("accepts both Value and Promise from callback") {
                noErrors {
                    Promise<Int>.rejected(on: context, MockError()).recover { (error) -> Int in
                        throw MockError2()
                    }.recover { error in
                        return 10
                    }.then { value in
                        return 700
                    }.recover { error in
                        return Promise.fulfilled(30)
                    }
                }
			}
		}
	}
}

