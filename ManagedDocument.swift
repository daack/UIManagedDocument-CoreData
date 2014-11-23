//
//  ManagedDocument.swift
//  CoreData
//
//  Created by Matteo Maselli on 10/11/14.
//  Copyright (c) 2014 Matteo Maselli. All rights reserved.
//

import Foundation
import CoreData
import UIKit

/*  Managed Document
    
    Public:
        Status [struct]:
            ready (Bool) true if document is open and state is normal
            state (UIDocumentState) the actual state of the document
            context (NSManagedObjectContext) the context of the document
            modelUrl (NSURL) where the active document is

        setDocument [class function]
            function to open/create the document

        checkDocument(complitionHandler: (() -> ())? = nil) [class function]
            takes a block (optional) -> check the state of the document -> and perform the block at the end in the main queue

        objectWithID(NSManagedObjectID) [class function]
            return the NSManagedObject if there is the ID in the actual context
 */

class ManagedDocument: NSObject {
    
    struct Status {
        static var ready: Bool = false
        static let modelUrl: NSURL = Const.url.URLByAppendingPathComponent(Const.modelPath)
        static var state: UIDocumentState? {
            get{
                return Global.document?.documentState
            }
        }
        static var context: NSManagedObjectContext? {
            get{
                return Global.document?.managedObjectContext
            }
        }
    }
    
    //Global variable for this class that handle the completion handler to perform and the document
    private struct Global {
        
        //Global UIManagedDocument
        static var document: UIManagedDocument?
       
        //Block to perform when the document is ready
        static var comletionHandler: (() -> ())?
    }
    
    //Constatnt for the class
    private struct Const {
        //!!SET these Variables!!
        //Path for Model
        static let modelPath: String = "Model"
        //iCloud Obiquitous Content set in your .entitlements file
        static let iCloudContainer = "myAppContainerMatMaselli2"
        
        //Helper Const
        
        //FileManager
        static let fileManager: NSFileManager = NSFileManager.defaultManager()
        //Document Directory
        static let documentDirectory = NSSearchPathDirectory.DocumentDirectory
        //Notification Center
        static let notificationCenter = NSNotificationCenter.defaultCenter()
        
        //URL
        static let url: NSURL = (fileManager.URLsForDirectory(documentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first as NSURL).URLByAppendingPathComponent(modelPath)
        
        //UIManagedDocument PersistentSoreOptions
        static let options = [ NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true, NSPersistentStoreUbiquitousContentNameKey: iCloudContainer ]

    }
    
    //MARK: - Document Methods
    
    //Instatntiate the document
    class func setDocument() {
        
        //Add an observer if the document change state
        Const.notificationCenter.addObserver(self, selector: "documentChangeState", name: UIDocumentStateChangedNotification, object: nil)
        
        Global.document = UIManagedDocument(fileURL: Status.modelUrl)
        
        //Set Document options
        Global.document!.persistentStoreOptions = Const.options
        
        self.addiCloudObserver()
        
        //Check if Document has been created in file path url
        if Const.fileManager.fileExistsAtPath(Status.modelUrl.path!) {
            self.openDocument()
        } else {
            var error: NSError?
            if error != nil {
                println("Error on creating database! onable to creat folder: \(error!.localizedDescription)")
            } else {
                self.createDocument()
            }
        }
    }
    
    private class func addiCloudObserver() {
        Const.notificationCenter.addObserverForName(NSPersistentStoreCoordinatorStoresWillChangeNotification, object: nil, queue: nil) { (note) -> Void in
        
        }
        
        Const.notificationCenter.addObserverForName(NSPersistentStoreCoordinatorStoresDidChangeNotification, object: nil, queue: nil) { (note) -> Void in
            println("--------- NSPersistentStoreCoordinatorStoresDidChangeNotification --------")
            
            if Status.context!.hasChanges {
                var error: NSError?
                Status.context!.save(&error)
                if error != nil {
                    println("Error on save context from iCloud")
                }
            } else {
                Status.context!.reset()
            }
            self.removeiCloudObserver()
        }
    }
    
