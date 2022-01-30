//
//  SettingsView.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 12/29/21.
//

import SwiftUI
import Kingfisher

struct SettingsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @State var confirmingReset = false
    @State var cloudSync = NSUbiquitousKeyValueStore.default.bool(forKey: "cloudSync")
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink {
                        List {
                            HStack {
                                Text("Version")
                                Spacer()
                                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                                    .foregroundColor(.secondaryLabel)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .navigationBarTitle("About")
                    } label: {
                        Text("About")
                    }
                    Link("GitHub Repository", destination: URL(string: "https://github.com/Skittyblock/Aidoku")!)
                    Link("Discord Server", destination: URL(string: "https://discord.gg/tGqkkKBBe5")!)
                }
                Section {
                    Toggle("iCloud Sync", isOn: $cloudSync)
                }
                Section {
                    Button {
                        URLCache.shared.removeAllCachedResponses()
                        KingfisherManager.shared.cache.clearMemoryCache()
                        KingfisherManager.shared.cache.clearDiskCache()
                        KingfisherManager.shared.cache.cleanExpiredDiskCache()
                    } label: {
                        Text("Clear Cached Data")
                    }
                    Button {
                        DataManager.shared.clearLibrary()
                    } label: {
                        Text("Clear Library")
                    }
                    Button {
                        DataManager.shared.clearHistory()
                    } label: {
                        Text("Clear Read History")
                    }
                    if #available(iOS 15.0, *) {
                        Button(role: .destructive) {
                            confirmingReset = true
                        } label: {
                            Text("Reset")
                        }
                        .confirmationDialog("Are you sure? This will remove all stored data and reset all settings.", isPresented: $confirmingReset, titleVisibility: .visible) {
                            Button("Reset", role: .destructive) {
                                KingfisherManager.shared.cache.clearMemoryCache()
                                KingfisherManager.shared.cache.clearDiskCache()
                                KingfisherManager.shared.cache.cleanExpiredDiskCache()
                                DataManager.shared.clearLibrary()
                                DataManager.shared.clearHistory()
                                DataManager.shared.clearManga()
                                DataManager.shared.clearChapters()
                                SourceManager.shared.clearSources()
                                UserDefaults.resetStandardUserDefaults()
                            }
                        }
                    } else {
                        Button {
                            confirmingReset = true
                        } label: {
                            Text("Reset")
                        }
                        .foregroundColor(.red)
                        .actionSheet(isPresented: $confirmingReset) {
                            ActionSheet(
                                title: Text("Are you sure? This will remove all stored data and reset all settings."),
                                buttons: [
                                    .default(Text("Reset").foregroundColor(.red)) {
                                        KingfisherManager.shared.cache.clearMemoryCache()
                                        KingfisherManager.shared.cache.clearDiskCache()
                                        KingfisherManager.shared.cache.cleanExpiredDiskCache()
                                        DataManager.shared.clearLibrary()
                                        DataManager.shared.clearHistory()
                                        UserDefaults.resetStandardUserDefaults()
                                    }
                                ]
                            )
                        }
                    }
                }
            }
            .onChange(of: cloudSync) { newValue in
                NSUbiquitousKeyValueStore.default.set(newValue as NSNumber, forKey: "cloudSync")
                DataManager.shared.setupContainer(cloudSync: newValue)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Done")
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
