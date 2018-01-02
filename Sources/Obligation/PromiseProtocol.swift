
/**
  Protocol representing a type that can be converted to a promise.

  It mainly exists because generic types cannot be used as type constraints.
  
  */
public protocol PromiseProtocol {

    /**
        Type the promise resolves to
      */
    associatedtype ValueType
    /**
      - returns: a promise
      */
    func toPromise() -> Promise<ValueType>
}


