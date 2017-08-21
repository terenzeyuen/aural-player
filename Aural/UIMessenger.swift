import Cocoa

/*
    Messenger for synchronous message delivery. All messages are dispatched directly from the publisher to the subscriber, via this messenger, synchronously, on the same (calling) thread. For example: When the player starts playing back a new track, it messages the playlist for it to update the playlist selection to match the new playing track.
 */
class SyncMessenger {
    
    // Keeps track of subscribers. For each message type, stores a list of subscribers
    private static var subscriberRegistry: [MessageType: [MessageSubscriber]] = [MessageType: [MessageSubscriber]]()
    
    // Called by a subscriber who is interested in a certain type of message
    static func subscribe(_ messageType: MessageType, subscriber: MessageSubscriber) {
        
        let subscribers = subscriberRegistry[messageType]
        if (subscribers == nil) {
            subscriberRegistry[messageType] = [MessageSubscriber]()
        }
        
        subscriberRegistry[messageType]?.append(subscriber)
    }
    
    // Called by a publisher to publish a message
    static func publishMessage(_ message: Message) {
        
        let messageType = message.messageType
        let subscribers = subscriberRegistry[messageType]
        
        if (subscribers != nil) {
            for subscriber in subscribers! {
                
                // Notify the subscriber
                subscriber.consumeMessage(message)
            }
        }
    }
}
