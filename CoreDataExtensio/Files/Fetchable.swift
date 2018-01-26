//
//  Fetchable.swift
//  meisterwork
//
//  Created by Georg Kitz on 13/02/16.
//  Copyright © 2016 9Cookies GmbH. All rights reserved.
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
}


/// Default Imp
public extension Fetchable where Self : NSManagedObject, FetchableType == Self {
    
    public static func objectWithIds(_ ids:[I], context: NSManagedObjectContext) -> [FetchableType] {
        
        let p = NSPredicate(format: "%K IN %@", idName(), ids)
        return allObjects(matchingPredicate: p, context: context)
    }
    
    public static func allObjects(matchingPredicate predicate: NSPredicate? = nil, sorted: [NSSortDescriptor]? = nil, fetchLimit: Int? = nil, context: NSManagedObjectContext) -> [FetchableType] {
        
        let r: NSFetchRequest<FetchableType> = NSFetchRequest(entityName: entityName())
        r.predicate = predicate
        r.sortDescriptors = sorted
        
        if let fetchLimit = fetchLimit {
            r.fetchLimit = fetchLimit
        }
        
        return context.typedFetchRequest(r)
    }
    
    public static func allObjectsCount(matchingPredicate predicate: NSPredicate? = nil, context: NSManagedObjectContext) -> Int {
        return allObjects(matchingPredicate: predicate, context: context).count
    }
    
    public static func rxAllObjects(matchingPredicate predicate: NSPredicate? = nil, sorted: [NSSortDescriptor]? = nil, fetchLimit: Int? = nil, context: NSManagedObjectContext) -> Observable<[FetchableType]> {
        
        return Observable.create({ (observer) -> Disposable in
            
            let r: NSFetchRequest<FetchableType> = NSFetchRequest(entityName: entityName())
            r.predicate = predicate
            r.sortDescriptors = sorted ?? defaultSortDescriptor()
            
            if let fetchLimit = fetchLimit {
                r.fetchLimit = fetchLimit
            }
            
            let container = FetchRequestContainer<FetchableType>(fetchRequest: r, context: context, observer: observer)
            
            return Disposables.create {
                container.dispose()
            }
        })
    }
    
    public static func rxMonitorChanges(_ context: NSManagedObjectContext) -> Observable<(inserted:[FetchableType], updated:[FetchableType], deleted: [FetchableType])> {
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
}

private final class FetchRequestContainer<T: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate {
    
    fileprivate var bag: DisposeBag? = DisposeBag()
    fileprivate var currentValues:[T] = []
    fileprivate var fetchRequest: NSFetchRequest<T>
    fileprivate var fetchedResultsController: NSFetchedResultsController<T>
    
    fileprivate let context: NSManagedObjectContext
    fileprivate let observer: AnyObserver<[T]>
    
    init(fetchRequest: NSFetchRequest<T>, context: NSManagedObjectContext, observer: AnyObserver<[T]>) {
        
        self.fetchRequest = fetchRequest
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        
        self.context = context
        self.observer = observer
        
        super.init()
        
        fetchedResultsController.delegate = self
        performFetch()
    }
    
    func dispose() {
        fetchedResultsController.delegate = nil
        bag = nil
    }
    
    fileprivate func performFetch() {
        
        try? fetchedResultsController.performFetch()
        let objects = fetchedResultsController.fetchedObjects ?? []
        observer.onNext(objects)
    }
    
    @objc func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let objects = fetchedResultsController.fetchedObjects ?? []
        observer.onNext(objects)
    }
}

