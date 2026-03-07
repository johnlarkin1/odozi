# Email/Password + GitHub Auth Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add email/password sign-up (with required SMS 2FA), GitHub OAuth sign-in, and forgot-password flow to the Odyssey iOS app.

**Architecture:** Extend the existing `AuthManager` with new Clerk SDK methods for email/password and GitHub flows. Add enum-driven step state to `SignInView` (sign-in + forgot password) and a new `EmailSignUpView` (sign-up + 2FA setup). Update `BackupPromptModal` to offer all four auth methods.

**Tech Stack:** SwiftUI, ClerkKit (existing SPM dependency), `@Observable` pattern (iOS 17+)

---

### Task 1: Extend AuthManager with GitHub OAuth and email/password methods

**Files:**
- Modify: `Odyssey/Services/Auth/AuthManager.swift`

**Step 1: Add `.github` case to `AuthStrategy` enum**

At `Odyssey/Services/Auth/AuthManager.swift:5-8`, replace:
```swift
enum AuthStrategy {
    case apple
    case google
}
```
with:
```swift
enum AuthStrategy {
    case apple
    case google
    case github
}
```

**Step 2: Add `.github` case to `signIn(strategy:)` switch**

At `Odyssey/Services/Auth/AuthManager.swift:80-86`, inside the `do` block's switch statement, add the github case:
```swift
switch strategy {
case .apple:
    try await Clerk.shared.auth.signInWithApple()
case .google:
    try await Clerk.shared.auth.signInWithOAuth(provider: .google)
case .github:
    try await Clerk.shared.auth.signInWithOAuth(provider: .github)
}
```

**Step 3: Add new email/password and 2FA methods**

After the `signUp(strategy:)` method (line 107), add these new methods:

```swift
// MARK: - Email/Password Authentication

func signUpWithEmail(email: String, password: String) async throws -> ClerkKit.SignUp {
    guard Self.clerkConfigured else {
        throw AuthError.serverError("Clerk not configured")
    }

    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
        let signUp = try await Clerk.shared.auth.signUp(
            emailAddress: email,
            password: password
        )
        // Auto-send email verification code
        let updated = try await signUp.sendEmailCode()
        return updated
    } catch {
        self.error = error.localizedDescription
        throw error
    }
}

func signInWithPassword(email: String, password: String) async throws -> ClerkKit.SignIn {
    guard Self.clerkConfigured else {
        throw AuthError.serverError("Clerk not configured")
    }

    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
        let signIn = try await Clerk.shared.auth.signInWithPassword(
            identifier: email,
            password: password
        )

        if signIn.status == .complete {
            try await completeSignIn()
        }

        return signIn
    } catch {
        self.error = error.localizedDescription
        throw error
    }
}

func completeSignIn() async throws {
    guard let clerkUser = Clerk.shared.user else {
        throw AuthError.serverError("Sign-in succeeded but no user returned")
    }

    isSignedIn = true
    user = mapClerkUser(clerkUser)

    if let token = await refreshTokenIfNeeded() {
        try? KeychainService.storeAuthToken(token)
    }
}

// MARK: - Phone 2FA Setup

func setupPhone2FA(phoneNumber: String) async throws -> ClerkKit.PhoneNumber {
    guard let user = Clerk.shared.user else {
        throw AuthError.notAuthenticated
    }

    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
        let phone = try await user.createPhoneNumber(phoneNumber)
        let sent = try await phone.sendCode()
        return sent
    } catch {
        self.error = error.localizedDescription
        throw error
    }
}

func verifyPhone2FA(phone: ClerkKit.PhoneNumber, code: String) async throws {
    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
        let verified = try await phone.verifyCode(code)
        let _ = try await verified.setReservedForSecondFactor(reserved: true)
        try await verified.makeDefaultSecondFactor()
    } catch {
        self.error = error.localizedDescription
        throw error
    }
}

// MARK: - Password Reset

func sendPasswordResetCode(email: String) async throws -> ClerkKit.SignIn {
    guard Self.clerkConfigured else {
        throw AuthError.serverError("Clerk not configured")
    }

    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
        let signIn = try await Clerk.shared.auth.signIn(email)
        let prepared = try await signIn.sendResetPasswordEmailCode()
        return prepared
    } catch {
        self.error = error.localizedDescription
        throw error
    }
}
```

