//
//  CoreDataMappable.swift
//  CoreDataHelpers
//
//  Created by Georg Kitz on 10/09/2017.
//  Copyright © 2017 9Cookies Gmbh. All rights reserved.
//

import Foundation
import CoreData

// MARK: - Keys for xcdatamodeld
struct PropertyKeys {
    static let jsonKey = "map.key"
    static let transformerClass = "map.tra"
}

struct RelationKeys {
    static let relatedObjectDatabaseUniqueIdentifier = "map.o.id"
    static let relatedObjectJsonUniqueIdentifier = "map.j.id"
}


// MARK: - String extension for keypaths
extension String {
    
    var isKeyPath: Bool {
        return self.range(of: ".") != nil
    }
    
    var keyPathElements: [String] {
        return self.components(separatedBy: ".")
    }
}

// MARK: - JSON Value extraction which supports key paths
public typealias JSONDictionary = [String: AnyObject]
public func jsonValueForKey(_ key: String, fromJSON JSON: JSONDictionary) -> AnyObject? {
    if !key.isKeyPath {
        return JSON[key]
    }
    
    let keys = key.keyPathElements
    var updatedJSON = JSON
    
    for idx in 0..<keys.count - 1 {
        
        let key = keys[idx]
        if let newJSON = updatedJSON[key] as? JSONDictionary {
            updatedJSON = newJSON
        }
    }
    
    return updatedJSON[keys.last!]
}


// MARK: - Extensions to NSPropertyDescription
extension NSPropertyDescription {
    
    var jsonKey: String {
        
        if let userInfo = userInfo, let value = userInfo[PropertyKeys.jsonKey] as? String {
            return value
        }
        return name
    }
    
    var jsonTransformer: ValueTransformer? {
        if let userInfo = userInfo, let value = userInfo[PropertyKeys.transformerClass] as? String {
            
            let app = NSStringFromClass(AppDelegate.self).components(separatedBy: ".").first!
            let className = "\(app).\(value)"
            let aClass = NSClassFromString(className) as! ValueTransformer.Type
            return aClass.init()
        }
        return nil
    }
}

// MARK: - Extensions to NSRelationshipDescription
extension NSRelationshipDescription {
    
    var relatedObjectDatabaseUIDKey: String {
        if let userInfo = userInfo, let value = userInfo[RelationKeys.relatedObjectDatabaseUniqueIdentifier] as? String {
            return value
        }
        
        return ""
    }
    
    var relatedObjectJsonUIDKey: String {
        if let userInfo = userInfo, let value = userInfo[RelationKeys.relatedObjectJsonUniqueIdentifier] as? String {
            return value
        }
        
        return relatedObjectDatabaseUIDKey
    }
}

// MARK: - Extensions to NSManageObject
extension NSManagedObject {
    
    /**
     Updates a core data item with a given json in a specific context
     - parameter JSON: the JSON we want to use for the update
     - parameter context: the managed context we want this changes to happen in
     */
    func updateFromJSON(_ JSON: JSONDictionary, context: NSManagedObjectContext) {
        
        var ignoreProperties = false
        if let updatedValue = JSON["updated"] as? String, let jsonUpdatedTimestamp = StringToISO8601DateTransfomer().typedTransformedValue(updatedValue), let entityUpdatedTimestamp = value(forKey: "updatedTimestamp") as? Date, jsonUpdatedTimestamp.timeIntervalSince1970 == entityUpdatedTimestamp.timeIntervalSince1970 {
            ignoreProperties = true
        }
        
        if (!ignoreProperties) {
            updatePropertiesFromJSON(JSON)
        }
        
        updateRelationshipsFromJSON(JSON, context: context)
    }
    
    /**
     Loads an identity with a given uid key and the value for this key, if it can't be found it will insert a new object
     - parameter key: the uid key in the database for this object
     - parameter value: the value we use for the fetchRequest
     - parameter entityDescription: the entityDescription we use to create the object
     - parameter context: the context we want this to happen
     - returns: the managed object we were looking for
     */
    class func loadOrInsertEntity(_ key: String, value: AnyObject, entityDescription: NSEntityDescription, context: NSManagedObjectContext) -> Self {
        
        /**
         Found this internal hack here http://stackoverflow.com/questions/25271208/cast-to-typeofself
         */
        func _loadOrInsertEntity<T> (_ key: String, value: AnyObject, entityDescription: NSEntityDescription, context: NSManagedObjectContext) -> T where T: NSManagedObject {
            
            let request: NSFetchRequest<T> = NSFetchRequest(entityName: entityDescription.name!)
            request.predicate = NSPredicate(format: "%K = %@", key, value as! NSObject)
            
            var entity = try! context.fetch(request).first
            
            if entity == nil {
                
                entity = (NSManagedObject(entity: entityDescription, insertInto: context) as! T)
                if (entityDescription.propertiesByName.keys.contains("createdTimestamp")) {
                    entity?.setValue(Date(), forKey: "createdTimestamp")
                }
                
                if (entityDescription.propertiesByName.keys.contains("updatedTimestamp")) {
                    entity?.setValue(Date(), forKey: "updatedTimestamp")
                }
            }
            
            return entity!
        }
        
