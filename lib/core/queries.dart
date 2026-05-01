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
    repliesCount clipType echoOfId locationName promptId
    user { id name username }
  }
}
''';

const String kFollowingFeed = r'''
query FollowingFeed {
  followingFeed {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount clipType echoOfId locationName promptId
    user { id name username }
  }
}
''';

const String kEmberFeed = r'''
query EmberFeed {
  emberFeed {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount clipType echoOfId locationName promptId
    user { id name username }
  }
}
''';

const String kClip = r'''
query Clip($id: ID!) {
  clip(id: $id) {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount parentId clipType echoOfId echoIntroPath echoIntroDuration locationName promptId
    user { id name username }
    echoOf {
      id audioPath duration waveform topic mood
      user { id name username }
    }
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

// Suggested users to follow (for empty Following tab)
const String kSuggestedUsers = r'''
query SuggestedUsers {
  search(q: "") {
    users { id name username voiceBioPath isEmbers }
  }
}
''';

// ── New feature queries ─────────────────────────────────────────────────────

// Mood feed
const String kMoodFeed = r'''
query MoodFeed($mood: String!, $limit: Int) {
  moodFeed(mood: $mood, limit: $limit) {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount clipType
    user { id name username }
  }
}
''';

// Ambient feed
const String kAmbientFeed = r'''
query AmbientFeed($limit: Int) {
  ambientFeed(limit: $limit) {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount clipType locationName
    user { id name username }
  }
}
''';

// Daily prompt
const String kTodayPrompt = r'''
query TodayPrompt {
  todayPrompt {
    id text category activeDate responseCount
  }
}
''';

const String kRecentPrompts = r'''
query RecentPrompts($days: Int) {
  recentPrompts(days: $days) {
    id text category activeDate responseCount
  }
}
''';

const String kPromptResponses = r'''
query PromptResponses($promptId: ID!, $limit: Int) {
  promptResponses(promptId: $promptId, limit: $limit) {
    id audioPath duration waveform topic mood playsCount insertedAt expiresAt hasPulsed
    repliesCount promptId
    user { id name username }
  }
}
''';

// Create clip with new fields (ambient, prompt response)
const String kCreateClipExtended = r'''
mutation CreateClipExtended($audioUrl: String!, $cloudinaryPublicId: String!, $waveformData: [Float!]!, $durationSeconds: Int!, $category: String!, $mood: String, $circleId: ID, $clipType: String, $locationName: String, $latitude: Float, $longitude: Float, $promptId: ID) {
  createClip(audioUrl: $audioUrl, cloudinaryPublicId: $cloudinaryPublicId, waveformData: $waveformData, durationSeconds: $durationSeconds, category: $category, mood: $mood, circleId: $circleId, clipType: $clipType, locationName: $locationName, latitude: $latitude, longitude: $longitude, promptId: $promptId) {
    id audioPath topic clipType insertedAt
    user { id name username }
  }
}
''';

// Echo
const String kCreateEcho = r'''
mutation CreateEcho($echoOfId: ID!, $introAudioUrl: String!, $introCloudinaryPublicId: String!, $introWaveformData: [Float!], $introDurationSeconds: Int) {
  createEcho(echoOfId: $echoOfId, introAudioUrl: $introAudioUrl, introCloudinaryPublicId: $introCloudinaryPublicId, introWaveformData: $introWaveformData, introDurationSeconds: $introDurationSeconds) {
    id audioPath clipType echoOfId echoIntroPath echoIntroDuration
    user { id name username }
    echoOf {
      id audioPath duration waveform topic mood
      user { id name username }
    }
  }
}
''';

// Voice threads
const String kMyThreads = r'''
query MyThreads {
  myThreads {
    id title clipCount isComplete insertedAt
    user { id name username }
    clips {
      id audioPath duration waveform threadPosition insertedAt
      user { id name username }
    }
  }
}
''';

const String kThreadFeed = r'''
query ThreadFeed($limit: Int) {
  threadFeed(limit: $limit) {
    id title clipCount isComplete insertedAt
    user { id name username }
    clips {
      id audioPath duration waveform threadPosition insertedAt
      user { id name username }
    }
  }
}
''';

const String kCreateVoiceThread = r'''
mutation CreateVoiceThread($title: String) {
  createVoiceThread(title: $title) {
    id title clipCount
  }
}
''';

const String kAddToThread = r'''
mutation AddToThread($threadId: ID!, $audioUrl: String!, $cloudinaryPublicId: String!, $waveformData: [Float!], $durationSeconds: Int, $mood: String) {
  addToThread(threadId: $threadId, audioUrl: $audioUrl, cloudinaryPublicId: $cloudinaryPublicId, waveformData: $waveformData, durationSeconds: $durationSeconds, mood: $mood) {
    id clipCount
    clips {
      id audioPath duration waveform threadPosition
      user { id name username }
    }
  }
}
''';

const String kCompleteThread = r'''
mutation CompleteThread($threadId: ID!) {
  completeThread(threadId: $threadId) {
    id isComplete clipCount
  }
}
''';

// Campfires
const String kActiveCampfires = r'''
query ActiveCampfires($circleId: ID) {
  activeCampfires(circleId: $circleId) {
    id title maxParticipants isActive participantCount circleId insertedAt
    starter { id name username }
    participants { id name username }
  }
}
''';

const String kStartCampfire = r'''
mutation StartCampfire($title: String, $circleId: ID, $maxParticipants: Int) {
  startCampfire(title: $title, circleId: $circleId, maxParticipants: $maxParticipants) {
    id title maxParticipants isActive participantCount
    starter { id name username }
    participants { id name username }
  }
}
''';

const String kJoinCampfire = r'''
mutation JoinCampfire($campfireId: ID!) {
  joinCampfire(campfireId: $campfireId) {
    id title participantCount
    participants { id name username }
  }
}
''';

const String kLeaveCampfire = r'''
mutation LeaveCampfire($campfireId: ID!) {
  leaveCampfire(campfireId: $campfireId)
}
''';

const String kEndCampfire = r'''
mutation EndCampfire($campfireId: ID!) {
  endCampfire(campfireId: $campfireId)
}
''';
