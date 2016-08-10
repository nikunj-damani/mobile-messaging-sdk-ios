//
//  MobileMessaging.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//
//

import Foundation
import MMAFNetworking

public final class MobileMessaging: NSObject {
	//MARK: Public
	/**
	Starts a new Mobile Messaging session. This method should be called form AppDelegate's `application(_:didFinishLaunchingWithOptions:)` callback.
	- remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
	- parameter userNotificationType: Preferable notification types that indicating how the app alerts the user when a  push notification arrives.
	- parameter applicationCode: The application code of your Application from Push Portal website.
	- parameter backendBaseURL: Your backend server base URL, optional parameter. Default is http://oneapi.infobip.com.
	*/
	public class func startWithNotificationType(userNotificationType: UIUserNotificationType, applicationCode: String, backendBaseURL: String) {
		MobileMessagingInstance.start(userNotificationType, applicationCode: applicationCode, storageType: .SQLite, remoteAPIBaseURL: backendBaseURL)
	}
	
	public class func startWithNotificationType(userNotificationType: UIUserNotificationType, applicationCode: String) {
		startWithNotificationType(userNotificationType, applicationCode: applicationCode, backendBaseURL: MMAPIValues.kProdBaseURLString)
	}
	
	/**
	Stops current Mobile Messaging session.
	*/
	public class func stop(cleanUpData: Bool = false) {
		if cleanUpData {
			MobileMessagingInstance.sharedInstance.cleanUpAndStop()
		} else {
			MobileMessagingInstance.sharedInstance.stop()
		}
	}
	
	/**
	This method handles a new APNs device token and updates user's registration on the server. This method should be called form AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
	- parameter token: A token that identifies a particular device to APNs.
	*/
	public class func didRegisterForRemoteNotificationsWithDeviceToken(token: NSData) {
		MobileMessagingInstance.sharedInstance.didRegisterForRemoteNotificationsWithDeviceToken(token)
	}
	
	/**
	This method handles incoming remote notifications and triggers sending procedure for delivery reports. The method should be called from AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback.
	- parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	- parameter fetchCompletionHandler: A block to execute when the download operation is complete. The block is originally passed to AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback as a `fetchCompletionHandler` parameter. Mobile Messaging will execute this block after sending notification's delivery report.
	*/
	public class func didReceiveRemoteNotification(userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
		MobileMessagingInstance.sharedInstance.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
			completionHandler?(.NewData)
		})

		if UIApplication.sharedApplication().applicationState == .Inactive {
			notificationTapHandler?(userInfo)
		}
	}
	
	/**
	This method handles actions of interactive notification and triggers procedure for performing operations that are defined for this action. The method should be called from AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` and `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callbacks.
	
	- parameter identifier: The identifier associated with the action of interactive notification.
	- parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	- parameter responseInfo: The data dictionary sent by the action.
	- parameter completionHandler: The block to execute when specified action performing finished. The block is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` and `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callbacks as a `completionHandler` parameter. Mobile Messaging will execute this block after performing all actions.
    */
	public class func handleActionWithIdentifier(identifier: String?, userInfo: [NSObject : AnyObject], responseInfo: [NSObject : AnyObject]?, completionHandler: (Void -> Void)?) {
		MMMessage.performAction(identifier, userInfo: userInfo, responseInfo: responseInfo, completionHandler: completionHandler)
	}
	
	/**
	Logging utility is used for:
	- setting up logging options and logging levels.
	- obtaining a path to the logs file, in case the Logging utility is set up to log in file (logging options contains `.File` option).
	*/
	public class var loggingUtil: MMLoggingUtil? {
		return MobileMessagingInstance.sharedInstance.loggingUtil
	}
	
	/**
	Maintains attributes related to the current application installation such as APNs device token, badge number, etc.
	*/
	public class var currentInstallation: MMInstallation? {
		return MobileMessagingInstance.sharedInstance.currentInstallation
	}
	
	/**
	Maintains attributes related to the current user such as unique ID for the registered user, email, MSISDN, custom data, external id.
	*/
	public class var currentUser: MMUser? {
		return MobileMessagingInstance.sharedInstance.currentUser
	}
    
    /**
	This method sets seen status for messages and sends a corresponding request to the server. If something went wrong, the library will repeat the request until it reaches the server.
	- parameter messageIds: Array of identifiers of messages that need to be marked as seen.
    */
    public class func setSeen(messageIds: [String]) {
        MobileMessagingInstance.sharedInstance.setSeen(messageIds)
    }
	
	//FIXME: MOMEssage should be replaced with something lighter
	/**
	This method sends mobile originated messages to the server.
	- parameter messages: Array of objects of `MOMessage` class that need to be sent.
	- parameter completion: The block to execute after the server responded, passes an array of `MOMessage` messages, that cont
	*/
	public class func sendMessages(messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MobileMessagingInstance.sharedInstance.sendMessages(messages, completion: completion)
	}
	
	/**
	A boolean variable that indicates whether the library will be sending the carrier information to the server.
	Default value is `false`.
    */
	public static var carrierInfoSendingDisabled: Bool = false
	
	/**
	A boolean variable that indicates whether the library will be sending the system information such as OS version, device model, application version to the server.
	Default value is `false`.
	*/
	public static var systemInfoSendingDisabled: Bool = false
	
	/**
	A block object to be executed when user opens the app by tapping on the notification alert. This block takes a single NSDictionary that contains information related to the notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	*/
	public static var notificationTapHandler: (([NSObject : AnyObject]) -> Void)?
	
	/**
	//TODO: docs
	*/
	public static var geoNotificationsDisabled: Bool = false {
		didSet {
			MMRegionMonitoringManager.sharedInstance.locationManagerEnabled = !geoNotificationsDisabled
		}
	}
}

