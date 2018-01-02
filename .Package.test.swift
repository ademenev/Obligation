import PackageDescription
import Foundation

var dependencies: [Package.Dependency] = [
	.Package(url: "https://github.com/Quick/Quick.git", majorVersion: 1, minor: 1),
	.Package(url: "https://github.com/Quick/Nimble.git", majorVersion: 7),
	.Package(url: "https://github.com/mxcl/PromiseKit.git", majorVersion: 4),
]


let package = Package(
    name: "Obligation",
	targets: [
		Target(name: "Obligation"),
		Target(name: "ObligationExamples", dependencies: ["Obligation"]),
	],
	dependencies: dependencies
)
