import ClerkKit
import SwiftUI

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
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Credentials

    private var credentialsView: some View {
        VStack(spacing: 24) {
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
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                if !confirmPassword.isEmpty && password != confirmPassword {
                    Text("Passwords do not match")
                        .font(.caption)
                        .foregroundStyle(Color.coralRed)
                }

                Button {
                    Task {
                        authManager.error = nil
                        do {
                            let signUp = try await authManager.signUpWithEmail(
                                email: email,
                                password: password
                            )
                            currentSignUp = signUp
                            step = .verifyEmail
                        } catch {
                            authManager.error = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Create Account")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black)
                }
                .disabled(email.isEmpty || password.isEmpty || confirmPassword.isEmpty || password != confirmPassword)
                .opacity(email.isEmpty || password.isEmpty || confirmPassword.isEmpty || password != confirmPassword ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Verify Email

    private var verifyEmailView: some View {
        VStack(spacing: 24) {
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

            VStack(spacing: 12) {
                TextField("000000", text: $emailCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospaced())
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    Task {
                        authManager.error = nil
                        do {
                            guard let signUp = currentSignUp else { return }
                            _ = try await signUp.verifyEmailCode(emailCode)
                            try await authManager.completeSignIn()
                            step = .addPhone
                        } catch {
                            authManager.error = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Verify Email")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black)
                }
                .disabled(emailCode.count < 6)
                .opacity(emailCode.count < 6 ? 0.5 : 1)

                Button {
                    Task {
                        authManager.error = nil
                        do {
                            guard let signUp = currentSignUp else { return }
                            currentSignUp = try await signUp.sendEmailCode()
                        } catch {
                            authManager.error = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Resend Code")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentTeal)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Add Phone

    private var addPhoneView: some View {
        VStack(spacing: 24) {
            Image(systemName: "phone.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentTeal)

            Text("Set Up Two-Factor Auth")
                .font(.title2)
                .fontWeight(.bold)

            Text("Your phone number will be required each time you sign in, keeping your journal secure.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    Task {
                        authManager.error = nil
                        do {
                            let phone = try await authManager.setupPhone2FA(phoneNumber: phoneNumber)
                            currentPhone = phone
                            step = .verifyPhone
                        } catch {
                            authManager.error = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Send Verification Code")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black)
                }
                .disabled(phoneNumber.isEmpty)
                .opacity(phoneNumber.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Verify Phone

    private var verifyPhoneView: some View {
        VStack(spacing: 24) {
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

            VStack(spacing: 12) {
                TextField("000000", text: $phoneCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospaced())
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    Task {
                        authManager.error = nil
                        do {
                            guard let phone = currentPhone else { return }
                            try await authManager.verifyPhone2FA(phone: phone, code: phoneCode)
                            dismiss()
                        } catch {
                            authManager.error = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Complete Setup")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black)
                }
                .disabled(phoneCode.count < 6)
                .opacity(phoneCode.count < 6 ? 0.5 : 1)

                Button {
                    Task {
                        authManager.error = nil
                        do {
                            guard let phone = currentPhone else { return }
                            currentPhone = try await phone.sendCode()
                        } catch {
                            authManager.error = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Resend Code")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentTeal)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}
