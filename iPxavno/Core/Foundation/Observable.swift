import Foundation

@MainActor
final class Observable<Value> {
    typealias Observer = (Value) -> Void

    private var observer: Observer?

    var value: Value {
        didSet {
            observer?(value)
        }
    }

    init(_ value: Value) {
        self.value = value
    }

    func bind(_ observer: @escaping Observer) {
        self.observer = observer
        observer(value)
    }
}
