//
//  TodoExtension.swift
//  CoreData
//
//  Created by Matteo Maselli on 10/11/14.
//  Copyright (c) 2014 Matteo Maselli. All rights reserved.
//

import Foundation
import CoreData
import UIKit

extension NSManagedObject {

    struct Stack {
        static var objects: [NSManagedObject] = []
    }
    
    class func initWithDocument(entityName: String, block: (context: NSManagedObjectContext, entity: NSEntityDescription) -> ()){
        
        var insideBlock = { () -> () in
            let context = ManagedDocument.Status.context
            let entity = NSEntityDescription.entityForName(entityName, inManagedObjectContext: context!)
            block(context: context!, entity: entity!)
        }
        
        ManagedDocument.checkDocument(insideBlock)
    }
    
    func save() {
        
        let saveBlock = { () -> () in
            var error: NSError?
            if let context = self.managedObjectContext {
                context.save(&error)
                if error != nil {
                    println("Error on save context in save method error: \(error!.localizedDescription)")
                } else {
                    NSManagedObject.Stack.objects.append(self)
                    NSNotificationCenter.defaultCenter().postNotificationName("didSaveNSManagedObject", object: self)
                }
            } else {
                println("Error on call save without initialization")
            }
        }
        
        ManagedDocument.checkDocument(saveBlock)
    }
    
    class func find(entityName: String,predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil, completionHandler: (results: [NSManagedObject]?) -> ()) {
        
        let findBlock = { () -> () in
            let backgroundContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
            backgroundContext.parentContext = ManagedDocument.Status.context
            
            backgroundContext.performBlock({ () -> Void in
                let fetchRequest: NSFetchRequest = NSFetchRequest(entityName: entityName)
                var error: NSError?
                
                if predicate != nil {
                    fetchRequest.predicate = predicate!
                }
                
                if sortDescriptors != nil {
                    fetchRequest.sortDescriptors = sortDescriptors
                }
                
                let results = backgroundContext.executeFetchRequest(fetchRequest, error: &error)
                if error != nil {
                    println("Error on fetching request, error: \(error!.localizedDescription)")
                } else {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        if results != nil {
                            var list: [NSManagedObject] = []
                            for obj in results! {
                                let item: NSManagedObject? = ManagedDocument.objectWithID(obj.objectID)
                                if item != nil {
                                    list.append(item!)
                                }
                            }
                            completionHandler(results: list)
                        }
                    })
                }
            })
        }
        
        ManagedDocument.checkDocument(findBlock)
    }
    
    func destroy(){
        
        var destroyBlock = { () -> () in
            if let context = self.managedObjectContext {
                context.deleteObject(self)
                var error: NSError?
                context.save(&error)
                if error != nil {
                    println("Error on destroy operation: \(error!.localizedDescription)")
                }
            } else {
                println("Error on call destroy")
            }
        }
        
        ManagedDocument.checkDocument(destroyBlock)
    }
}