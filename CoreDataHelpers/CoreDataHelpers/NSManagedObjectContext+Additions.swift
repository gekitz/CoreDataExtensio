//
//  NSManagedObjectContext+Additions.swift
//  meisterwork
//
//  Created by Georg Kitz on 13/02/16.
//  Copyright © 2016 9Cookies GmbH. All rights reserved.
//

import CoreData
import RxSwift
import RxCocoa

/// Extension to NSManagedObjectContext for a typed FetchRequest
public extension NSManagedObjectContext {
    
    func typedFetchRequest<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        return try! self.fetch(request) 
    }
    
    func typedObjectWithID<T: NSManagedObject>(_ objectId: NSManagedObjectID) -> T {
        return self.object(with: objectId) as! T
    }
}


/// Extensions to NSManagedObjectContext providing observables for change and save notifications
public extension NSManagedObjectContext {
    
    /// Returns an observable for the NSManagedObjectContextObjectsDidChangeNotification in the current context
    public func rx_objectsDidChange() -> Observable<RxManagedObjectContextNotification> {
        return NotificationCenter.default.rx.notification(NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: self).map {
            return RxManagedObjectContextNotification(notification: $0)
        }
    }
    
    /// Returns an observable for the NSManagedObjectContextWillSaveNotification in the current context
    public func rx_willSave() -> Observable<NSManagedObjectContext> {
        return NotificationCenter.default.rx.notification(NSNotification.Name.NSManagedObjectContextWillSave, object: self).map {
            return $0.object as! NSManagedObjectContext
        }
    }
    
    /// Returns an observable for the NSManagedObjectContextDidSaveNotification in the current context
    public func rx_didSave() -> Observable<RxManagedObjectContextNotification> {
        return NotificationCenter.default.rx.notification(NSNotification.Name.NSManagedObjectContextDidSave, object: self).map {
            return RxManagedObjectContextNotification(notification: $0)
        }
    }
}

open class RxManagedObjectContextNotification {
    open let managedObjectContext:NSManagedObjectContext
    open let insertedObjects:Set<NSManagedObject>
    open let updatedObjects:Set<NSManagedObject>
    open let deletedObjects:Set<NSManagedObject>
    
    init(notification: Notification) {
        managedObjectContext = notification.object as! NSManagedObjectContext
        
        insertedObjects = (notification as NSNotification).userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        updatedObjects = (notification as NSNotification).userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        deletedObjects = (notification as NSNotification).userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
    }
}
