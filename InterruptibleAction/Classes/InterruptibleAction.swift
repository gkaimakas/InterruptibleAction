//
//  InterruptibleAction.swift
//  InterruptibleAction
//
//  Created by George Kaimakas on 26/01/2019.
//

import ReactiveSwift
import Result

/// A wrapper that creates an `Action` that can be interrupted.
public final class InterruptibleAction<Input, Output, Error: Swift.Error> {
    /// Interrupt the currently executing action.
    public let interrupt: Action<Void, Void, NoError>
    
    /// The inner action that generates the units of work.
    public let inner: Action<Input, Output, Error>
    
    /// The lifetime of the inner `Action`.
    public let lifetime: Lifetime
    
    /// A signal of all events generated from all units of work of the inner `Action`.
    ///
    /// In other words, this sends every `Event` from every unit of work that the inner `Action`
    /// executes.
    public let events: Signal<Signal<Output, Error>.Event, NoError>
    
    /// A signal of all values generated from all units of work of the inner `Action`.
    ///
    /// In other words, this sends every value from every unit of work that the inner `Action`
    /// executes.
    public let values: Signal<Output, NoError>
    
    /// A signal of all errors generated from all units of work of the inner `Action`.
    ///
    /// In other words, this sends every error from every unit of work that the inner `Action`
    /// executes.
    public let errors: Signal<Error, NoError>
    
    /// A signal of all failed attempts to start a unit of work of the inner `Action`.
    public let disabledErrors: Signal<(), NoError>
    
    /// A signal of all completed events generated from applications of the inner action.
    ///
    /// In other words, this will send completed events from every signal generated
    /// by each SignalProducer returned from apply().
    public let completed: Signal<(), NoError>
    
    /// Whether the inner action is currently executing.
    public let isExecuting: Property<Bool>
    
    /// Whether the inner action is currently enabled.
    public let isEnabled: Property<Bool>
    
    public init<State: PropertyProtocol>(state: State, enabledIf isEnabled: @escaping (State.Value) -> Bool, execute: @escaping (State.Value, Input) -> SignalProducer<Output, Error>) {
        
        weak var weakSelf: InterruptibleAction<Input, Output, Error>!
        
        interrupt = Action(state: state, enabledIf: isEnabled, execute: { _, _ in SignalProducer(value: ()) })
        inner = Action<Input, Output, Error>(state: state,
                                             enabledIf: isEnabled,
                                             execute: { (currentState, input) -> SignalProducer<Output, Error> in
                                                
                                                return SignalProducer<Output, Error> { observer, lifetime in
                                                    lifetime += execute(currentState, input)
                                                        .materialize()
                                                        .startWithValues({ (event) in
                                                            observer.send(event)
                                                        })
                                                    
                                                    lifetime += weakSelf
                                                        .interrupt
                                                        .values
                                                        .observeValues { observer.sendInterrupted() }
                                                }
        })
        
        self.lifetime = inner.lifetime
        self.events = inner.events
        self.values = inner.values
        self.errors = inner.errors
        self.disabledErrors = inner.disabledErrors
        self.completed = inner.completed
        self.isExecuting = inner.isExecuting
        self.isEnabled = inner.isEnabled
        
        weakSelf = self
    }
    
    /// Initializes a `InterruptibleAction` that uses a property as its state.
    ///
    /// When the `InterruptibleAction` is asked to start the execution, a unit of work — represented by
    /// a `SignalProducer` — would be created by invoking `execute` with the latest value
    /// of the state.
    ///
    /// - parameters:
    ///   - state: A property to be the state of the `InterruptibleAction`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
    ///              be executed by the `InterruptibleAction`.
    public convenience init<P: PropertyProtocol>(state: P, execute: @escaping (P.Value, Input) -> SignalProducer<Output, Error>) {
        self.init(state: state, enabledIf: { _ in true }, execute: execute)
    }
    
    /// Initializes a `InterruptibleAction` that would be conditionally enabled.
    ///
    /// When the `InterruptibleAction` is asked to start the execution with an input value, a unit of
    /// work — represented by a `SignalProducer` — would be created by invoking
    /// `execute` with the input value.
    ///
    /// - parameters:
    ///   - isEnabled: A property which determines the availability of the `InterruptibleAction`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to be
    ///              executed by the `Action`.
    public convenience init<P: PropertyProtocol>(enabledIf isEnabled: P, execute: @escaping (Input) -> SignalProducer<Output, Error>) where P.Value == Bool {
        self.init(state: isEnabled, enabledIf: { $0 }) { _, input in
            execute(input)
        }
    }
    