**Step 4: Build to verify compilation**

Run: `make build`
Expected: Build succeeds with no errors related to AuthManager.

**Step 5: Commit**

```bash
git add Odyssey/Services/Auth/AuthManager.swift
git commit -m "feat(auth): add email/password, GitHub OAuth, and 2FA methods to AuthManager"
```

---

### Task 2: Rewrite SignInView with step-based email/password, 2FA, and forgot password

**Files:**
- Modify: `Odyssey/Views/Auth/SignInView.swift`

**Step 1: Rewrite SignInView with step enum and all flows**

Replace the entire contents of `Odyssey/Views/Auth/SignInView.swift` with:

```swift
import SwiftUI
import ClerkKit

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    enum Step {
        case chooseMethod
        case emailPassword
        case verify2FA
        case forgotPassword
        case resetVerifyCode
        case resetNewPassword
    }

    @State private var step: Step = .chooseMethod
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var currentSignIn: ClerkKit.SignIn?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            switch step {
            case .chooseMethod:
                chooseMethodView
            case .emailPassword:
                emailPasswordView
            case .verify2FA:
                verify2FAView
            case .forgotPassword:
                forgotPasswordView
            case .resetVerifyCode:
                resetVerifyCodeView
            case .resetNewPassword:
                resetNewPasswordView
            }

            if authManager.isLoading {
                ProgressView()
            }

            if let error = authManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.coralRed)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                dismiss()
            }
        }
    }

    // MARK: - Choose Method

    private var chooseMethodView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentTeal)

            Text("Sign In")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                oauthButton(icon: "apple.logo", title: "Continue with Apple") {
                    Task { await performOAuth(strategy: .apple) }
                }

                oauthButton(icon: "globe", title: "Continue with Google") {
                    Task { await performOAuth(strategy: .google) }
                }

                oauthButton(icon: "cat.fill", title: "Continue with GitHub") {
                    Task { await performOAuth(strategy: .github) }
                }

                oauthButton(icon: "envelope.fill", title: "Sign in with Email") {
                    authManager.error = nil
                    step = .emailPassword
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Email/Password

    private var emailPasswordView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentTeal)

            Text("Sign In with Email")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)

            Button {
                Task { await performEmailSignIn() }
            } label: {
                Text("Sign In")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
            .padding(.horizontal, 24)

            Button("Forgot Password?") {
                authManager.error = nil
                code = ""
                newPassword = ""
                confirmPassword = ""
                step = .forgotPassword
            }
            .foregroundStyle(Color.accentTeal)
            .font(.subheadline)

            backButton { step = .chooseMethod }
        }
    }

    // MARK: - 2FA Verification

    private var verify2FAView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentTeal)

            Text("Two-Factor Authentication")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter the code sent to your phone")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("6-digit code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title3.monospaced())
                .padding()
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

            Button {
                Task { await verify2FACode() }
            } label: {
                Text("Verify")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(code.count < 6 || authManager.isLoading)
            .padding(.horizontal, 24)

            Button("Resend Code") {
                Task { await resend2FACode() }
            }
            .foregroundStyle(Color.accentTeal)
            .font(.subheadline)

            backButton { step = .emailPassword }
        }
    }

    // MARK: - Forgot Password

    private var forgotPasswordView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentAmber)

            Text("Reset Password")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your email to receive a reset code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

            Button {
                Task { await sendResetCode() }
            } label: {
                Text("Send Reset Code")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(email.isEmpty || authManager.isLoading)
            .padding(.horizontal, 24)

            backButton { step = .emailPassword }
        }
    }

    // MARK: - Reset Verify Code

    private var resetVerifyCodeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentTeal)

            Text("Check Your Email")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter the verification code sent to \(email)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("6-digit code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title3.monospaced())
                .padding()
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

            Button {
                Task { await verifyResetCode() }
            } label: {
                Text("Verify Code")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(code.count < 6 || authManager.isLoading)
            .padding(.horizontal, 24)

            Button("Resend Code") {
                Task { await sendResetCode() }
            }
            .foregroundStyle(Color.accentTeal)
            .font(.subheadline)

            backButton { step = .forgotPassword }
        }
    }

    // MARK: - New Password

    private var resetNewPasswordView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.rotation")
                .font(.system(size: 48))
                .foregroundStyle(Color.successGreen)

            Text("Set New Password")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)

            if !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword != confirmPassword {
                Text("Passwords don't match")
                    .font(.caption)
                    .foregroundStyle(Color.coralRed)
            }

            Button {
                Task { await resetPassword() }
            } label: {
                Text("Reset Password")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(newPassword.isEmpty || newPassword != confirmPassword || authManager.isLoading)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Actions

    private func performOAuth(strategy: AuthStrategy) async {
        do {
            try await authManager.signIn(strategy: strategy)
        } catch is CancellationError {
            // User cancelled OAuth sheet
        } catch {
            authManager.error = error.localizedDescription
        }
    }

    private func performEmailSignIn() async {
        do {
            let signIn = try await authManager.signInWithPassword(email: email, password: password)

            if signIn.status == .needsSecondFactor {
                currentSignIn = signIn
                // Auto-send SMS code
                let prepared = try await signIn.sendMfaPhoneCode()
                currentSignIn = prepared
                authManager.error = nil
                code = ""
                step = .verify2FA
            }
            // If .complete, completeSignIn() was already called in AuthManager
        } catch {
            // Error already set by AuthManager
        }
    }

    private func verify2FACode() async {
        guard let signIn = currentSignIn else { return }

        authManager.isLoading = true
        authManager.error = nil
        defer { authManager.isLoading = false }

        do {
            let result = try await signIn.verifyMfaCode(code, type: .phoneCode)
            if result.status == .complete {
                try await authManager.completeSignIn()
            }
        } catch {
            authManager.error = error.localizedDescription
        }
    }

    private func resend2FACode() async {
        guard let signIn = currentSignIn else { return }

        authManager.isLoading = true
        authManager.error = nil
        defer { authManager.isLoading = false }

        do {
            let prepared = try await signIn.sendMfaPhoneCode()
            currentSignIn = prepared
        } catch {
            authManager.error = error.localizedDescription
        }
    }

    private func sendResetCode() async {
        do {
            let signIn = try await authManager.sendPasswordResetCode(email: email)
            currentSignIn = signIn
            authManager.error = nil
            code = ""
            step = .resetVerifyCode
        } catch {
            // Error already set by AuthManager
        }
    }

    private func verifyResetCode() async {
        guard let signIn = currentSignIn else { return }

        authManager.isLoading = true
        authManager.error = nil
        defer { authManager.isLoading = false }

        do {
            let result = try await signIn.verifyCode(code)
            currentSignIn = result
            if result.status == .needsNewPassword {
                step = .resetNewPassword
            }
        } catch {
            authManager.error = error.localizedDescription
        }
    }

    private func resetPassword() async {
        guard let signIn = currentSignIn else { return }

        authManager.isLoading = true
        authManager.error = nil
        defer { authManager.isLoading = false }

        do {
            let result = try await signIn.resetPassword(newPassword: newPassword)
            currentSignIn = result

            if result.status == .needsSecondFactor {
                let prepared = try await result.sendMfaPhoneCode()
                currentSignIn = prepared
                code = ""
                step = .verify2FA
            } else if result.status == .complete {
                try await authManager.completeSignIn()
            }
        } catch {
            authManager.error = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func oauthButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button("Back") {
            authManager.error = nil
            action()
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }
}
```