class MobileMessagingInstance {
	//MARK: Internal
	static var sharedInstance = MobileMessagingInstance()
	
	func cleanUpAndStop() {
		MMLogInfo("Cleaning up MobileMessaging service...")
		MobileMessagingInstance.queue.executeSync {
			self.storage?.drop()
			self.stop()
		}
	}
	
	func stop() {
		MMLogInfo("Stopping MobileMessaging service...")
		if UIApplication.sharedApplication().isRegisteredForRemoteNotifications() {
			UIApplication.sharedApplication().unregisterForRemoteNotifications()
		}
		MobileMessagingInstance.queue.executeSync {
			self.storage = nil
			self.currentInstallation = nil
			self.appListener = nil
			self.messageHandler = nil
		}
	}
	
	func didReceiveRemoteNotification(userInfo: [NSObject : AnyObject], newMessageReceivedCallback: ([NSObject : AnyObject] -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		MMLogDebug("New remote notification received \(userInfo)")
		MobileMessagingInstance.queue.executeAsync {
			self.messageHandler?.handleAPNSMessage(userInfo, newMessageReceivedCallback: newMessageReceivedCallback, completion: completion)
		}
	}
	
	func didRegisterForRemoteNotificationsWithDeviceToken(token: NSData, completion: (NSError? -> Void)? = nil) {
		MMLogInfo("Application did register with device token \(token.mm_toHexString)")
		NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationDeviceTokenReceived, userInfo: [MMNotificationKeyDeviceToken: token.mm_toHexString])
		MobileMessagingInstance.queue.executeAsync {
			self.currentInstallation?.updateDeviceToken(token, completion: completion)
		}
	}
	
	func setSeen(messageIds: [String], completion: (MMSeenMessagesResult -> Void)? = nil) {
		MMLogDebug("Setting seen status: \(messageIds)")
		MobileMessagingInstance.queue.executeAsync {
			self.messageHandler?.setSeen(messageIds, completion: completion)
		}
	}
	
