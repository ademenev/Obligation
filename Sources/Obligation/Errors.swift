import Foundation


/**
  Error thrown if promise is not fulfilled within specified timeout
  */
public class TimeoutError: Error, CustomStringConvertible {

    // MARK: Initializers
    /**

      */
    public init() {
    }

    // MARK: CustomStringConvertible

    public var description: String {
        return "TimeoutError : promise not fulfilled within specified timeout"
    }
}

/**
  Error type representing a collection of errors
  */

public struct AggregateError : Error, Collection, CustomStringConvertible {
    internal var errors: [Error] = []
    mutating internal func append(_ error: Error) {
        errors.append(error)
    }

    // MARK: Collection

    /**
      */
    public var startIndex: Int { return 0 }

    /**
      */
    public var endIndex: Int { return errors.count }
    
    /**
      */
    public subscript(index: Int) -> Error {
        return errors[index]
    }
    
    /**
      */
    public func index(after i: Int) -> Int {
        precondition(i < endIndex, "Can't advance beyond endIndex")
        return i + 1
    }

   
    // MARK: CustomStringConvertible

    /**
      Error description
      */
    public var description: String {
        return "AggregateError with (\(errors.count) errors)";
    }


}

