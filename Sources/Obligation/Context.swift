import Foundation

/**
  Provides execution context for promises.

  Normally you should use DispatchQueue as execution context.

  - Important: If you adopt Context protocol (and yo do not want to),
    make sure that any new
    block passed to `execute` will be executed only after
    other blocks passed for execution on same context are
    finished. That means using same thread or same DispatchQueue
    (either serial or with .barrier)

  */

public protocol Context {
	/**
	  Executes a block of code
      
      - parameter work: code block to execute
	  */
	func execute(_ work: @escaping () -> Void)
}

extension DispatchQueue: Context {
	/**

      Implementation of `Context` protocol

	  Executes a block of code on this queue asynchronously
	  */
	public func execute(_ work: @escaping () -> Void) {
		self.async(flags: .barrier, execute: work)
	}

}

