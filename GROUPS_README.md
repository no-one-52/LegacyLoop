# Facebook-like Group System

This feature implements a comprehensive group system similar to Facebook, with admin approval for both member joining and post publishing.

## 🎯 Features

### 1. Group Creation & Management
- **Create Groups**: Users can create groups with name, description, cover image, and category
- **Privacy Settings**: Public (anyone can join) or Private (admin approval required)
- **Group Categories**: Technology, Sports, Music, Movies, Books, Travel, Food, Fashion, Business, Education, Health, Fitness, Art, Photography, Gaming, Other

### 2. Member Management
- **Join Groups**: Users can join public groups directly or request to join private groups
- **Admin Approval**: Group admins can approve/reject member requests for private groups
- **Member Roles**: Admin (creator) and Member (approved users)
- **Leave Groups**: Members can leave groups at any time

### 3. Post System with Admin Approval
- **Create Posts**: Members can create text and image posts in groups
- **Post Approval**: All posts require admin approval before appearing in the group feed
- **Admin Controls**: Admins can approve or reject posts
- **Post Status**: Pending, Approved, or Rejected

### 4. Group Discovery
- **My Groups**: View groups you're a member of
- **Discover**: Search for groups by name or description
- **Popular Groups**: Browse groups sorted by member count
- **Search**: Real-time search functionality

### 5. Admin Features
- **Member Management**: Approve/reject member requests
- **Post Moderation**: Approve/reject posts
- **Group Settings**: Update group information (admin only)
- **Group Deletion**: Delete groups (admin only)

## 🗂️ Database Structure

### Groups Collection
```javascript
groups/{groupId} {
  name: string,
  description: string,
  isPrivate: boolean,
  coverImageUrl: string?,
  category: string?,
  createdBy: string (userId),
  createdAt: timestamp,
  memberCount: number,
  postCount: number
}
```

### Group Members Collection
```javascript
group_members/{membershipId} {
  groupId: string,
  userId: string,
  role: 'admin' | 'member' | 'pending',
  joinedAt: timestamp,
  approvedAt: timestamp?
}
```

### Group Posts Collection
```javascript
group_posts/{postId} {
  groupId: string,
  content: string,
  imageUrl: string?,
  authorId: string,
  createdAt: timestamp,
  status: 'pending' | 'approved' | 'rejected',
  approvedBy: string? (admin userId),
  approvedAt: timestamp?
}
```

## 📱 UI Components

### 1. Groups Screen (`groups_screen.dart`)
- **Tabs**: My Groups, Discover, Popular
- **Search**: Real-time group search
- **Create Button**: Quick access to group creation
- **Group Cards**: Display group info with join buttons

### 2. Create Group Screen (`create_group_screen.dart`)
- **Form Fields**: Name, description, category
- **Cover Image**: Upload group cover photo
- **Privacy Toggle**: Public vs Private group
- **Validation**: Required fields and length limits

### 3. Group Detail Screen (`group_detail_screen.dart`)
- **Tabs**: About, Posts, Members
- **Group Info**: Cover image, name, description, stats
- **Join/Leave**: Action buttons for membership
- **Admin Controls**: Post approval, member management

### 4. Group Service (`group_service.dart`)
- **CRUD Operations**: Create, read, update, delete groups
- **Member Management**: Join, leave, approve, reject
- **Post Management**: Create, approve, reject posts
- **Search & Discovery**: Find groups and popular groups

## 🔄 User Flow

### Creating a Group
1. User taps "+" button in Groups screen
2. Fills out group creation form
3. Chooses privacy settings (public/private)
4. Uploads optional cover image
5. Group is created with user as admin

### Joining a Group
1. User discovers group in search or popular tabs
2. Taps "Join Group" button
3. **Public Group**: Immediately becomes member
4. **Private Group**: Request sent to admin for approval

### Posting in a Group
1. Member navigates to group detail screen
2. Taps post creation button
3. Writes content and optionally adds image
4. Post is submitted with "pending" status
5. Admin reviews and approves/rejects post
6. Approved posts appear in group feed

### Admin Moderation
1. Admin views pending members/posts in respective tabs
2. Reviews each request/post
3. Approves or rejects with one tap
4. Approved items become visible to all members

## 🎨 UI/UX Features

### Visual Design
- **Material Design**: Consistent with app theme
- **Color Scheme**: Purple theme (`#7B1FA2`)
- **Icons**: Intuitive icons for all actions
- **Cards**: Clean card-based layout

### User Experience
- **Real-time Updates**: Live updates using Firestore streams
- **Loading States**: Proper loading indicators
- **Error Handling**: User-friendly error messages
- **Confirmation Dialogs**: For destructive actions
- **Success Feedback**: SnackBar notifications

### Navigation
- **Tab Navigation**: Easy switching between sections
- **Breadcrumb Navigation**: Clear navigation hierarchy
- **Back Navigation**: Standard back button behavior

## 🔒 Privacy & Security

### Group Privacy
- **Public Groups**: Visible to all users, anyone can join
- **Private Groups**: Only visible to members, admin approval required
- **Member Privacy**: Member lists visible to group members only

### Content Moderation
- **Post Approval**: All posts require admin approval
- **Admin Controls**: Only admins can approve/reject content
- **Content Filtering**: Admins can remove inappropriate content

### Data Security
- **Firestore Rules**: Proper security rules for group data
- **User Authentication**: All operations require authentication
- **Permission Checks**: Server-side validation of user permissions

## 🚀 Getting Started

### Prerequisites
- Firebase project with Firestore enabled
- Firebase Storage for image uploads
- Proper Firestore security rules

### Installation
1. Add the group service to your project
2. Include the group screens in your navigation
3. Update your app's navigation to include the Groups tab
4. Configure Firebase Storage rules for group images

### Usage
1. **Create Groups**: Users can create groups from the Groups tab
2. **Join Groups**: Discover and join groups from the Discover tab
3. **Post Content**: Members can create posts that require approval
4. **Moderate**: Admins can manage members and approve posts

## 🔧 Configuration

### Firebase Storage Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /group_covers/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /group_posts/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /groups/{groupId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /group_members/{membershipId} {
      allow read, write: if request.auth != null;
    }
    match /group_posts/{postId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## 🎯 Future Enhancements

### Planned Features
1. **Group Invitations**: Invite friends to groups
2. **Group Events**: Create and manage group events
3. **Group Polls**: Create polls within groups
4. **Group Files**: Share files in groups
5. **Group Analytics**: Admin dashboard with group statistics
6. **Group Categories**: More detailed categorization
7. **Group Rules**: Custom rules and guidelines
8. **Group Moderation Tools**: Advanced moderation features

### Technical Improvements
1. **Caching**: Implement local caching for better performance
2. **Push Notifications**: Notify users of group activities
3. **Image Optimization**: Better image compression and loading
4. **Offline Support**: Basic offline functionality
5. **Search Improvements**: Advanced search with filters

## 🐛 Troubleshooting

### Common Issues
1. **Posts not appearing**: Check if posts are approved by admin
2. **Can't join group**: Verify group privacy settings
3. **Image upload fails**: Check Firebase Storage permissions
4. **Real-time updates not working**: Verify Firestore connection

### Debug Tips
1. Check Firebase console for errors
2. Verify user authentication status
3. Test with different user accounts
4. Check network connectivity
5. Review Firestore security rules

## 📞 Support

For issues or questions about the group system:
1. Check the Firebase console for errors
2. Review the service logs
3. Test with different user scenarios
4. Verify all dependencies are properly configured

The group system is now fully integrated and ready for use! 🎉 