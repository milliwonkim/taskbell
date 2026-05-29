//
//  TaskBellWidgetLiveActivity.swift
//  TaskBellWidget
//
//  Created by 김기원 on 5/29/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TaskBellWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TaskBellWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskBellWidgetAttributes.self) { context in
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

extension TaskBellWidgetAttributes {
    fileprivate static var preview: TaskBellWidgetAttributes {
        TaskBellWidgetAttributes(name: "World")
    }
}

extension TaskBellWidgetAttributes.ContentState {
    fileprivate static var smiley: TaskBellWidgetAttributes.ContentState {
        TaskBellWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TaskBellWidgetAttributes.ContentState {
         TaskBellWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TaskBellWidgetAttributes.preview) {
   TaskBellWidgetLiveActivity()
} contentStates: {
    TaskBellWidgetAttributes.ContentState.smiley
    TaskBellWidgetAttributes.ContentState.starEyes
}
