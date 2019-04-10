//
//  CoreDataContainer.swift
//  expense
//
//  Created by Richard Marktl on 09.04.19.
//  Copyright © 2019 meisterwork GmbH. All rights reserved.
//

import Foundation
import CoreData


/// The CoreDataContainer wraps the handling and creation of the NSPersistentContainer
/// coredata stack. Implemented as Singleton.
public class CoreDataContainer: NSObject {
    /// Singleton Methods
    
    private struct Static {
        static var instance: CoreDataContainer?
    }
    
    public class var instance: CoreDataContainer? {
        get {
            return Static.instance
        }
        set {
            Static.instance = newValue
        }
    }
    
    public private(set) var isStoreLoaded: Bool = false
    
    /// The class method create will try to create and load the core data store.
    ///
    /// - Parameters:
    ///   - name: the name of the NSPersistentContainer
    ///   - modelURL: path to the model file
    ///   - description: the description of the persistent container.
    public class func create(name: String, modelURL: URL, description: NSPersistentStoreDescription, completionHandler block: ((NSPersistentStoreDescription, Error?) -> Void)?) {
        instance = CoreDataContainer(name: name, modelURL: modelURL, description: description)
        instance?.container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if error == nil {
                instance?.isStoreLoaded = true
                instance?.mainContext.stalenessInterval = 0
            }
            if let block = block {
                block(storeDescription, error);
            }
        })
    }
    
    /// Destroy the singleton.
    ///
    /// - Throws: throws an error if the class method is not able to destroy the data store.
    public class func destroy() throws {
        try instance?.destroy()
        instance = nil
    }
    
    /// Properties
    
    private let container: NSPersistentContainer
    
    public var mainContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    /// Intialises a new CoreDataContainer
    ///
    /// - Parameters:
    ///   - name: the name of the NSPersistentContainer
    ///   - modelURL: path to the model file
    ///   - description: the description of the persistent container.
    init?(name: String, modelURL: URL?, description: NSPersistentStoreDescription) {
        // try to load the model
        var model: NSManagedObjectModel?
        if let modelURL = modelURL {
            model = NSManagedObjectModel(contentsOf: modelURL)
        } else {
            model = NSManagedObjectModel.mergedModel(from: nil)
        }
        
        if let model = model {
            container = NSPersistentContainer(name: name, managedObjectModel: model)
        } else {
            print("failed to load the NSManagedObjectModel")
            return nil
        }
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.saveNotification), name:NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Creates a background worker context
    ///
    /// - Returns: a new background NSManagedObjectContext
    public func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    /// Creates a new child context on the main queue
    ///
    /// - Returns: child context we just created
    public func newMainThreadChildContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = mainContext
        return context
    }
    
    /// Destroys the current persistent store
    ///
    /// - Throws: if container can't be destroyed or the store can't be removed from the file system
    public func destroy() throws {
        for description in container.persistentStoreDescriptions {
            if let storeURL = description.url {
                do {
                    try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: description.type, options: description.options)
                    try FileManager().removeItem(at: storeURL)
                } catch {
                    print("Destroy failed with: %s", error)
                }
            }
        }
        CoreDataContainer.instance = nil
    }
    
    /// Merging of the data from child to parent context
    ///
    /// - Parameter notification: changes notification
    @objc func saveNotification(notification: NSNotification) {
        let context  = notification.object as! NSManagedObjectContext?
        if let context = context, context != mainContext {
            
            let persistentStoreCoordinator = context.persistentStoreCoordinator
            if let parent = context.parent, container.persistentStoreCoordinator == persistentStoreCoordinator {
                parent.perform {
                    do {
                        try parent.save()
                    } catch {
                        print("Failed to merge changes with error: \(error)")
                    }
                }
            } else {
                mainContext.perform {
                    self.mainContext.mergeChanges(fromContextDidSave: notification as Notification)
                }
            }
        }
    }
}
