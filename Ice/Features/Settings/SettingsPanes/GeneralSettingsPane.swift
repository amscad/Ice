//
//  GeneralSettingsPane.swift
//  Ice
//

import SwiftKeys
import SwiftUI

struct GeneralSettingsPane: View {
    @EnvironmentObject var statusBar: StatusBar

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                Divider()
            }

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20) {
                    controlStack
                    Divider()
                    hotkeyStack
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .mask(scrollViewMask)

            VStack(alignment: .leading, spacing: 20) {
                Divider()
                footerView
            }
        }
        .onChange(of: statusBar.isAlwaysHiddenSectionEnabled) { newValue in
            statusBar.section(withName: .alwaysHidden)?.controlItem.isVisible = newValue
            if newValue {
                KeyCommand(name: .toggleSection(withName: .alwaysHidden)).enable()
            } else {
                KeyCommand(name: .toggleSection(withName: .alwaysHidden)).disable()
            }
        }
        .padding()
    }

    var headerView: some View {
        HStack(spacing: 15) {
            Image("IceCube")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .fixedSize()

            Text("Ice - Menu Bar Manipulator")
                .font(.system(size: 30, weight: .thin))
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
    }

    var footerView: some View {
        HStack {
            Button("Reset") {
                print("RESET")
            }
            Spacer()
            Button("Quit \(Constants.appName)") {
                NSApp.terminate(nil)
            }
        }
    }

    var controlStack: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle(
                "Enable the \"Always Hidden\" menu bar section",
                isOn: $statusBar.isAlwaysHiddenSectionEnabled
            )
        }
        .padding()
    }

    var hotkeyStack: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Hotkeys")
                .font(.system(size: 20, weight: .light))

            Grid {
                LabeledKeyRecorder(name: .hidden)
                LabeledKeyRecorder(name: .alwaysHidden)
            }
        }
        .padding()
    }

    var scrollViewMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 10)

            Rectangle().fill(.black)

            LinearGradient(
                colors: [.black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 10)
        }
    }
}

struct LabeledKeyRecorder: View {
    @EnvironmentObject var statusBar: StatusBar

    let name: StatusBarSection.Name

    var body: some View {
        if
            let section = statusBar.section(withName: name),
            statusBar.isSectionEnabled(section)
        {
            gridRow
        } else {
            gridRow
                .frame(height: 0)
                .hidden()
        }
    }

    private var gridRow: some View {
        GridRow {
            Text("Toggle the \"\(name.rawValue)\" menu bar section")
            KeyRecorder(name: .toggleSection(withName: name))
        }
        .gridColumnAlignment(.leading)
    }
}

struct GeneralSettingsPane_Previews: PreviewProvider {
    @StateObject private static var statusBar = StatusBar()

    static var previews: some View {
        GeneralSettingsPane()
            .fixedSize()
            .buttonStyle(SettingsButtonStyle())
            .toggleStyle(SettingsToggleStyle())
            .environmentObject(statusBar)
    }
}
