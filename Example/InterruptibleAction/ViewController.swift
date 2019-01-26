//
//  ViewController.swift
//  InterruptibleAction
//
//  Created by gkaimakas@gmail.com on 01/26/2019.
//  Copyright (c) 2019 gkaimakas@gmail.com. All rights reserved.
//

import InterruptibleAction
import ReactiveSwift
import Result
import UIKit

class ViewController: UIViewController {
    var action: InterruptibleAction<Void, Int, NoError>!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        var execNum = 0
        action = InterruptibleAction<Void, Int, NoError> { _ -> SignalProducer<Int, NoError> in
            execNum = execNum + 1
            return SignalProducer
                .timer(interval: DispatchTimeInterval.seconds(1), on: QueueScheduler.main)
                .map { _ in execNum }
                .take(first: 6)
        }
        
        action
            .events
            .observeValues { (evemt) in
                print(evemt.description)
        }
        
        action.bindingTarget <~ SignalProducer
            .timer(interval: DispatchTimeInterval.seconds(5), on: QueueScheduler.main)
            .map { _ in () }
            .take(first: 3)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

