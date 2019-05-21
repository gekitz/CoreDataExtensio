//
//  Fetchable.swift
//  meisterwork
//
//  Created by Georg Kitz on 13/02/16.
//  Copyright © 2019 meisterwork GmbH. All rights reserved.
//

import Foundation
import CoreData
import RxSwift

/// Protocol for Fetching data from CoreData Contexts

public protocol Fetchable {
    associatedtype FetchableType: NSManagedObject
    associatedtype I: Any
    
    
    /// the name of the unique ID column in the database
    static func idName() -> String
    static func defaultSortDescriptor() -> [NSSortDescriptor]
    static func objectWithIds(_ ids:[I], context: NSManagedObjectContext) -> [FetchableType]
    static func allObjects(matchingPredicate predicate: NSPredicate?, sorted:[NSSortDescriptor]?, fetchLimit: Int?, context: NSManagedObjectContext) -> [FetchableType]
    static func allObjectsCount(matchingPredicate predicate: NSPredicate?, context: NSManagedObjectContext) -> Int
    static func rxAllObjects(matchingPredicate predicate: NSPredicate?, sorted:[NSSortDescriptor]?, fetchLimit: Int?, context: NSManagedObjectContext) -> Observable<[FetchableType]>
    static func rxMonitorChanges(_ context: NSManagedObjectContext) -> Observable<(inserted:[FetchableType], updated:[FetchableType], deleted: [FetchableType])>
    static func deleteAllObjects(in context: NSManagedObjectContext) -> Bool
}

public extension Fetchable where Self: NSManagedObject {
    static func allObjectsCount(matchingPredicate predicate: NSPredicate? = nil, context: NSManagedObjectContext) -> Int {
        return allObjects(matchingPredicate: predicate, sorted: nil, fetchLimit: nil, context: context).count
    }
}

/// Default Imp
public extension Fetchable where Self : NSManagedObject, FetchableType == Self {
    
    static func objectWithIds(_ ids:[I], context: NSManagedObjectContext) -> [FetchableType] {
        
        let p = NSPredicate(format: "%K IN %@", idName(), ids)
        return allObjects(matchingPredicate: p, context: context)
    }
    
    static func allObjects(matchingPredicate predicate: NSPredicate? = nil, sorted: [NSSortDescriptor]? = nil, fetchLimit: Int? = nil, context: NSManagedObjectContext) -> [FetchableType] {
        
        let r: NSFetchRequest<FetchableType> = NSFetchRequest(entityName: entityName())
        r.predicate = predicate
        r.sortDescriptors = sorted
        
        if let fetchLimit = fetchLimit {
            r.fetchLimit = fetchLimit
        }
        
        return context.typedFetchRequest(r)
    }
    
    static func allObjectsCount(matchingPredicate predicate: NSPredicate?, context: NSManagedObjectContext) -> Int {
        return allObjects(matchingPredicate: predicate, context: context).count
    }
    
    static func rxAllObjects(matchingPredicate predicate: NSPredicate? = nil, sorted: [NSSortDescriptor]? = nil, fetchLimit: Int? = nil, context: NSManagedObjectContext) -> Observable<[FetchableType]> {
        
        return Observable.create({ (observer) -> Disposable in
            
            let r: NSFetchRequest<FetchableType> = NSFetchRequest(entityName: entityName())
            r.predicate = predicate
            r.sortDescriptors = sorted ?? defaultSortDescriptor()
            
            if let fetchLimit = fetchLimit {
                r.fetchLimit = fetchLimit
            }
            
            let container = FetchRequestContainer<FetchableType>(fetchRequest: r, context: context, observer: observer)
            container.startUpdating()
            
            return Disposables.create {
                container.dispose()
            }
        })
    }
    
