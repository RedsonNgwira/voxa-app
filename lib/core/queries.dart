// Auth
const String kLogin = r'''
mutation Login($email: String!, $password: String!) {
  login(email: $email, password: $password) {
    token
    user { id name username isEmbers voiceBioPath onboarded }
  }
}
''';

const String kRegister = r'''
mutation Register($email: String!, $password: String!, $name: String!, $username: String!) {
  register(email: $email, password: $password, name: $name, username: $username) {
    token
    user { id name username }
  }
}
''';

const String kMe = r'''
query Me {
  me { id name username isEmbers voiceBioPath onboarded emberFeedExpiresAt }
}
''';

const String kFeed = r'''
query Feed {
  feed {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount
    user { id name username }
  }
}
''';

const String kFollowingFeed = r'''
query FollowingFeed {
  followingFeed {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount
    user { id name username }
  }
}
''';

const String kEmberFeed = r'''
query EmberFeed {
  emberFeed {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount
    user { id name username }
  }
}
''';

const String kClip = r'''
query Clip($id: ID!) {
  clip(id: $id) {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount parentId
    user { id name username }
    replies {
      id audioPath duration waveform insertedAt isWhisper hasPulsed playsCount repliesCount
      user { id name username }
    }
  }
}
''';

// Pulse — anonymous, no count (RULE_003)
const String kPulse = r'''
mutation Pulse($postId: ID!) {
  pulse(postId: $postId) { pulsed }
}
''';

// Preserve post (Embers only)
const String kPreservePost = r'''
mutation PreservePost($id: ID!) {
  preservePost(id: $id) { id expiresAt }
}
''';

const String kCreateClip = r'''
mutation CreateClip($audioUrl: String!, $cloudinaryPublicId: String!, $waveformData: [Float!]!, $durationSeconds: Int!, $category: String!, $mood: String, $circleId: ID) {
  createClip(audioUrl: $audioUrl, cloudinaryPublicId: $cloudinaryPublicId, waveformData: $waveformData, durationSeconds: $durationSeconds, category: $category, mood: $mood, circleId: $circleId) {
    id audioPath topic insertedAt
    user { id name username }
  }
}
''';

const String kDeleteClip = r'''
mutation DeleteClip($id: ID!) {
  deleteClip(id: $id)
}
''';

// Replies / Whispers
const String kCreateReply = r'''
mutation CreateReply($postId: ID!, $audioUrl: String!, $cloudinaryPublicId: String!, $waveformData: [Float!]!, $durationSeconds: Int!, $isWhisper: Boolean!) {
  createReply(postId: $postId, audioUrl: $audioUrl, cloudinaryPublicId: $cloudinaryPublicId, waveformData: $waveformData, durationSeconds: $durationSeconds, isWhisper: $isWhisper) {
    id audioPath isWhisper
    user { id name username }
  }
}
''';

// Profile — no follower counts (RULE_001)
const String kUser = r'''
query User($username: String!) {
  user(username: $username) {
    id name username isFollowing voiceBioPath voiceBioWaveform isEmbers
  }
}
''';

const String kUserClips = r'''
query UserClips($username: String!) {
  userClips(username: $username) {
    id audioPath duration topic playsCount insertedAt expiresAt hasPulsed repliesCount waveform
    user { id name username }
  }
}
''';

// Follow takes userId not username
const String kFollow = r'''
mutation Follow($userId: ID!) { follow(userId: $userId) }
''';

const String kUnfollow = r'''
mutation Unfollow($userId: ID!) { unfollow(userId: $userId) }
''';

// Voice bio
const String kSaveVoiceBio = r'''
mutation SaveVoiceBio($audioUrl: String!, $waveformData: [Float!]!) {
  saveVoiceBio(audioUrl: $audioUrl, waveformData: $waveformData) {
    id voiceBioPath voiceBioWaveform
  }
}
''';

// FCM token
const String kRegisterFcmToken = r'''
mutation RegisterFcmToken($token: String!) {
  registerFcmToken(token: $token)
}
''';

// Search
const String kSearch = r'''
query Search($q: String!) {
  search(q: $q) {
    users { id name username }
    clips { id audioPath duration waveform topic playsCount insertedAt expiresAt hasPulsed repliesCount user { id name username } }
  }
}
''';

// Discover — mood + category, recency sorted (RULE_010)
const String kDiscover = r'''
query Discover($topic: String, $mood: String) {
  discover(topic: $topic, mood: $mood) {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed repliesCount
    user { id name username }
  }
}
''';

// Circles
const String kMyCircles = r'''
query MyCircles {
  myCircles {
    id name isPrivate memberCount
    members { id name username }
    posts { id insertedAt }
  }
}
''';

const String kCircle = r'''
query Circle($id: ID!) {
  circle(id: $id) {
    id name isPrivate memberCount
    members { id name username }
    posts {
      id audioPath duration waveform topic playsCount insertedAt expiresAt hasPulsed repliesCount
      user { id name username }
    }
  }
}
''';

const String kCreateCircle = r'''
mutation CreateCircle($name: String!, $isPrivate: Boolean) {
  createCircle(name: $name, isPrivate: $isPrivate) { id name isPrivate memberCount }
}
''';

const String kJoinCircle = r'''
mutation JoinCircle($circleId: ID!) {
  joinCircle(circleId: $circleId) { id name memberCount }
}
''';

const String kLeaveCircle = r'''
mutation LeaveCircle($circleId: ID!) {
  leaveCircle(circleId: $circleId)
}
''';

// Notifications
const String kNotifications = r'''
query Notifications {
  notifications {
    id type message relatedPostId insertedAt
  }
}
''';