**Step 2: Build to verify compilation**

Run: `make build`
Expected: Build succeeds. SignInView compiles with ClerkKit types.

**Step 3: Commit**

```bash
git add Odyssey/Views/Auth/SignInView.swift
git commit -m "feat(auth): rewrite SignInView with email/password, 2FA, GitHub, and forgot password flows"
```

---

### Task 3: Create EmailSignUpView with 4-step sign-up + 2FA setup

**Files:**
- Create: `Odyssey/Views/Auth/EmailSignUpView.swift`

**Step 1: Create the new EmailSignUpView file**

Create `Odyssey/Views/Auth/EmailSignUpView.swift`:

```swift
import SwiftUI
import ClerkKit

struct EmailSignUpView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    enum Step {
        case credentials
        case verifyEmail
        case addPhone
        case verifyPhone
    }

    @State private var step: Step = .credentials
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var emailCode = ""
    @State private var phoneNumber = ""
    @State private var phoneCode = ""
    @State private var currentSignUp: ClerkKit.SignUp?
    @State private var currentPhone: ClerkKit.PhoneNumber?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            switch step {
            case .credentials:
                credentialsView
            case .verifyEmail:
                verifyEmailView
            case .addPhone:
                addPhoneView
            case .verifyPhone:
                verifyPhoneView
            }

            if authManager.isLoading {
                ProgressView()
            }

            if let error = authManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.coralRed)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Credentials

    private var credentialsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentTeal)

            Text("Create Your Account")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)

            if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                Text("Passwords don't match")
                    .font(.caption)
                    .foregroundStyle(Color.coralRed)
            }

            Button {
                Task { await createAccount() }
            } label: {
                Text("Create Account")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(email.isEmpty || password.isEmpty || password != confirmPassword || authManager.isLoading)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Verify Email

    private var verifyEmailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentTeal)

            Text("Check Your Email")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter the verification code sent to \(email)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("6-digit code", text: $emailCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title3.monospaced())
                .padding()
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

            Button {
                Task { await verifyEmail() }
            } label: {
                Text("Verify Email")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(emailCode.count < 6 || authManager.isLoading)
            .padding(.horizontal, 24)

            Button("Resend Code") {
                Task { await resendEmailCode() }
            }
            .foregroundStyle(Color.accentTeal)
            .font(.subheadline)
        }
    }

    // MARK: - Add Phone

    private var addPhoneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "phone.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentTeal)

            Text("Set Up Two-Factor Auth")
                .font(.title2)
                .fontWeight(.bold)

            Text("Add your phone number for account security. You'll need it to sign in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("+1 (555) 123-4567", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding()
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

            Button {
                Task { await setupPhone() }
            } label: {
                Text("Send Verification Code")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(phoneNumber.isEmpty || authManager.isLoading)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Verify Phone

    private var verifyPhoneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.successGreen)

            Text("Verify Your Phone")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter the code sent to \(phoneNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("6-digit code", text: $phoneCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title3.monospaced())
                .padding()
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

            Button {
                Task { await verifyPhone() }
            } label: {
                Text("Complete Setup")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(phoneCode.count < 6 || authManager.isLoading)
            .padding(.horizontal, 24)

            Button("Resend Code") {
                Task { await resendPhoneCode() }
            }
            .foregroundStyle(Color.accentTeal)
            .font(.subheadline)
        }
    }

    // MARK: - Actions

    private func createAccount() async {
        do {
            let signUp = try await authManager.signUpWithEmail(email: email, password: password)
            currentSignUp = signUp
            authManager.error = nil
            emailCode = ""
            step = .verifyEmail
        } catch {
            // Error already set by AuthManager
        }
    }

    private func verifyEmail() async {
        guard let signUp = currentSignUp else { return }

        authManager.isLoading = true
        authManager.error = nil
        defer { authManager.isLoading = false }

        do {
            let result = try await signUp.verifyEmailCode(emailCode)
            currentSignUp = result

            if result.status == .complete {
                // User is now authenticated — set up 2FA
                try await authManager.completeSignIn()
                step = .addPhone
            } else {
                // Still missing requirements — advance to phone anyway since email is verified
                try await authManager.completeSignIn()
                step = .addPhone
            }
        } catch {
            authManager.error = error.localizedDescription
        }
    }

    private func resendEmailCode() async {
        guard let signUp = currentSignUp else { return }

        authManager.isLoading = true
        authManager.error = nil
        defer { authManager.isLoading = false }

        do {
            let updated = try await signUp.sendEmailCode()
            currentSignUp = updated
        } catch {
            authManager.error = error.localizedDescription
        }
    }

    private func setupPhone() async {
        do {
            let phone = try await authManager.setupPhone2FA(phoneNumber: phoneNumber)
            currentPhone = phone
            authManager.error = nil
            phoneCode = ""
            step = .verifyPhone
        } catch {
            // Error already set by AuthManager
        }
    }

    private func verifyPhone() async {
        guard let phone = currentPhone else { return }

        do {
            try await authManager.verifyPhone2FA(phone: phone, code: phoneCode)
            // 2FA setup complete — authManager.isSignedIn triggers parent dismissal
            // If isSignedIn was already set during email verification, signal completion
            // by dismissing (parent's onChange may have already fired)
            dismiss()
        } catch {
            // Error already set by AuthManager
        }
    }

    private func resendPhoneCode() async {
        guard let phone = currentPhone else { return }

        authManager.isLoading = true
        authManager.error = nil
        defer { authManager.isLoading = false }

        do {
            let sent = try await phone.sendCode()
            currentPhone = sent
        } catch {
            authManager.error = error.localizedDescription
        }
    }
}
```

