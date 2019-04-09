//
//  Createable.swift
//  CoreDataExtensio
//
//  Created by Georg Kitz on 09.04.19.
//  Copyright © 2019 meisterwork GmbH. All rights reserved.
//

import Foundation
import CoreData

public protocol Createable {
    associatedtype CreatedType: NSManagedObject
    static func create(in context: NSManagedObjectContext) -> CreatedType
}
