//
//  FNPathWatcher.swift
//  Finicky
//
//  Created by John Sterling on 07/07/15.
//  Copyright (c) 2015 John sterling. All rights reserved.
//

import Foundation

open class FNPathWatcher {

    enum State {
        case on, off
    }

    fileprivate let source: DispatchSource
    fileprivate let descriptor: CInt
    fileprivate var state: State = .off

    /// Creates a folder monitor object with monitoring enabled.
    public init(url: URL, handler: ()->Void) {

        state = .off
        descriptor = open((url as NSURL).fileSystemRepresentation, O_EVTONLY)
        let queue = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default)
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: DispatchSource.FileSystemEvent.delete | DispatchSource.FileSystemEvent.write | DispatchSource.FileSystemEvent.extend | DispatchSource.FileSystemEvent.attrib | DispatchSource.FileSystemEvent.link | DispatchSource.FileSystemEvent.rename | DispatchSource.FileSystemEvent.revoke, queue: queue) /*Migrator FIXME: Use DispatchSourceFileSystemObject to avoid the cast*/ as! DispatchSource

        source.setEventHandler(handler: handler)
        //dispatch_source_set_cancel_handler({})
        start()
    }

    /// Starts sending notifications if currently stopped
    open func start() {
        if state == .off {
            state = .on
            source.resume()
        }
    }

    /// Stops sending notifications if currently enabled
    open func stop() {
        if state == .on {
            state = .off
            source.suspend()
        }
    }

    deinit {
        close(descriptor)
        source.cancel()
    }
}