        return _loadOrInsertEntity(key, value: value, entityDescription: entityDescription, context: context)
    }
    
    
    /**
     Convenience method for the other `loadOrInsertEntity(...)` method
     */
    class func loadOrInsertEntity(_ key: String, value: AnyObject, context: NSManagedObjectContext) -> Self {
        return loadOrInsertEntity(key, value: value, entityDescription: entityDescription(context), context: context)
    }
    
    
    /**
     Updates properties of the object with the data which can be found in the json.
     if there is no value in the json for the property nothing happens, if we find `null`
     we earase set the value of the property to nil, otherwise to the correct value
     -parameter JSON: the JSON we want to use for the upate
     */
    fileprivate func updatePropertiesFromJSON(_ JSON: JSONDictionary) {
        
        let properties = self.entity.propertiesByName.filter { !($0.1 is NSRelationshipDescription)}
        for (name, property) in properties {
            
            let jsonKey = property.jsonKey
            let transformer = property.jsonTransformer
            
            if let jsonValue = jsonValueForKey(jsonKey, fromJSON: JSON) {
                
                var value = jsonValue
                
                /// set property to nil if we encounter NSNull
                if value is NSNull {
                    
                    setNilValueForKey(name)
                    continue;
                }
                
                /// if we have a transformer, transform the value
                if let transformer = transformer {
                    
                    value = transformer.transformedValue(jsonValue)! as AnyObject
                }
                
                /// finally set the value
                setValuesForKeys([name: value])
            }
        }
    }
    
    /**
     Updates relationships of the object with the data which we find in the json.
     - parameter JSON: the json we want to update from
     - parameter context: the context in which we want to fetch existing relationship objects from or in which we want to insert new objects
     */
    fileprivate func updateRelationshipsFromJSON(_ JSON: JSONDictionary, context: NSManagedObjectContext) {
        /// Handle relationships
        let relationships = self.entity.relationshipsByName
        for (name, relationship) in relationships {
            
            let jsonRelationshipKey = relationship.jsonKey
            let databaseObjectKey = relationship.relatedObjectDatabaseUIDKey
            let jsonObjectKey = relationship.relatedObjectJsonUIDKey
            let entityDescription = relationship.destinationEntity!
            
            if relationship.isToMany {
                
                if let arrayJSON = JSON[jsonRelationshipKey] as? [JSONDictionary] {
                    
                    var set: Set<NSManagedObject> = Set()
                    
                    for entityJSON in arrayJSON {
                        if let entity = updateRelationShipEntity(entityJSON, jsonObjectKey: jsonObjectKey, databaseObjectKey: databaseObjectKey, entityDesription: entityDescription, context: context) {
                            set.insert(entity)
                        }
                    }
                    
                    setValuesForKeys([name: set])
                }
                
            } else {
                
                var entityJSON = JSON[jsonRelationshipKey] as? JSONDictionary
                if  entityJSON == nil {
                    
                    if let jsonValue = jsonValueForKey(jsonRelationshipKey, fromJSON: JSON) {
                        
                        /// set property to nil if we encounter NSNull
                        if jsonValue is NSNull {
                            
                            setNilValueForKey(name)
                            continue;
                        }
                        
                        entityJSON = [jsonObjectKey: jsonValue]
                    }
                }
                
                if let entityJSON = entityJSON,
                    let entity = updateRelationShipEntity(entityJSON, jsonObjectKey: jsonObjectKey, databaseObjectKey: databaseObjectKey, entityDesription: entityDescription, context: context) {
                    setValuesForKeys([name: entity])
                }
            }
        }
    }
    
    /**
     tries to update a entity in a relationship with a given json. if the entity can be found it's simply updated, if it can't be found we insert a new entity and update it
     - parameter entityJSON: the json we use for the update
     - parameter jsonObjectKey: is the key in the json which gives us the uid of this object
     - parameter databaseObjectKey: is the property which is used to identify the object in the database
     - parameter entityDescription: the entityDescription of the object
     - parameter context: the context we want this changes to happen in
     */
    fileprivate func updateRelationShipEntity(_ entityJSON: JSONDictionary, jsonObjectKey: String, databaseObjectKey: String, entityDesription: NSEntityDescription, context: NSManagedObjectContext) -> NSManagedObject? {
        
        if let uniqueValue = entityJSON[jsonObjectKey], jsonObjectKey.characters.count > 0 {
            
            let entity = NSManagedObject.loadOrInsertEntity(databaseObjectKey, value: uniqueValue, entityDescription: entityDesription, context: context)
            entity.updateFromJSON(entityJSON, context: context)
            
            return entity
        }
        
        return nil
    }
}

// MARK: - Transformers

/// Transfroms a String to Int
open class StringToIntTransformer: ValueTransformer {
    
    override open func transformedValue(_ value: Any?) -> Any? {
        
        if let value = value as? String {
            return Int(value)
        }
        
        return nil
    }
}

/// Transforms a Int to String
open class IntToStringTransformer: ValueTransformer {
    
    override open func transformedValue(_ value: Any?) -> Any? {
        
        if let value = value as? Int {
            return String(value)
        }
        
        return nil
    }
}

/// Transforms a ISO8601 String to NSDate
open class StringToISO8601DateTransfomer: ValueTransformer {
    
    override open func transformedValue(_ value: Any?) -> Any? {
        
        guard let value = value as? String else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
        
        if let date = dateFormatter.date(from: value) {
            return date
        }
        
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return dateFormatter.date(from: value)
    }
    
    open func typedTransformedValue(_ value: String) -> Date? {
        return transformedValue(value) as? Date
    }
}

/// Transforms a String to a DecimalNumber
open class StringToDecimalNumberTransformer: ValueTransformer {
    
    override open func transformedValue(_ value: Any?) -> Any? {
        
        guard let value = value as? String else {
            return nil
        }
        
        let formatter = NumberFormatter()
        formatter.generatesDecimalNumbers = true
        
        if let decimalNumber = formatter.number(from: value) {
            return decimalNumber
        }
        
        formatter.locale = Locale(identifier: "en-US")
        return formatter.number(from: value) ?? NSDecimalNumber()
    }
}
