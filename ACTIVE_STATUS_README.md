# Active Status Feature

This feature adds WhatsApp-like active status functionality to your messaging system. Users can see when their friends are online and when they were last active.

## Features

### 1. Real-time Online Status
- Green dot indicator shows when a user is currently online
- Grey dot shows when a user is offline
- Status updates in real-time across all users

### 2. Last Seen Information
- Shows "Online" for currently active users
- Shows "Just now" for users active within the last minute
- Shows "X minutes ago" for users active within the last hour
- Shows "X hours ago" for users active within the last day
- Shows "X days ago" for users active within the last week
- Shows date for users inactive for more than a week

### 3. Automatic Status Management
- Automatically sets user as online when app opens
- Automatically sets user as offline when app closes or goes to background
- Updates last active timestamp every minute while app is running
- Cleans up status when user logs out

## Implementation Details

### Files Added/Modified

1. **`lib/services/user_status_service.dart`** - Core service for managing user status
2. **`lib/widgets/user_status_widget.dart`** - UI components for displaying status
3. **`lib/screens/messages_screen.dart`** - Updated to show status in messages list and chat
4. **`lib/screens/home_screen.dart`** - Added lifecycle management
5. **`lib/screens/login_screen.dart`** - Initialize status on login
6. **`lib/screens/signup_screen.dart`** - Initialize status on signup
7. **`lib/screens/profile_screen.dart`** - Cleanup status on logout

### Database Structure

The feature uses a new Firestore collection called `user_status`:

```javascript
user_status/{userId} {
  isOnline: boolean,
  lastSeen: timestamp,
  lastActive: timestamp
}
```

### UI Components

1. **UserStatusIndicator** - Small circular indicator (green/grey dot)
2. **UserStatusText** - Text showing "Online" or last seen time
3. **UserStatusWidget** - Full widget with dot and text

## Usage

### In Messages List
- Each user's avatar shows a status indicator dot
- User name shows status text (Online/Last seen)

### In Chat Screen
- Friend's avatar in app bar shows status indicator
- Friend's name shows status text below it

### Automatic Updates
- Status updates automatically when users open/close the app
- Real-time updates when users become active/inactive
- Periodic updates every minute while app is running

## Privacy Considerations

- Users can see when their friends are online
- Last seen information is available to all friends
- Status is automatically managed (no manual control)
- Status is cleaned up when user logs out

## Future Enhancements

1. **Privacy Settings** - Allow users to hide their online status
2. **Custom Status** - Allow users to set custom status messages
3. **Status History** - Track status changes over time
4. **Push Notifications** - Notify when friends come online
5. **Status Filters** - Filter messages by online status

## Testing

To test the feature:

1. Login with two different accounts on different devices/simulators
2. Open the messages screen on both devices
3. You should see each other's online status
4. Close one app and check if the other shows "offline" status
5. Reopen the app and verify status changes to "online"

## Troubleshooting

- If status doesn't update, check Firebase connection
- If status shows incorrectly, verify app lifecycle events
- If status persists after logout, check cleanup method
- If status doesn't show for new users, verify initialization 