    private class func removeiCloudObserver() {
        Const.notificationCenter.removeObserver(self, name: NSPersistentStoreCoordinatorStoresDidChangeNotification, object: nil)
        Const.notificationCenter.removeObserver(self, name: NSPersistentStoreCoordinatorStoresWillChangeNotification, object: nil)
    }
    
    class private func createDocument() {
        var error: NSError?
        Const.fileManager.createDirectoryAtURL(Const.url, withIntermediateDirectories: true, attributes: nil, error: &error)
        if Global.document != nil && error == nil {
            Global.document!.saveToURL(Status.modelUrl, forSaveOperation: UIDocumentSaveOperation.ForCreating)
                { (succed) -> Void in
                    if succed {
                        self.openDocument()
                    } else {
                        println("Error on Creating Document")
                    }
                }
        } else {
            println("Error on create document: \(error?.localizedDescription)")
        }
    }
    
    class private func openDocument() {
        if Global.document != nil {
            Global.document!.openWithCompletionHandler
                { (succed) -> Void in
                    if succed {
                        self.checkDocument()
                    } else {
                        println("Error on open the Document: \(Status.state)")
                        //self.moveModel()
                    }
                }
        } else {
            println("Invoking open document with globalDocument = nil")
        }
    }
    
    class func checkDocument(completionHandler: (() -> ())? = nil) {
        if let block = completionHandler {
            Global.comletionHandler = block
        }
        if Status.ready {
            if let handler = Global.comletionHandler {
                NSThread.isMainThread() ? handler() : dispatch_async(dispatch_get_main_queue(), handler)
            }
        } else {
            Const.notificationCenter.removeObserver(self, name: UIDocumentStateChangedNotification, object: nil)
            self.setDocument()
        }
    }
    
    //MARK: - Helper methods
    
    class func objectWithID(id: NSManagedObjectID) -> NSManagedObject? {
        
        if Const.fileManager.fileExistsAtPath(Status.modelUrl.path!) {
            if !Status.ready {
                println("The document is not ready")
                return nil
            }
            var error: NSError?
            let item = Status.context!.existingObjectWithID(id, error: &error)
            if error != nil {
                println("Error on retriving object with objectID")
                return nil
            } else {
                return item
            }
        } else {
            return nil
        }
    }
    
    //This function is call if the document is corrupt, and it moves the document in another folder
    class private func moveModel() {
        Const.notificationCenter.removeObserver(self, name: UIDocumentStateChangedNotification, object: nil)
        var error: NSError?
        let date = NSDate(timeIntervalSinceNow: 0.0)
        let errorFolder: String = date.description
        
        let newUrl: NSURL = Const.url.URLByAppendingPathComponent(errorFolder)
        Const.fileManager.moveItemAtURL(Status.modelUrl, toURL: newUrl, error: &error)
        
        if error != nil {
            println("Unable to move Model")
            self.allert("Errore sul Database", message: "L'attuale Database è inrimediabilmente corrotto, contattare l'amministratore")
        } else {
            self.allert("Errore sul Database", message: "L'attuale Database è corrotto, per recuperare i dati contattare l'amministratore")
            self.setDocument()
        }
        
    }
    
    //Selector for documentDidChangeState notification
    class func documentChangeState() {
        let state = Global.document!.documentState
        switch state {
        case UIDocumentState.Normal:
            Status.ready = true
            println("State Normal")
        case UIDocumentState.Closed:
            Status.ready = false
            println("State Closed")
        case UIDocumentState.EditingDisabled:
            Status.ready = false
            println("State Editing disabled")
        case UIDocumentState.InConflict:
            Status.ready = false
            println("State in Conflict")
        case UIDocumentState.allZeros:
            Status.ready = false
            println("State allZeroes")
        case UIDocumentState.SavingError:
            Status.ready = false
            println("State SavingError")
        default:
            Status.ready = false
            println("Stato \(state)")
        }
    }
    
    //Modal allert
    class private func allert(title: String, message: String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        let action = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
        alert.addAction(action)
        UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
}