    static func rxMonitorChanges(_ context: NSManagedObjectContext) -> Observable<(inserted:[FetchableType], updated:[FetchableType], deleted: [FetchableType])> {
        return context.rx_objectsDidChange()
            .filter { (notification) -> Bool in
                
                let inserted = notification.insertedObjects.filter { $0 is FetchableType }.count
                let deleted = notification.deletedObjects.filter { $0 is FetchableType }.count
                let updated = notification.updatedObjects.filter { $0 is FetchableType }.count
                
                return inserted > 0 || deleted > 0 || updated > 0
                
            }
            .map { (notification) -> (inserted:[FetchableType], updated:[FetchableType], deleted: [FetchableType]) in
                
                let inserted = Array(notification.insertedObjects.filter { $0 is FetchableType } as! Set<Self>)
                let deleted = Array(notification.deletedObjects.filter { $0 is FetchableType } as! Set<Self>)
                let updated = Array(notification.updatedObjects.filter { $0 is FetchableType } as! Set<Self>)
                
                return (inserted: inserted, updated: updated, deleted: deleted)
        }
    }
    
    static func deleteAllObjects(in context: NSManagedObjectContext) -> Bool {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName())
        let batchRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(batchRequest)
            return true
        } catch {
            print("Couldn't delete item: \(error)")
            return false
        }
    }
}

private final class FetchRequestContainer<T: NSManagedObject> {
    
    fileprivate var bag: DisposeBag? = DisposeBag()
    fileprivate var currentValues:[T] = []
    fileprivate var fetchRequest: NSFetchRequest<T>
    
    fileprivate let context: NSManagedObjectContext
    fileprivate let observer: AnyObserver<[T]>
    
    init(fetchRequest: NSFetchRequest<T>, context: NSManagedObjectContext, observer: AnyObserver<[T]>) {
        
        self.fetchRequest = fetchRequest
        self.context = context
        self.observer = observer
        
        performFetch()
    }
    
    func startUpdating() {
        
        self.context.rx_didSave().map { [weak self](notification) -> ([T], [T], [T]) in
            
            guard let entityName = self?.fetchRequest.entityName else {
                print("No Entity Name")
                return ([], [], [])
            }
            
            //            if (notification.deletedObjects.count > 0) {
            //                print(notification.deletedObjects)
            //                print(notification.deletedObjects.first!.changedValues())
            //            }
            //
            //            if (notification.updatedObjects.count > 0) {
            //                print(notification.updatedObjects)
            //                print(notification.updatedObjects.first!.changedValues())
            //            }
            
            let inserted = Array(notification.insertedObjects.filter { $0.entity.name == entityName } as! Set<T>)
            let updated = Array(notification.updatedObjects.filter { $0.entity.name == entityName } as! Set<T>)
            let deleted = Array(notification.deletedObjects.filter { $0.entity.name == entityName } as! Set<T>)
            
            return (inserted, updated, deleted)
            
            }.filter { [weak self](notification) -> Bool in
                
                if notification.0.count == 0 && notification.1.count == 0 && notification.2.count == 0 {
                    return false
                }
                
                guard let predicate = self?.fetchRequest.predicate, let currentValues = self?.currentValues else {
                    return true
                }
                
                let inserted = notification.0.filter { predicate.evaluate(with: $0) }.count > 0
                let updated = notification.1.filter { notificationObject in
                    
                    //either the updated objet evaluates positively against the predicate
                    //or the object doesn't evaluate but is currently in the currentValues list
                    return predicate.evaluate(with: notificationObject) || currentValues.filter{ notificationObject == $0}.count > 0
                    }.count > 0
                print(updated)
                
                let deleted = currentValues.filter({ (currentValue) -> Bool in
                    return notification.2.filter { currentValue == $0 }.count > 0
                }).count > 0
                
                return inserted || updated || deleted
                
            }.map { [weak self](_) -> Void in
                
                self?.performFetch()
                
            }.subscribe().disposed(by: bag!)
    }
    
    func dispose() {
        bag = nil
    }
    
    fileprivate func performFetch() {
        currentValues = context.typedFetchRequest(fetchRequest)
        observer.onNext(currentValues)
    }
}