**Step 2: Add the new file to the Xcode project**

The file needs to be added to the Xcode project's `Odyssey/Views/Auth` group and the Odyssey target's Sources build phase. Add three entries to `Odyssey.xcodeproj/project.pbxproj`:

1. A PBXBuildFile entry (in the `/* Begin PBXBuildFile section */`):
```
		BB14B5C6D7E8F9A0B1C2D3E4 /* EmailSignUpView.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA14B5C6D7E8F9A0B1C2D3E4 /* EmailSignUpView.swift */; };
```

2. A PBXFileReference entry (in the `/* Begin PBXFileReference section */`):
```
		AA14B5C6D7E8F9A0B1C2D3E4 /* EmailSignUpView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EmailSignUpView.swift; sourceTree = "<group>"; };
```

3. Add the file reference `AA14B5C6D7E8F9A0B1C2D3E4 /* EmailSignUpView.swift */` to the Auth group's `children` array (near line 838-840 where the other Auth views are listed).

4. Add the build file reference `BB14B5C6D7E8F9A0B1C2D3E4 /* EmailSignUpView.swift in Sources */` to the Odyssey target's Sources build phase `files` array (near line 1138-1140).

**Step 3: Build to verify compilation**

Run: `make build`
Expected: Build succeeds. EmailSignUpView compiles and is included in the target.

