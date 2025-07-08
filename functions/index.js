/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

exports.deleteUserAndData = functions.https.onCall(async (data, context) => {
  console.log('deleteUserAndData function called');
  console.log('Context:', context);
  console.log('Context auth:', context.auth);
  console.log('Data:', data);
  
  // Only allow admins to call this function
  if (!context.auth) {
    console.log('No authentication found');
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
  }

  const adminUid = context.auth.uid;
  console.log('Admin UID:', adminUid);
  const db = admin.firestore();

  // Check if user is admin by looking up their document in Firestore
  const adminDoc = await db.collection("users").doc(adminUid).get();
  console.log('Admin document exists:', adminDoc.exists);
  
  if (!adminDoc.exists) {
    console.log('Admin document not found in Firestore');
    throw new functions.https.HttpsError("permission-denied", "Admin user not found in database.");
  }
  
  const adminData = adminDoc.data();
  console.log('Admin data:', adminData);
  console.log('Is admin:', adminData.isAdmin);
  
  if (!adminData.isAdmin) {
    console.log('User is not an admin');
    throw new functions.https.HttpsError("permission-denied", "Only admins can delete users.");
  }

  const { userId } = data;
  if (!userId) {
    throw new functions.https.HttpsError("invalid-argument", "userId is required.");
  }

  console.log('Deleting user:', userId);

  try {
    // Get user data before deletion
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "User not found.");
    }

    const userData = userDoc.data();
    console.log('User data to delete:', userData);

    // Delete all user's posts
    const postsSnapshot = await db.collection("posts").where("userId", "==", userId).get();
    const postDeletions = postsSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(postDeletions);
    console.log(`Deleted ${postsSnapshot.docs.length} posts`);

    // Delete all user's comments
    const commentsSnapshot = await db.collection("comments").where("userId", "==", userId).get();
    const commentDeletions = commentsSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(commentDeletions);
    console.log(`Deleted ${commentsSnapshot.docs.length} comments`);

    // Delete all user's group posts
    const groupPostsSnapshot = await db.collection("groupPosts").where("userId", "==", userId).get();
    const groupPostDeletions = groupPostsSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(groupPostDeletions);
    console.log(`Deleted ${groupPostsSnapshot.docs.length} group posts`);

    // Delete all user's likes
    const likesSnapshot = await db.collection("likes").where("userId", "==", userId).get();
    const likeDeletions = likesSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(likeDeletions);
    console.log(`Deleted ${likesSnapshot.docs.length} likes`);

    // Delete all user's notifications
    const notificationsSnapshot = await db.collection("notifications").where("userId", "==", userId).get();
    const notificationDeletions = notificationsSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(notificationDeletions);
    console.log(`Deleted ${notificationsSnapshot.docs.length} notifications`);

    // Delete all user's messages
    const messagesSnapshot = await db.collection("messages").where("userId", "==", userId).get();
    const messageDeletions = messagesSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(messageDeletions);
    console.log(`Deleted ${messagesSnapshot.docs.length} messages`);

    // Delete all user's status updates
    const statusSnapshot = await db.collection("userStatus").where("userId", "==", userId).get();
    const statusDeletions = statusSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(statusDeletions);
    console.log(`Deleted ${statusSnapshot.docs.length} status updates`);

    // Remove user from all groups
    const groupsSnapshot = await db.collection("groups").get();
    const groupUpdates = [];
    for (const groupDoc of groupsSnapshot.docs) {
      const groupData = groupDoc.data();
      if (groupData.members && groupData.members.includes(userId)) {
        const updatedMembers = groupData.members.filter(memberId => memberId !== userId);
        groupUpdates.push(groupDoc.ref.update({ members: updatedMembers }));
      }
    }
    await Promise.all(groupUpdates);
    console.log(`Removed user from ${groupUpdates.length} groups`);

    // Delete all friend relationships
    const friendsSnapshot = await db.collection("friends").where("userId", "==", userId).get();
    const friendDeletions = friendsSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(friendDeletions);
    console.log(`Deleted ${friendsSnapshot.docs.length} friend relationships`);

    // Delete all friend requests
    const requestsSnapshot = await db.collection("friendRequests").where("userId", "==", userId).get();
    const requestDeletions = requestsSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(requestDeletions);
    console.log(`Deleted ${requestsSnapshot.docs.length} friend requests`);

    // Delete the user document
    await db.collection("users").doc(userId).delete();
    console.log('Deleted user document');

    // Delete user from Firebase Auth
    try {
      await admin.auth().deleteUser(userId);
      console.log('Deleted user from Firebase Auth');
    } catch (authError) {
      console.log('Error deleting from Auth (user might not exist):', authError.message);
    }

    // Log the deletion for audit
    await db.collection("adminLogs").add({
      action: "deleteUser",
      adminUid: adminUid,
      adminEmail: adminData.email,
      targetUserId: userId,
      targetUserEmail: userData.email,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: {
        postsDeleted: postsSnapshot.docs.length,
        commentsDeleted: commentsSnapshot.docs.length,
        groupPostsDeleted: groupPostsSnapshot.docs.length,
        likesDeleted: likesSnapshot.docs.length,
        notificationsDeleted: notificationsSnapshot.docs.length,
        messagesDeleted: messagesSnapshot.docs.length,
        statusUpdatesDeleted: statusSnapshot.docs.length,
        groupsRemovedFrom: groupUpdates.length,
        friendRelationshipsDeleted: friendsSnapshot.docs.length,
        friendRequestsDeleted: requestsSnapshot.docs.length
      }
    });

    console.log('User deletion completed successfully');
    return { success: true, message: "User and all related data deleted successfully" };

  } catch (error) {
    console.error('Error deleting user:', error);
    throw new functions.https.HttpsError("internal", "Failed to delete user: " + error.message);
  }
});
