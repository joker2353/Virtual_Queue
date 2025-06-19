const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Cloud Function that sends Firebase Cloud Messaging notifications
 * Triggered when a new document is created in the 'notifications' collection
 */
exports.sendQueueNotification = functions.firestore
    .document('notifications/{notificationId}')
    .onCreate(async (snapshot, context) => {
        try {
            const notificationData = snapshot.data();
            
            // Check if we have all the required fields
            if (!notificationData.token || !notificationData.payload) {
                console.error('Notification missing required fields:', notificationData);
                await snapshot.ref.update({
                    'status': 'error',
                    'error': 'Missing required fields',
                    'sentAt': admin.firestore.FieldValue.serverTimestamp()
                });
                return;
            }

            const token = notificationData.token;
            const payload = notificationData.payload;
            
            // Ensure we have a title and body in the data payload
            // This ensures messages can be shown even when app is terminated
            const dataPayload = payload.data || {};
            if (payload.notification) {
                // Add notification content to data payload for terminated app
                dataPayload.title = payload.notification.title || 'Virtual Queue';
                dataPayload.body = payload.notification.body || 'You have a new notification';
            }
            
            // Send the message
            const response = await admin.messaging().send({
                token: token,
                notification: payload.notification,
                data: Object.fromEntries(
                    Object.entries(dataPayload).map(([key, value]) => [key, String(value)])
                ),
                android: {
                    priority: 'high',
                    notification: {
                        channelId: 'high_importance_channel',
                        priority: 'high',
                        visibility: 'public',
                        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                    },
                    // Direct boot aware flag for terminated notifications
                    directBootOk: true
                },
                apns: {
                    headers: {
                        'apns-priority': '10', // High priority
                    },
                    payload: {
                        aps: {
                            contentAvailable: true,
                            sound: 'default',
                            // Enable critical alert for terminated app
                            badge: 1,
                            category: 'QUEUE_UPDATE'
                        }
                    }
                }
            });
            
            console.log('Successfully sent notification:', response);
            
            // Update the notification status
            await snapshot.ref.update({
                'status': 'sent',
                'messageId': response,
                'sentAt': admin.firestore.FieldValue.serverTimestamp()
            });
            
            return;
        } catch (error) {
            console.error('Error sending notification:', error);
            
            // Update the document with the error
            await snapshot.ref.update({
                'status': 'error',
                'error': error.message,
                'sentAt': admin.firestore.FieldValue.serverTimestamp()
            });
            
            return;
        }
    });

/**
 * Clean up old notifications (older than 30 days)
 * Runs once per day at midnight
 */
exports.cleanupOldNotifications = functions.pubsub
    .schedule('0 0 * * *')
    .timeZone('UTC')
    .onRun(async (context) => {
        const cutoff = Date.now() - (30 * 24 * 60 * 60 * 1000); // 30 days ago
        
        // Find old notifications
        const snapshot = await admin.firestore()
            .collection('notifications')
            .where('sentAt', '<', new Date(cutoff))
            .get();
            
        if (snapshot.empty) {
            console.log('No old notifications to delete');
            return;
        }
        
        // Delete them in batches
        const batch = admin.firestore().batch();
        let count = 0;
        
        snapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
            count++;
        });
        
        await batch.commit();
        console.log(`Deleted ${count} old notifications`);
        
        return;
    }); 