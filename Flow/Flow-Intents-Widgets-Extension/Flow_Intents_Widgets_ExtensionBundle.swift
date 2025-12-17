//
//  Flow_Intents_Widgets_ExtensionBundle.swift
//  Flow-Intents-Widgets-Extension
//
//  Created by admin on 12/17/25.
//

import WidgetKit
import SwiftUI

@main
struct Flow_Intents_Widgets_ExtensionBundle: WidgetBundle {
    var body: some Widget {
        Flow_Intents_Widgets_Extension()
        Flow_Intents_Widgets_ExtensionControl()
        Flow_Intents_Widgets_ExtensionLiveActivity()
    }
}
