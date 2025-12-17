//
//  WidgetsBundle.swift
//  Widgets
//
//  Created by admin on 12/17/25.
//

import WidgetKit
import SwiftUI

@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        Widgets()
        WidgetsControl()
        WidgetsLiveActivity()
        FlowActivityConfiguration()
    }
}
