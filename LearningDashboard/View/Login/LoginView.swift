//
//  LoginView.swift
//  LearningDashboard
//

import SwiftUI

struct LoginView: View {

    private enum Field {
        case email, password
    }

    @State private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    init(viewModel: @autoclosure @escaping () -> LoginViewModel) {
        _viewModel = State(wrappedValue: viewModel())
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    fieldGroup(error: viewModel.emailError) {
                        TextField("Email", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                            .onSubmit { focusedField = .password }
                            .accessibilityIdentifier("login.email")
                    }

                    fieldGroup(error: viewModel.passwordError) {
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .password)
                            .onSubmit { submit() }
                            .accessibilityIdentifier("login.password")
                    }

                    if let message = viewModel.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("login.error")
                    }

                    Button(action: submit) {
                        ZStack {
                            Text("Log In").opacity(viewModel.isLoading ? 0 : 1)
                            if viewModel.isLoading { ProgressView() }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("login.button")
                }

                if AppConfiguration.useMockBackend {
                    demoHint
                }
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: viewModel.email) { viewModel.inputChanged() }
        .onChange(of: viewModel.password) { viewModel.inputChanged() }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Learning Dashboard")
                .font(.title.bold())
            Text("Log in to continue your courses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 48)
    }

    private var demoHint: some View {
        VStack(spacing: 2) {
            Text("Demo account")
                .font(.caption.weight(.semibold))
            Text("\(MockAPIClient.validEmail)  /  \(MockAPIClient.validPassword)")
                .font(.caption.monospaced())
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }

    private func fieldGroup<Content: View>(
        error: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(error == nil ? Color.clear : Color.red, lineWidth: 1)
                }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.login() }
    }
}