    /// Initializes an `InterruptibleAction` that uses a property of optional as its state.
    ///
    /// When the `InterruptibleAction` is asked to start executing, a unit of work (represented by
    /// a `SignalProducer`) is created by invoking `execute` with the latest value
    /// of the state and the `input` that was passed to `apply()`.
    ///
    /// If the property holds a `nil`, the `Action` would be disabled until it is not
    /// `nil`.
    ///
    /// - parameters:
    ///   - state: A property of optional to be the state of the `Action`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
    ///              be executed by the `Action`.
    public convenience init<P: PropertyProtocol, T>(unwrapping state: P, execute: @escaping (T, Input) -> SignalProducer<Output, Error>) where P.Value == T? {
        self.init(state: state, enabledIf: { $0 != nil }) { state, input in
            execute(state!, input)
        }
    }
    
    /// Initializes an `InterruptibleAction` that would always be enabled.
    ///
    /// When the `Action` is asked to start the execution with an input value, a unit of
    /// work — represented by a `SignalProducer` — would be created by invoking
    /// `execute` with the input value.
    ///
    /// - parameters:
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to be
    ///              executed by the `Action`.
    public convenience init(execute: @escaping (Input) -> SignalProducer<Output, Error>) {
        self.init(enabledIf: Property(value: true), execute: execute)
    }
    
    /// Create a `SignalProducer` that would attempt to create and start a unit of work of
    /// the inner`Action`. The `SignalProducer` would forward only events generated by the unit
    /// of work it created.
    ///
    /// If the execution attempt is failed, the producer would fail with
    /// `ActionError.disabled`.
    ///
    /// - parameters:
    ///   - input: A value to be used to create the unit of work.
    ///
    /// - returns: A producer that forwards events generated by its started unit of work,
    ///            or emits `ActionError.disabled` if the execution attempt is failed.
    public func apply(_ input: Input) -> SignalProducer<Output, ActionError<Error>> {
        return inner.apply(input)
    }
}

extension InterruptibleAction: BindingTargetProvider {
    /// Each new trigger will cancel the previous executing action.
    public var bindingTarget: BindingTarget<Input> {
        return BindingTarget(lifetime: lifetime) { [weak self] input in
            guard let self = self else {
                return
            }
            
            self.interrupt
                .apply()
                .flatMapError { _ in SignalProducer<Void, NoError>.empty }
                .then(self.inner.apply(input))
                .start()
        }
    }
}

extension InterruptibleAction where Input == Void {
    /// Create a `SignalProducer` that would attempt to create and start a unit of work of
    /// the `Action`. The `SignalProducer` would forward only events generated by the unit
    /// of work it created.
    ///
    /// If the execution attempt is failed, the producer would fail with
    /// `ActionError.disabled`.
    ///
    /// - returns: A producer that forwards events generated by its started unit of work,
    ///            or emits `ActionError.disabled` if the execution attempt is failed.
    public func apply() -> SignalProducer<Output, ActionError<Error>> {
        return apply(())
    }
    
    /// Initializes an `Action` that uses a property of optional as its state.
    ///
    /// When the `Action` is asked to start the execution, a unit of work — represented by
    /// a `SignalProducer` — would be created by invoking `execute` with the latest value
    /// of the state.
    ///
    /// If the property holds a `nil`, the `Action` would be disabled until it is not
    /// `nil`.
    ///
    /// - parameters:
    ///   - state: A property of optional to be the state of the `Action`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
    ///              be executed by the `Action`.
    public convenience init<P: PropertyProtocol, T>(unwrapping state: P, execute: @escaping (T) -> SignalProducer<Output, Error>) where P.Value == T? {
        self.init(unwrapping: state) { state, _ in
            execute(state)
        }
    }
    
    /// Initializes an `Action` that uses a property as its state.
    ///
    /// When the `Action` is asked to start the execution, a unit of work — represented by
    /// a `SignalProducer` — would be created by invoking `execute` with the latest value
    /// of the state.
    ///
    /// - parameters:
    ///   - state: A property to be the state of the `Action`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
    ///              be executed by the `Action`.
    public convenience init<P: PropertyProtocol, T>(state: P, execute: @escaping (T) -> SignalProducer<Output, Error>) where P.Value == T {
        self.init(state: state) { state, _ in
            execute(state)
        }
    }
}