**Step 4: Commit**

```bash
git add Odyssey/Views/Auth/EmailSignUpView.swift Odyssey.xcodeproj/project.pbxproj
git commit -m "feat(auth): add EmailSignUpView with 4-step sign-up and SMS 2FA setup"
```

---

### Task 4: Update BackupPromptModal with Email and GitHub sign-up options

**Files:**
- Modify: `Odyssey/Views/Auth/BackupPromptModal.swift`

**Step 1: Add NavigationLink state and GitHub/Email buttons to signUpView**

In `BackupPromptModal.swift`, add a new state variable near the top (after line 10):
```swift
@State private var showEmailSignUp = false
```

Then replace the `signUpView` computed property (lines 92-162) with:

```swift
private var signUpView: some View {
    VStack(spacing: 24) {
        Spacer()

        Text("Create Account")
            .font(.title2)
            .fontWeight(.bold)

        VStack(spacing: 12) {
            signInButton(
                icon: "apple.logo",
                title: "Continue with Apple",
                action: {
                    Task {
                        do {
                            try await authManager.signUp(strategy: .apple)
                        } catch is CancellationError {
                            // User cancelled OAuth sheet
                        } catch {
                            authManager.error = error.localizedDescription
                        }
                    }
                }
            )

            signInButton(
                icon: "globe",
                title: "Continue with Google",
                action: {
                    Task {
                        do {
                            try await authManager.signUp(strategy: .google)
                        } catch is CancellationError {
                            // User cancelled OAuth sheet
                        } catch {
                            authManager.error = error.localizedDescription
                        }
                    }
                }
            )

            signInButton(
                icon: "cat.fill",
                title: "Continue with GitHub",
                action: {
                    Task {
                        do {
                            try await authManager.signUp(strategy: .github)
                        } catch is CancellationError {
                            // User cancelled OAuth sheet
                        } catch {
                            authManager.error = error.localizedDescription
                        }
                    }
                }
            )

            NavigationLink(destination: EmailSignUpView().environment(authManager)) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .frame(width: 20)
                    Text("Sign up with Email")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 24)

        Spacer()

        if authManager.isLoading {
            ProgressView()
        }

        if let error = authManager.error {
            Text(error)
                .font(.caption)
                .foregroundStyle(Color.coralRed)
                .padding(.horizontal)
        }

        Button("Back") {
            showSignUp = false
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, 32)
    }
    .onChange(of: authManager.isSignedIn) { _, isSignedIn in
        if isSignedIn {
            Task {
                await generateRecoveryKey()
                showRecoveryKey = true
            }
        }
    }
}
```

**Step 2: Build to verify compilation**

