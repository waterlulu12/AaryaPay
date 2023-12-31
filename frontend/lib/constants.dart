const backendBase = "https://arpandaze.tech/v1";

const fileServerBase = "https://arpandaze.tech/profile";

const serverKeyPair =
    "fzAng9P5nxQCaxh4+sExTCdRI2++KmwBRKohfBJ8RuuD5sb/gfzu1BrFiJeGJudEOwAp1ZVekbVwWrLmRlzu1g==";

enum TAMStatus {
  clicked,
  other,
  initiated,
  generated,
  completed,
  interrupted,
}

enum AuthenticationStatus {
  unknown,
  loggedIn,
  logOut,
  none,
  twoFA,
  onLogOutProcess,
  error,
  loaded,
}

enum VerificationStatus {
  unknown,
  initial,
  verified,
  unverified,
  twofa,
  error,
}

enum FAStatus {
  initiated,
  onprocess,
  success,
  faliure,
  unknown,
}

enum MessageType {
  idle,
  neutral,
  warning,
  error,
  success,
}

enum LoginStatus {
  initial,
  onprocess,
  success,
  faliure,
}

enum ForgotStatus {
  initial,
  error,
  success,
  onprocess,
  otpOnProcess,
  otpSuccess,
}

enum ImageType {
  circle,
  rectangle,
  initial,
}
