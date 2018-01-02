import Foundation

class InvalidationContext: Context {
    var context: Context?
	func execute(_ work: @escaping () -> Void) {
        context?.execute(work)
    }
}

/**

  InvalidationToken provides execution context that can be invalidated
  later. Invalidated context will ignore any code blocks passed for execution. 

  */

public final class InvalidationToken {

    internal var invalidationContext : InvalidationContext

    /**
        Execution context managed by this InvalidationToken
      */
    public var context: Context {
        return invalidationContext
    }

    // MARK: Initializers
    /**
      Creates an InvalidationToken. Context obtained from
      `context` variable will execute code on context passed
      in context parameter.
      */

    public init(_ context: Context) {
        self.invalidationContext = InvalidationContext()
        self.invalidationContext.context = context
    }

    // MARK: Invalidation

    /**
        Invalidates this token. Contexts obtained from `context`
        variable earlier, will no more execute blocks of code
        passed to them. If non-nil is passed in context parameter,
        then contexts obtained from `context` variable after this call
        will execute code on new context.
      */
    public func invalidate(_ context: Context? = nil) {
        self.invalidationContext.execute {
            let context = context ?? self.invalidationContext.context
            let newContext = InvalidationContext()
            newContext.context = context
            let oldContext = self.invalidationContext
            self.invalidationContext = newContext
            oldContext.context = nil
        }

    }

}
