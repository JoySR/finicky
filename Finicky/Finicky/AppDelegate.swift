//
//  AppDelegate.swift
//  Finicky
//
//  Created by John Sterling on 04/06/15.
//  Copyright (c) 2015 John Sterling. All rights reserved.
//

import Cocoa
import Foundation
import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet var statusItemMenu: NSMenu!

    var statusItem: NSStatusItem!
    var configLoader: FNConfigLoader!
    var shortUrlResolver: FNShortUrlResolver!
    var urlsToLoad = Array<String>()
    var isActive: Bool = true

    static var defaultBrowser: String! = "com.google.Chrome"

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let bundleId = "net.kassett.Finicky"
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleId as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleId as CFString)

        let img: NSImage! = NSImage(named: "statusitem")
        img.isTemplate = true

        let bar = NSStatusBar.system()
        // Workaround for some bug: -1 instead of NSVariableStatusItemLength
        statusItem = bar.statusItem(withLength: CGFloat(-1))
        statusItem.menu = statusItemMenu
        statusItem.highlightMode = true
        statusItem.image = img
        toggleDockIcon(showIcon: false)
    }

    @IBAction func reloadConfig(_ sender: NSMenuItem) {
        configLoader.reload()
    }

    @IBAction func showAboutPanel(_ sender: NSMenuItem) {
        NSApp.orderFrontStandardAboutPanel(sender)
    }

    func toggleDockIcon(showIcon state: Bool) -> Bool {
        var result: Bool
        if state {
            result = NSApp.setActivationPolicy(NSApplicationActivationPolicy.regular)
        }
        else {
            result = NSApp.setActivationPolicy(NSApplicationActivationPolicy.accessory)
        }
        return result
    }

    func handleGetURLEvent(_ event: NSAppleEventDescriptor?, withReplyEvent: NSAppleEventDescriptor?) {
        let url : URL = URL(string: event!.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))!.stringValue!)!
        let pid = event!.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))!.int32Value
        let sourceBundleIdentifier = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier

        let callback = callUrlHandlers(sourceBundleIdentifier, <#URL#>)

        if shortUrlResolver.isShortUrl(url) {
            shortUrlResolver.resolveUrl(url, callback: callback)
        } else {
            callback(url)
        }
    }

    func getActiveApp(_ bundleIds: Array<String>) -> String {
        for bundleId in bundleIds {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if !apps.isEmpty {
                let app : NSRunningApplication = apps[0]
                let bundleIdentifier = app.bundleIdentifier
                if bundleIdentifier != nil {
                    return bundleIdentifier!
                }
            }
        }

        // If we are here, no apps are running, so we return the first bundleIds in the array instead.
        return bundleIds.first!
    }

    func callUrlHandlers(_ sourceBundleIdentifier: String?, _ url: URL) {
        let flags = getFlags()
        var bundleIdentifier : String! = AppDelegate.defaultBrowser
        var newUrl : URL = url
        var openInBackground : Bool? = nil

        let strategy = FinickyAPI.callUrlHandlers(newUrl, sourceBundleIdentifier: sourceBundleIdentifier, flags: flags)
        print("opening %@ from %@ as %@ in %@", url, bundleIdentifier, strategy["url"], strategy["bundleIdentifier"]);
        if strategy["url"] != nil {
            newUrl = URL(string: strategy["url"]! as! String)!

            // If the bundle identifier is a string, open the url with that app. If it's an array, find the first running
            // app, and open the url with that. If none of the apps are running, use the first available one instead.
            if let bundleId : String? = strategy["bundleIdentifier"] as? String! {
                if bundleId != nil && !(bundleId?.isEmpty)! {
                    bundleIdentifier = strategy["bundleIdentifier"]! as! String
                }
            } else if let bundleIds = strategy["bundleIdentifier"] as? Array<String>! {
                bundleIdentifier = getActiveApp(bundleIds)
            }

            if strategy["openInBackground"] != nil {
                openInBackground = (strategy["openInBackground"]! as! Bool)
            }

            if bundleIdentifier != nil && !bundleIdentifier.isEmpty {
                openUrlWithBrowser(newUrl, bundleIdentifier:bundleIdentifier, openInBackground: openInBackground)
            }
        }
    }

    func openUrlWithBrowser(_ url: URL, bundleIdentifier: String, openInBackground: Bool?) {
        var eventDescriptor: NSAppleEventDescriptor? = NSAppleEventDescriptor()
        var errorInfo : NSDictionary? = nil
        var appleEventManager:NSAppleEventManager = NSAppleEventManager.shared()
        let urls = [url]

        var launchInBackground = !isActive
        if openInBackground != nil {
            launchInBackground = openInBackground!
        }

        if !launchInBackground {
            NSWorkspace.shared().launchApplication(
                withBundleIdentifier: bundleIdentifier,
                options: NSWorkspaceLaunchOptions.default,
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
        }

        NSWorkspace.shared().open(
            urls,
            withAppBundleIdentifier: bundleIdentifier,
            options: launchInBackground ? NSWorkspaceLaunchOptions.withoutActivation : NSWorkspaceLaunchOptions.default,
            additionalEventParamDescriptor: nil,
            launchIdentifiers: nil
        )
    }

    func getFlags() -> Dictionary<String, Bool> {
        return [
            "cmd": NSEvent.modifierFlags().intersection(.command) != [],
            "ctrl": NSEvent.modifierFlags().intersection(.control) != [],
            "shift": NSEvent.modifierFlags().intersection(.shift) != [],
            "alt": NSEvent.modifierFlags().intersection(.option) != []
        ]
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            callUrlHandlers(nil, <#URL#>)(URL(fileURLWithPath: filename ))
        }
    }

    func applicationWillFinishLaunching(_ aNotification: Notification) {
        configLoader = FNConfigLoader()
        configLoader.reload()
        shortUrlResolver = FNShortUrlResolver()
        let appleEventManager:NSAppleEventManager = NSAppleEventManager.shared()
        appleEventManager.setEventHandler(self, andSelector: #selector(AppDelegate.handleGetURLEvent(_:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidBecomeActive(_ aNotification: Notification) {
        isActive = true
    }

    func applicationDidResignActive(_ aNotification: Notification) {
        isActive = false
    }

}

