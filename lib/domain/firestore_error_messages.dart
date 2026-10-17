/// Maps Firestore / Cloud Functions error codes to readable messages.
String firestoreErrorMessage(String code) {
  switch (code) {
    case 'permission-denied':
      return 'You are not allowed to do this';
    case 'not-found':
      return 'This item no longer exists';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'The service is unreachable. Check your connection and try again';
    case 'unauthenticated':
      return 'Your session has expired. Please log in again';
    default:
      return 'Something went wrong. Please try again';
  }
}
