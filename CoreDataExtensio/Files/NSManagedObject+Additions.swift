//
//  NSManagedObject+Additions.swift
//  meisterwork
//
//  Created by Georg Kitz on 12/02/16.
//  Copyright © 2019 meisterwork GmbH. All rights reserved.
//

import Foundation
import CoreData

public extension NSManagedObject {
    
    /**
        Returns the entity's name
     */
    class func entityName() -> String {
        let fullClassName = NSStringFromClass(object_getClass(self)!)
        let nameComponents = fullClassName.components(separatedBy: ".")
        return nameComponents.last!
    }

    
    /**
        Returns the entity's core data description
     */
    class func entityDescription(_ context: NSManagedObjectContext) -> NSEntityDescription {
        let name = self.entityName()
        return NSEntityDescription.entity(forEntityName: name, in: context)!
    }
    
    
    /**
        Convenience Init
     */
    convenience init(inContext context: NSManagedObjectContext) {
        let t = type(of: self)
        let entity = t.entityDescription(context)
        self.init(entity: entity, insertInto: context)
    }
}
