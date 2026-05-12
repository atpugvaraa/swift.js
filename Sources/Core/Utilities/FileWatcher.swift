//
//  FileWatcher.swift
//  swiftjs
//
//  Monitors Swift files for changes and triggers recompilation
//

import Foundation

/// Watches a directory for .swift file changes and invokes a callback
public final class FileWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var directorySource: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.swiftjs.filewatcher", qos: .utility)
    private let debounceInterval: TimeInterval
    private var lastEventTime: Date = .distantPast
    private var debounceWorkItem: DispatchWorkItem?
    
    /// Callback invoked when a file change is detected
    public var onChange: ((String) -> Void)?
    
    /// Initialize with a debounce interval to coalesce rapid saves
    public init(debounceInterval: TimeInterval = 0.1) {
        self.debounceInterval = debounceInterval
    }
    
    deinit {
        stop()
    }
    
    /// Start watching a directory for .swift file changes
    public func watch(directory: String) throws {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directory)
        
        guard fileManager.fileExists(atPath: directory) else {
            throw FileWatcherError.directoryNotFound(directory)
        }
        
        // Watch the directory itself for new/deleted files
        let dirFD = open(directory, O_EVTONLY)
        guard dirFD >= 0 else {
            throw FileWatcherError.cannotOpenDirectory(directory)
        }
        
        let dirSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD,
            eventMask: [.write, .rename],
            queue: queue
        )
        
        dirSource.setEventHandler { [weak self] in
            self?.handleDirectoryChange(directory)
        }
        
        dirSource.setCancelHandler {
            close(dirFD)
        }
        
        dirSource.resume()
        directorySource = dirSource
        
        // Watch individual .swift files
        let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "swift" {
                try watchFile(fileURL.path)
            }
        }
    }
    
    /// Watch a single file
    private func watchFile(_ path: String) throws {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            throw FileWatcherError.cannotOpenFile(path)
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )
        
        source.setEventHandler { [weak self] in
            self?.handleFileChange(path)
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        source.resume()
        sources.append(source)
    }
    
    /// Handle a file change event with debouncing
    private func handleFileChange(_ path: String) {
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.onChange?(path)
        }
        
        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
    
    /// Handle a directory change (new/deleted files)
    private func handleDirectoryChange(_ directory: String) {
        handleFileChange(directory)
    }
    
    /// Stop watching all files
    public func stop() {
        directorySource?.cancel()
        directorySource = nil
        
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }
    
    /// Errors that can occur during file watching
    public enum FileWatcherError: Error, CustomStringConvertible {
        case directoryNotFound(String)
        case cannotOpenDirectory(String)
        case cannotOpenFile(String)
        
        public var description: String {
            switch self {
            case .directoryNotFound(let path):
                return "Directory not found: \(path)"
            case .cannotOpenDirectory(let path):
                return "Cannot open directory for watching: \(path)"
            case .cannotOpenFile(let path):
                return "Cannot open file for watching: \(path)"
            }
        }
    }
}