	func sendMessages(messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MMLogDebug("Sending mobile originated messages...")
		MobileMessagingInstance.queue.executeAsync {
			self.messageHandler?.sendMessages(messages, completion: completion)
		}
	}
	
	static func start(userNotificationType: UIUserNotificationType, applicationCode: String, storageType: MMStorageType, remoteAPIBaseURL: String, completion: (Void -> Void)? = nil) {
		MMLogInfo("Starting MobileMessaging service...")
		MobileMessagingInstance.queue.executeAsync {
			do {
				var storage: MMCoreDataStorage?
				switch storageType {
				case .InMemory:
					storage = try MMCoreDataStorage.newInMemoryStorage()
				case .SQLite:
					storage = try MMCoreDataStorage.SQLiteStorage()
				}
				if let storage = storage {
					MobileMessagingInstance.sharedInstance.storage = storage
					let installation = MMInstallation(storage: storage, baseURL: remoteAPIBaseURL, applicationCode: applicationCode)
					MobileMessagingInstance.sharedInstance.currentInstallation = installation
					let user = MMUser(installation: installation)
					MobileMessagingInstance.sharedInstance.currentUser = user
					let messageHandler = MMMessageHandler(storage: storage, baseURL: remoteAPIBaseURL, applicationCode: applicationCode)
					MobileMessagingInstance.sharedInstance.messageHandler = messageHandler
					MobileMessagingInstance.sharedInstance.appListener = MMApplicationListener(messageHandler: messageHandler, installation: installation, user: user)
					
					MMRegionMonitoringManager.sharedInstance.startMonitoringCampaignsRegions()
					
					MMLogInfo("MobileMessaging SDK service successfully initialized.")
				}
			} catch {
				MMLogError("Unable to initialize Core Data stack. MobileMessaging SDK service stopped because of the fatal error.")
			}
			
			let categories = MMNotificationCategoryManager.categoriesToRegister()
			UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: userNotificationType, categories: categories))
			if UIApplication.sharedApplication().isRegisteredForRemoteNotifications() == false {
				UIApplication.sharedApplication().registerForRemoteNotifications()
			}
		}
	}
	
	//MARK: Private
	private static var queue: MMQueueObject = MMQueue.Serial.New.MobileMessagingSingletonQueue.queue
	private var valuesStorage = [NSObject: AnyObject]()
	private init() {
		self.loggingUtil = MMLoggingUtil()
	}
	
	private func setValue(value: AnyObject?, forKey key: String) {
		MobileMessagingInstance.queue.executeAsync {
			self.valuesStorage[key] = value
		}
	}
	
	private func valueForKey(key: String) -> AnyObject? {
		var result: AnyObject?
		MobileMessagingInstance.queue.executeSync {
			result = self.valuesStorage[key]
		}
		return result
	}
	
	private(set) var storage: MMCoreDataStorage? {
		get { return self.valueForKey("storage") as? MMCoreDataStorage }
		set { self.setValue(newValue, forKey: "storage") }
	}
	
	private(set) var currentInstallation: MMInstallation? {
		get { return self.valueForKey("currentInstallation") as? MMInstallation }
		set { self.setValue(newValue, forKey: "currentInstallation") }
	}
	
	private(set) var currentUser: MMUser? {
		get { return self.valueForKey("currentUser") as? MMUser }
		set { self.setValue(newValue, forKey: "currentUser") }
	}
	
	private(set) var appListener: MMApplicationListener? {
		get { return self.valueForKey("appListener") as? MMApplicationListener }
		set { self.setValue(newValue, forKey: "appListener") }
	}
	
	private(set) var messageHandler: MMMessageHandler? {
		get { return self.valueForKey("messageHandler") as? MMMessageHandler }
		set { self.setValue(newValue, forKey: "messageHandler") }
	}
	
	private(set) var alertTapHandler: (Void -> Void)?
	
	private(set) var loggingUtil : MMLoggingUtil
}