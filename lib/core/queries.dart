// Auth
const String kLogin = r'''
mutation Login($email: String!, $password: String!) {
  login(email: $email, password: $password) {
    token
    user { id name username email followerCount followingCount }
  }
}
''';

const String kRegister = r'''
mutation Register($email: String!, $password: String!, $name: String!, $username: String!) {
  register(email: $email, password: $password, name: $name, username: $username) {
    token
    user { id name username email }
  }
}
''';

const String kMe = r'''
query Me {
  me { id name username email followerCount followingCount voiceBioPath }
}
''';

// Feed
const String kFeed = r'''
query Feed($page: Int!) {
  feed(page: $page) {
    id audioPath duration waveform topic playsCount insertedAt
    repliesCount echoCount feltCount
    user { id name username }
  }
}
''';

const String kClip = r'''
query Clip($id: ID!) {
  clip(id: $id) {
    id audioPath duration waveform topic playsCount insertedAt
    repliesCount echoCount feltCount parentId
    user { id name username }
  }
}
''';

const String kReact = r'''
mutation React($clipId: ID!, $type: String!) {
  react(clipId: $clipId, type: $type) {
    reacted echoCount feltCount
  }
}
''';

const String kCreateClip = r'''
mutation CreateClip($audioData: String!, $duration: Int, $topic: String, $parentId: ID) {
  createClip(audioData: $audioData, duration: $duration, topic: $topic, parentId: $parentId) {
    id audioPath topic insertedAt
    user { id name username }
  }
}
''';

// Profile
const String kUser = r'''
query User($username: String!) {
  user(username: $username) {
    id name username email followerCount followingCount isFollowing voiceBioPath
  }
}
''';

const String kUserClips = r'''
query UserClips($username: String!) {
  userClips(username: $username) {
    id audioPath duration topic playsCount insertedAt echoCount feltCount repliesCount
    user { id name username }
  }
}
''';

const String kFollow = r'''
mutation Follow($username: String!) { follow(username: $username) }
''';

const String kUnfollow = r'''
mutation Unfollow($username: String!) { unfollow(username: $username) }
''';

// Search
const String kSearch = r'''
query Search($q: String!) {
  search(q: $q) {
    users { id name username }
    clips { id audioPath topic insertedAt user { id name username } }
  }
}
''';

// Discover
const String kDiscover = r'''
query Discover($topic: String) {
  discover(topic: $topic) {
    id audioPath duration topic playsCount insertedAt echoCount feltCount repliesCount
    user { id name username }
  }
}
''';
