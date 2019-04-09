//
//  Createable.swift
//  CoreDataExtensio
//
//  Created by Georg Kitz on 09.04.19.
//  Copyright © 2019 Georg Kitz. All rights reserved.
//

import Foundation
import CoreData

protocol Createable {
    associatedtype CreatedType: NSManagedObject
    static func create(in context: NSManagedObjectContext) -> CreatedType
}