Run: `make build`
Expected: Build succeeds. BackupPromptModal navigates to EmailSignUpView.

**Step 3: Commit**

```bash
git add Odyssey/Views/Auth/BackupPromptModal.swift
git commit -m "feat(auth): add GitHub and Email sign-up options to BackupPromptModal"
```

---

### Task 5: Update OnboardingFlowView to present sign-up options when creating account

**Files:**
- Modify: `Odyssey/Views/Onboarding/OnboardingFlowView.swift`
- Modify: `Odyssey/ViewModels/OnboardingViewModel.swift`

**Step 1: Add account creation sheet state to OnboardingFlowView**

At `OnboardingFlowView.swift`, add a state variable and present BackupPromptModal as a sheet. Replace the `handleCreateAccount()` method and add a sheet modifier:

After the `onboardingCard(for:)` function (before `handleCreateAccount`), add a `@State`:
```swift
@State private var showAccountSheet = false
```

Replace `handleCreateAccount()`:
```swift
private func handleCreateAccount() {
    showAccountSheet = true
}
```

Add a `.sheet` modifier to the `ZStack` in `body` (after the closing `}` of the VStack, before the ZStack closes):
```swift
.sheet(isPresented: $showAccountSheet) {
    BackupPromptModal()
        .environment(authManager)
}
```

This requires adding `@Environment(AuthManager.self) private var authManager` to `OnboardingFlowView`.

**Step 2: Remove the TODO in OnboardingViewModel**

In `Odyssey/ViewModels/OnboardingViewModel.swift`, the `beginAccountCreation()` method currently just calls `goToNext()`. This is no longer called since `OnboardingFlowView` now handles it directly with a sheet. Remove or keep the method — since `OnboardingFlowView` no longer calls it, we can leave it as-is (it's unused but harmless) or remove the call. The simplest change: since `OnboardingFlowView.handleCreateAccount()` now shows a sheet instead of calling `viewModel.beginAccountCreation()`, no change needed to the ViewModel.

**Step 3: Build to verify compilation**

Run: `make build`
Expected: Build succeeds. Onboarding account card now presents sign-up sheet.

**Step 4: Commit**

```bash
git add Odyssey/Views/Onboarding/OnboardingFlowView.swift
git commit -m "feat(auth): present sign-up options sheet from onboarding account card"
```

---

### Task 6: Build verification and manual testing checklist

**Step 1: Full clean build**

Run: `make clean && make build`
Expected: Clean build succeeds with no warnings related to auth changes.

**Step 2: Manual testing checklist**

Test on a physical device or simulator with Clerk configured:

- [ ] **Sign-in view**: All 4 buttons visible (Apple, Google, GitHub, Email)
- [ ] **GitHub OAuth**: Tapping "Continue with GitHub" opens OAuth sheet, signs in successfully
- [ ] **Email sign-in**: Enter email/password → 2FA code screen appears → entering code signs in
- [ ] **Forgot password**: From email/password step, tap "Forgot Password?" → enter email → receive code → enter code → set new password → signs in (with 2FA if enabled)
- [ ] **Email sign-up (BackupPromptModal)**: "Sign up with Email" navigates to EmailSignUpView → enter credentials → verify email code → add phone → verify phone code → recovery key shown
- [ ] **GitHub sign-up (BackupPromptModal)**: "Continue with GitHub" opens OAuth → signs up → recovery key shown
- [ ] **Onboarding account card**: "Create Free Account" opens sheet with all 4 options
- [ ] **Back navigation**: All "Back" buttons return to previous step correctly
- [ ] **Error states**: Invalid email, wrong password, wrong code, expired code all show error messages
- [ ] **Loading states**: ProgressView shown during all async operations

**Step 3: Commit any fixes from testing, then final commit**

```bash
git add -A
git commit -m "feat(auth): email/password sign-up with SMS 2FA, GitHub OAuth, and forgot password"
```

---

### Clerk Dashboard Configuration (prerequisite — not code)

Before testing, ensure these are enabled in the Clerk dashboard (https://dashboard.clerk.com):

1. **Authentication → Email**: Enable email/password strategy
2. **Authentication → Multi-factor**: Enable Phone code (SMS)
3. **Authentication → Social connections**: Add GitHub (requires GitHub OAuth app client ID and secret)
4. **Authentication → Social connections**: Verify Apple and Google are already enabled
