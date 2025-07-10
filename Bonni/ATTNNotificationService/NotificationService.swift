//
//  NotificationService.swift
//  ATTNNotificationService
//
//  Created by Adela Gao on 7/7/25.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
        contentHandler(request.content)
        return
    }
    self.bestAttemptContent = bestAttemptContent
    guard let imageURLString = bestAttemptContent.userInfo["attentive_image_url"] as? String,
          let imageURL = URL(string: imageURLString) else {
        contentHandler(bestAttemptContent)
        return
    }
    downloadImageAttachment(from: imageURL) { attachment in
        if let attachment = attachment {
            bestAttemptContent.attachments = [attachment]
        }
        contentHandler(bestAttemptContent)
    }
  }

  private func downloadImageAttachment(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
URLSession.shared.downloadTask(with: url) { downloadedUrl, _, _ in
   guard let downloadedUrl else {
       completion(nil)
       return
   }

   let fileExtension = url.pathExtension.isEmpty ? "tmp" : url.pathExtension
   let tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
   let uniqueName = UUID().uuidString + "." + fileExtension
   let tmpFileURL = tmpDirectory.appendingPathComponent(uniqueName)

   do {
       try FileManager.default.moveItem(at: downloadedUrl, to: tmpFileURL)
       let attachment = try UNNotificationAttachment(identifier: "image", url: tmpFileURL, options: nil)
       completion(attachment)
   } catch {
       completion(nil)
   }
}.resume()
  }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
