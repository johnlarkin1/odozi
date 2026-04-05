//
//  TotalActivityView.swift
//  OdysseyDeviceActivityReport
//
//  Created by John Larkin on 1/8/24.
//

import SwiftUI

struct TotalActivityView: View {
    let totalActivity: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #if DEBUG
                    // Debug build: display whatever the extension returned verbatim,
                    // wrapped in a monospaced font so diagnostic strings are readable.
                    Text(totalActivity)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                #else
                    Text(totalActivity)
                        .font(.title2.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                #endif
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// In order to support previews for your extension's custom views, make sure its source files are
// members of your app's Xcode target as well as members of your extension's target. You can use
// Xcode's File Inspector to modify a file's Target Membership.
struct TotalActivityView_Previews: PreviewProvider {
    static var previews: some View {
        TotalActivityView(totalActivity: "1h 23m")
            .background(Color.black)
    }
}
