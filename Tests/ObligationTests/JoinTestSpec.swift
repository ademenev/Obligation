import Obligation
import Foundation

import Quick
import Nimble

class JoinTestSpec: QuickSpec {

    let contexts: [Context] = [
        createContext(label: ctxLabel),
        createContext(label: "Context 2"),
        createContext(label: "Context 3"),
        createContext(label: "Context 4"),
        createContext(label: "Context 5"),
    ]

	func joinHelper(_ n: Int, _ callback: ([Promise<Int>], Error?) -> Promise<Int>) {
		let promises: [Promise] = (0 ..< n).map { .fulfilled(on: self.contexts[$0],  1 << $0) }
		let expected = (0 ..< n).map { 1 << $0 }.reduce(0, +)
        noErrors {
    		return callback(promises, nil).then() { total in
    			expect(total).to(equal(expected))
            }
        }
        for i in 0 ..< n {
		    let promises: [Promise] = (0 ..< n).map { $0 == i ? .rejected(on: self.contexts[$0], MockError()) : .fulfilled(on: self.contexts[$0],  1 << $0) }
            expectError {
    		    return callback(promises, nil).then() { total in
    			    expect(total).to(equal(expected))
                }
            }
        }
        expectError {
    		return callback(promises, MockError()).then() { total in
    			expect(total).to(equal(expected))
            }
        }
	}

	override func spec() {

		describe("'join'") {
			it("joins two promises") {
				self.joinHelper(2) { p, err in
					p[0].join(p[1]).fulfill(on: self.contexts[0]) { (v1, v2) -> Int in
                        if err != nil { throw err! }
                        testContext()
						return v1 + v2
					}
				}
			}
			it("joins three promises") {
				self.joinHelper(3) { p, err in
					p[0].join(p[1]).join(p[2]).fulfill(on: self.contexts[0]) { (v1, v2, v3) -> Int in
                        if err != nil { throw err! }
                        testContext()
						return v1 + v2 + v3
					}
				}
			}
			it("joins four promises") {
				self.joinHelper(4) { p, err in
					p[0].join(p[1]).join(p[2]).join(p[3]).fulfill(on: self.contexts[0]) { (v1, v2, v3, v4) -> Int in
                        if err != nil { throw err! }
                        testContext()
						return v1 + v2 + v3 + v4
					}
				}
			}
			it("joins five promises") {
				self.joinHelper(5) { p, err in
					p[0].join(p[1]).join(p[2]).join(p[3]).join(p[4]).fulfill(on: self.contexts[0]) { (v1, v2, v3, v4, v5) -> Int in
                        if err != nil { throw err! }
                        testContext()
						return v1 + v2 + v3 + v4 + v5
					}
				}
			}
			it("joins two promises (returning promise)") {
				self.joinHelper(2) { p, err in
					p[0].join(p[1]).fulfill(on: self.contexts[0]) { (v1, v2) -> Promise<Int> in
                        if err != nil { throw err! }
                        testContext()
						return Promise.fulfilled(v1 + v2)
					}
				}
			}
			it("joins three promises (returning promise)") {
				self.joinHelper(3) { p, err in
					p[0].join(p[1]).join(p[2]).fulfill(on: self.contexts[0]) { (v1, v2, v3) -> Promise<Int> in
                        if err != nil { throw err! }
                        testContext()
						return Promise.fulfilled(v1 + v2 + v3)
					}
				}
			}
			it("joins four promises (returning promise)") {
				self.joinHelper(4) { p, err in
					p[0].join(p[1]).join(p[2]).join(p[3]).fulfill(on: self.contexts[0]) { (v1, v2, v3, v4) -> Promise<Int> in
                        if err != nil { throw err! }
                        testContext()
						return Promise.fulfilled(v1 + v2 + v3 + v4)
					}
				}
			}
			it("joins five promises (returning promise)") {
				self.joinHelper(5) { p, err in
					p[0].join(p[1]).join(p[2]).join(p[3]).join(p[4]).fulfill(on: self.contexts[0]) { (v1, v2, v3, v4, v5) -> Promise<Int> in
                        if err != nil { throw err! }
                        testContext()
						return Promise.fulfilled(v1 + v2 + v3 + v4 + v5)
					}
				}
			}

		}
	}
}

