# Email/Password + GitHub Auth Design

**Date**: 2026-03-05
**Status**: Approved

## Summary

Add email/password sign-up (with required SMS 2FA) and GitHub OAuth sign-in to the Odyssey iOS app. Currently the app only supports Apple and Google OAuth via Clerk. All new flows use existing ClerkKit SDK APIs — no new dependencies.

## Decisions

- **2FA policy**: Required for all email/password users (set up during sign-up)
- **Sign-up order**: Email/password → verify email → add phone → verify phone
- **Sign-in 2FA**: Inline step (same view transitions to code entry)
- **Forgot Password**: Included (email code → new password)
- **Architecture**: Enum-driven step state within views (Approach 1 — inline steps)

## AuthManager Changes

Expand `AuthStrategy`:
```swift
enum AuthStrategy {
    case apple
    case google
    case github
    case emailPassword
}
```

New methods:
- `signUpWithEmail(email:password:) async throws -> SignUp` — creates Clerk sign-up
- `signInWithPassword(email:password:) async throws -> SignIn` — returns SignIn (may need 2FA)
- `signIn(strategy: .github)` — `Clerk.shared.auth.signInWithOAuth(provider: .github)`
- `setupPhone2FA(phoneNumber:) async throws -> PhoneNumber` — adds phone, sends code
- `verifyPhone2FA(phone:code:) async throws` — verifies phone, reserves for 2FA
- `completeSignIn(_ signIn:)` — shared helper for final state transition

GitHub OAuth in `signIn(strategy:)`:
```swift
case .github:
    try await Clerk.shared.auth.signInWithOAuth(provider: .github)
```

## Sign-Up Flow (new `EmailSignUpView`)

Step enum:
```swift
enum EmailSignUpStep {
    case credentials    // email + password
    case verifyEmail    // 6-digit email code
    case addPhone       // phone number
    case verifyPhone    // 6-digit SMS code
}
```

1. **Credentials**: Email field, password field, "Create Account" button. Client-side validation. Calls `authManager.signUpWithEmail()`, auto-sends email code, advances.
2. **Verify Email**: "Check your email" + 6-digit code field + "Resend" link. Calls `signUp.verifyEmailCode()`. User is now authenticated → advances.
3. **Add Phone**: Phone number field with country prefix. Calls `authManager.setupPhone2FA()`, advances.
4. **Verify Phone**: 6-digit SMS code field + "Resend" link. Calls `authManager.verifyPhone2FA()`. Phone reserved for 2FA. Done.

Parent view detects `authManager.isSignedIn` change to show recovery key / dismiss.

## Sign-In Flow (updated `SignInView`)

Step enum:
```swift
enum SignInStep {
    case chooseMethod       // all OAuth + email option
    case emailPassword      // email + password fields
    case verify2FA          // SMS code
    case forgotPassword     // email field
    case resetVerifyCode    // 6-digit email code
    case resetNewPassword   // new password fields
}
```

**Choose Method** — four buttons:
1. Continue with Apple (existing)
2. Continue with Google (existing)
3. Continue with GitHub (new)
4. Sign in with Email (new → advances to emailPassword step)

**Email/Password** — email + password fields, "Sign In" button, "Forgot Password?" link. If `signIn.status == .needsSecondFactor` → advance to verify2FA. If `.complete` → done.

**2FA Code** — "Enter code sent to your phone", 6-digit field, verify button.

**Forgot Password** — email field → sends reset code → verify code → new password → may still need 2FA.

## BackupPromptModal Changes

Add to `signUpView` section:
- "Sign up with Email" button → pushes `EmailSignUpView` in existing NavigationStack
- "Continue with GitHub" button → `authManager.signUp(strategy: .github)`

Existing Apple/Google buttons remain. Recovery key flow unchanged.

## ClerkKit APIs Used

| Operation | API |
|-----------|-----|
| Email sign-up | `Clerk.shared.auth.signUp(emailAddress:password:)` |
| Send email code | `signUp.sendEmailCode()` |
| Verify email code | `signUp.verifyEmailCode(code)` |
| Add phone | `user.createPhoneNumber(number)` |
| Send phone code | `phone.sendCode()` |
| Verify phone code | `phone.verifyCode(code)` |
| Reserve for 2FA | `phone.setReservedForSecondFactor()` |
| GitHub OAuth | `Clerk.shared.auth.signInWithOAuth(provider: .github)` |
| Password sign-in | `Clerk.shared.auth.signInWithPassword(identifier:password:)` |
| Send MFA SMS | `signIn.sendMfaPhoneCode()` |
| Verify MFA | `signIn.verifyMfaCode(code, type: .phoneCode)` |
| Reset password email | `signIn.sendResetPasswordEmailCode()` |
| Verify reset code | `signIn.verifyCode(code)` |
| Set new password | `signIn.resetPassword(newPassword:)` |

## Files Changed

| File | Change |
|------|--------|
| `Odyssey/Services/Auth/AuthManager.swift` | Add strategies, new methods |
| `Odyssey/Views/Auth/SignInView.swift` | Rewrite with step enum, email/password + 2FA + forgot password |
| `Odyssey/Views/Auth/BackupPromptModal.swift` | Add Email and GitHub buttons |
| **New**: `Odyssey/Views/Auth/EmailSignUpView.swift` | Full sign-up flow |

No new dependencies. No changes to AccountView, OdysseyApp, or data layer.

## Clerk Dashboard Requirements

For these flows to work, the Clerk dashboard must have enabled:
- Email/password authentication strategy
- Phone number (SMS) as second factor
- GitHub OAuth provider configured with client ID/secret
