//
//  OCTranspoWidgetExtensionLiveActivity.swift
//  OCTranspoWidgetExtension
//
//  Created by kshitij savi mavai on 2025-12-25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct OCTranspoWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct OCTranspoWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OCTranspoWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension OCTranspoWidgetExtensionAttributes {
    fileprivate static var preview: OCTranspoWidgetExtensionAttributes {
        OCTranspoWidgetExtensionAttributes(name: "World")
    }
}

extension OCTranspoWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: OCTranspoWidgetExtensionAttributes.ContentState {
        OCTranspoWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: OCTranspoWidgetExtensionAttributes.ContentState {
         OCTranspoWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: OCTranspoWidgetExtensionAttributes.preview) {
   OCTranspoWidgetExtensionLiveActivity()
} contentStates: {
    OCTranspoWidgetExtensionAttributes.ContentState.smiley
    OCTranspoWidgetExtensionAttributes.ContentState.starEyes
}
