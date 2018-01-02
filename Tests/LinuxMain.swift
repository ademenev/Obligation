import XCTest
import Quick

@testable import CoreTests

QCKMain([
   PromiseTestSpec.self,
   PromisesAsValuesTestSpec.self,
   CollectionsTestSpec.self,
   JoinTestSpec.self,
   InvalidationTestSpec.self,
   TimeoutTestSpec.self,
   ResourcesTestSpec.self,
])
