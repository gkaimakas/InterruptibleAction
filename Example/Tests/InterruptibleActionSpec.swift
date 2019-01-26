// https://github.com/Quick/Quick

import Quick
import Nimble
import InterruptibleAction
import ReactiveSwift
import Result

class InterruptibleActionSpec: QuickSpec {
    override func spec() {
        describe("InterruptibleAction") {
            describe("interrupt") {
                it("should be enabled if inner action is executing") {
                    let enabled = MutableProperty<Bool>(true)
                    let interruptibleAction = InterruptibleAction<Void, Void, NoError>(enabledIf: enabled) { _ in
                        return SignalProducer.timer(interval: DispatchTimeInterval.seconds(1), on: QueueScheduler.main)
                            .map { _ in () }
                    }
                    
                    interruptibleAction
                        .apply()
                        .start()
                    
                    expect(interruptibleAction.inner.isExecuting.value).toEventually(equal(true))
                    expect(interruptibleAction.interrupt.isEnabled.value).toEventually(equal(true))
                }
                
                it("should be disabled if inner action is not executing") {
                    let enabled = MutableProperty<Bool>(true)
                    let interruptibleAction = InterruptibleAction<Void, Void, NoError>(enabledIf: enabled) { _ in
                        return SignalProducer.timer(interval: DispatchTimeInterval.seconds(1), on: QueueScheduler.main)
                            .map { _ in () }
                    }
                    
                    expect(interruptibleAction.inner.isExecuting.value).toEventually(equal(false))
                    expect(interruptibleAction.interrupt.isEnabled.value).toEventually(equal(false))
                }
                
                it("should terminate the currently executing unit of work") {
                    let interruptibleAction = InterruptibleAction<Void, Void, NoError> { _ in
                        return SignalProducer.timer(interval: DispatchTimeInterval.seconds(1), on: QueueScheduler.main)
                            .map { _ in () }
                    }
                    
                    interruptibleAction
                        .apply()
                        .start()
                    
                    var wasInterrupted = false
                    var anyOtherEvent: Void? = nil
                    interruptibleAction
                        .events
                        .observeValues({ (event) in
                            switch event {
                            case .interrupted:
                                wasInterrupted = true
                            default:
                                anyOtherEvent = ()
                            }
                        })
                    
                    interruptibleAction
                        .interrupt
                        .apply()
                        .start()
                    
                    expect(wasInterrupted).toEventually(equal(true))
                    expect(anyOtherEvent).toEventually(beNil())
                }
            }
            
            describe("bindingTarget") {
                it("should terminate the executing unit of work and start a new one") {
                    var innerProducerGeneration = 0
                    let interruptibleAction = InterruptibleAction<Void, Void, NoError> { _ in
                        innerProducerGeneration = innerProducerGeneration + 1
                        return SignalProducer.never
                    }
                    
                    var wasInterrupted = false
                    var anyOtherEvent: Void? = nil
                    interruptibleAction
                        .events
                        .observeValues({ (event) in
                            switch event {
                            case .interrupted:
                                wasInterrupted = true
                            default:
                                anyOtherEvent = ()
                            }
                        })
                    
                    interruptibleAction
                        .apply()
                        .start()
                    
                    interruptibleAction.bindingTarget <~ SignalProducer(value: ())
                    
                    expect(innerProducerGeneration).toEventually(equal(2))
                    expect(wasInterrupted).toEventually(equal(true))
                    expect(anyOtherEvent).toEventually(beNil())
                }
                
                it("should start a new unit of work") {
                    var innerProducerGeneration = 0
                    let interruptibleAction = InterruptibleAction<Void, Void, NoError> { _ in
                        innerProducerGeneration = innerProducerGeneration + 1
                        return SignalProducer.never
                    }
                    
                    interruptibleAction.bindingTarget <~ SignalProducer(value: ())
                    
                    expect(innerProducerGeneration).toEventually(equal(1))
                    expect(interruptibleAction.isExecuting.value).toEventually(equal(true))
                }
            }
        }
    }
}
