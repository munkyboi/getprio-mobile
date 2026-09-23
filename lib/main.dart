import 'social/vendor_social_widgets.dart';
import 'social/vendor_social_repository.dart';

import 'package:flutter/material.dart' show Icons;

import 'dart:async';
import 'dart:math';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    show FirebaseMessaging;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'auth/auth_models.dart';
import 'auth/biometric_login.dart';
import 'auth/remembered_user_store.dart';
import 'auth/oauth_flow.dart';
import 'auth/auth_repository.dart';
import 'auth/password_utils.dart';
import 'auth/username_utils.dart';
import 'account/ticket_repository.dart';
import 'account/account_settings_repository.dart';
import 'account/approved_vendor_store.dart';
import 'account/phone_formatting.dart';
import 'account/profile_repository.dart';
import 'account/security_repository.dart';
import 'directory/directory_repository.dart';
import 'directory/vendor_contact.dart';
import 'feedback_toast.dart';
import 'form_validation.dart';
import 'navigation/customer_navigation_bar.dart';
import 'navigation/scroll_aware_app_bar.dart';
import 'navigation/swipe_back_page_route.dart';
import 'queue/auth_queue_api.dart';
import 'queue/join_repository.dart';
import 'queue/join_ui.dart';
import 'queue/payment_flow.dart';
import 'queue/queue_models.dart';
import 'queue/queue_repository.dart';
import 'push/push_coordinator.dart';
import 'app_theme.dart';
import 'loading_skeleton.dart';
import 'onboarding/onboarding_gate.dart';
import 'onboarding/onboarding_store.dart';
import 'mobile_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final environmentConfig = MobileEnvironmentConfig.fromCompileTime();
  final firebaseEnabled = await initializeFirebase(
    environment: environmentConfig.environment,
  );
  if (firebaseEnabled) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(
    GetPrioApp(
      firebaseEnabled: firebaseEnabled,
      environmentConfig: environmentConfig,
    ),
  );
}

class GetPrioApp extends StatelessWidget {
  GetPrioApp({
    super.key,
    AuthRepository? authRepository,
    this.firebaseEnabled = false,
    this.onboardingStore = const InstallationOnboardingStore(),
    MobileEnvironmentConfig? environmentConfig,
    ApprovedVendorStore? approvedVendorStore,
  }) : authRepository =
           authRepository ??
           _defaultAuthRepository(
             environmentConfig ?? MobileEnvironmentConfig.fromCompileTime(),
           ),
       environmentConfig =
           environmentConfig ?? MobileEnvironmentConfig.fromCompileTime(),
       approvedVendorStore = approvedVendorStore ?? SecureApprovedVendorStore();

  final AuthRepository authRepository;
  final bool firebaseEnabled;
  final OnboardingStore onboardingStore;
  final MobileEnvironmentConfig environmentConfig;
  final ApprovedVendorStore approvedVendorStore;

  @override
  Widget build(BuildContext context) {
    final baseUrl = environmentConfig.apiBaseUrl;
    final configurationError = environmentConfig.configurationError;
    if (configurationError != null) {
      return ShadcnApp(
        title: environmentConfig.appName,
        debugShowCheckedModeBanner: false,
        home: _EnvironmentConfigurationError(message: configurationError),
      );
    }
    final apiClient = AuthenticatedApiClient(
      baseUrl: baseUrl,
      authRepository: authRepository,
    );
    final joinRepository = JoinRepository(RestJoinApi(apiClient));
    final paymentApi = RestPaymentApi(apiClient);
    final oauthFlow = OAuthFlow(
      baseUrl: baseUrl,
      authRepository: authRepository,
      api: RestOAuthApi(baseUrl: baseUrl),
    );
    final ticketRepository = QueueTicketRepository(
      RestAccountQueueApi(apiClient, sandbox: environmentConfig.isSandbox),
    );
    final pushSignal = ValueNotifier<PushSignal?>(null);
    final pushCoordinator = firebaseEnabled
        ? PushCoordinator(
            messaging: FirebaseMessagingPort(),
            api: RestPushRegistrationApi(apiClient),
            installationStore: SecureInstallationStore(),
            platform: defaultTargetPlatform == TargetPlatform.android
                ? 'android'
                : 'ios',
            appVersion: const String.fromEnvironment(
              'FLUTTER_BUILD_NAME',
              defaultValue: '1.0.1',
            ),
            locale: 'en-PH',
            onSignal: (signal) async {
              ticketRepository.requestRefresh();
              pushSignal.value = signal;
            },
          )
        : null;
    final lightTheme = GetPrioTheme.light();
    return ShadcnApp(
      title: environmentConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      background: lightTheme.colorScheme.background,
      theme: lightTheme,
      home: GetPrioTheme.wrap(
        OnboardingGate(
          store: onboardingStore,
          loading: const SplashLoadingScreen(),
          child: AuthGate(
            authRepository: authRepository,
            joinRepository: joinRepository,
            paymentApi: paymentApi,
            ticketRepository: ticketRepository,
            queueRepository: QueueRepository(RestQueueApi(apiClient)),
            directoryRepository: DirectoryRepository(
              RestDirectoryApi(apiClient),
            ),
            settingsRepository: AccountSettingsRepository(
              RestAccountSettingsApi(apiClient),
            ),
            securityRepository: SecurityRepository(RestSecurityApi(apiClient)),
            profileRepository: AccountProfileRepository(
              RestAccountProfileApi(apiClient),
            ),
            allowedHosts: environmentConfig.approvedHostSet,
            sandbox: environmentConfig.isSandbox,
            paymentLinkSource: AppPaymentLinkSource(),
            pushCoordinator: pushCoordinator,
            pushSignal: pushSignal,
            oauthFlow: oauthFlow,
            approvedVendorStore: approvedVendorStore,
          ),
        ),
      ),
    );
  }

  static AuthRepository _defaultAuthRepository(
    MobileEnvironmentConfig environmentConfig,
  ) {
    return AuthRepository(
      api: RestAuthApi(
        baseUrl: environmentConfig.apiBaseUrl,
        sandbox: environmentConfig.isSandbox,
      ),
      tokenStore: SecureTokenStore(),
      biometricLogin: DeviceBiometricLogin(),
      rememberedUserStore: SecureRememberedUserStore(),
    );
  }
}

class _EnvironmentConfigurationError extends StatelessWidget {
  const _EnvironmentConfigurationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authRepository,
    required this.joinRepository,
    required this.paymentApi,
    required this.ticketRepository,
    required this.queueRepository,
    required this.directoryRepository,
    required this.settingsRepository,
    required this.securityRepository,
    required this.profileRepository,
    required this.allowedHosts,
    this.paymentLinkSource,
    this.pushCoordinator,
    this.pushSignal,
    this.oauthFlow,
    this.approvedVendorStore,
    this.sandbox = false,
  });

  final AuthRepository authRepository;
  final JoinRepository joinRepository;
  final PaymentApi paymentApi;
  final QueueTicketRepository ticketRepository;
  final QueueRepository queueRepository;
  final DirectoryRepository directoryRepository;
  final AccountSettingsRepository settingsRepository;
  final SecurityRepository securityRepository;
  final AccountProfileRepository profileRepository;
  final Set<String> allowedHosts;
  final PaymentLinkSource? paymentLinkSource;
  final PushCoordinator? pushCoordinator;
  final ValueNotifier<PushSignal?>? pushSignal;
  final OAuthFlow? oauthFlow;
  final ApprovedVendorStore? approvedVendorStore;
  final bool sandbox;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<AuthSession?> _restore;
  AuthSession? _session;
  bool _pushStarted = false;
  bool _showBiometricLogin = false;
  bool _pushRegistrationDialogVisible = false;
  StreamSubscription<Object>? _pushRegistrationErrorSubscription;

  @override
  void initState() {
    super.initState();
    _restore = _prepareLogin();
    _pushRegistrationErrorSubscription = widget
        .pushCoordinator
        ?.registrationErrors
        .listen(_handlePushRegistrationError);
  }

  @override
  void dispose() {
    _pushRegistrationErrorSubscription?.cancel();
    super.dispose();
  }

  Future<AuthSession?> _prepareLogin() async {
    final repository = widget.authRepository;
    final token = await repository.tokenStore.readRefreshToken();
    if (token != null &&
        token.isNotEmpty &&
        await repository.biometricLogin?.isEnabled() == true) {
      _showBiometricLogin = true;
      return null;
    }
    return repository.restoreSession();
  }

  void _authenticated(AuthSession session) {
    setState(() {
      _session = session;
      _showBiometricLogin = false;
    });
    unawaited(_startPush());
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      return CustomerShell(
        user: _session!.user,
        joinRepository: widget.joinRepository,
        paymentApi: widget.paymentApi,
        ticketRepository: widget.ticketRepository,
        queueRepository: widget.queueRepository,
        directoryRepository: widget.directoryRepository,
        settingsRepository: widget.settingsRepository,
        securityRepository: widget.securityRepository,
        profileRepository: widget.profileRepository,
        onUserUpdated: _updateUser,
        sandbox: widget.sandbox,
        allowedHosts: widget.allowedHosts,
        paymentLinkSource: widget.paymentLinkSource,
        pushSignal: widget.pushSignal,
        approvedVendorStore: widget.approvedVendorStore,
        onSignOut: () => unawaited(_signOut()),
      );
    }

    return FutureBuilder<AuthSession?>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashLoadingScreen();
        }
        if (snapshot.hasData) {
          _session = snapshot.data;
          unawaited(_startPush());
          return CustomerShell(
            user: snapshot.data!.user,
            joinRepository: widget.joinRepository,
            paymentApi: widget.paymentApi,
            ticketRepository: widget.ticketRepository,
            queueRepository: widget.queueRepository,
            directoryRepository: widget.directoryRepository,
            settingsRepository: widget.settingsRepository,
            securityRepository: widget.securityRepository,
            profileRepository: widget.profileRepository,
            onUserUpdated: _updateUser,
            sandbox: widget.sandbox,
            allowedHosts: widget.allowedHosts,
            paymentLinkSource: widget.paymentLinkSource,
            pushSignal: widget.pushSignal,
            approvedVendorStore: widget.approvedVendorStore,
            onSignOut: () => unawaited(_signOut()),
          );
        }
        if (_showBiometricLogin) {
          return BiometricLoginPage(
            authRepository: widget.authRepository,
            onAuthenticated: _authenticated,
            sandbox: widget.sandbox,
          );
        }
        return SignInPage(
          authRepository: widget.authRepository,
          oauthFlow: widget.oauthFlow,
          onAuthenticated: _authenticated,
          sandbox: widget.sandbox,
        );
      },
    );
  }

  Future<void> _startPush() async {
    if (_pushStarted || widget.pushCoordinator == null) return;
    _pushStarted = true;
    try {
      final initialized = await widget.pushCoordinator!.initialize();
      if (!initialized) _pushStarted = false;
    } catch (error) {
      _pushStarted = false;
      debugPrint('[push] initialization failed: $error');
      // Push is best effort and must never block queue actions.
    }
  }

  Future<void> _handlePushRegistrationError(Object error) async {
    if (!mounted ||
        error is! ApiException ||
        error.code != 'SANDBOX_DEVICE_LIMIT' ||
        _pushRegistrationDialogVisible) {
      return;
    }
    _pushRegistrationDialogVisible = true;
    final retry = await showOverlay<bool>(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        key: const Key('sandbox-device-limit-dialog'),
        leading: const Icon(LucideIcons.bellOff),
        title: const Text('Notifications unavailable'),
        content: const Text(
          'This Sandbox account already has two active devices. Sign out of another device, then retry notifications here.',
        ),
        actions: [
          GetPrioActionButton.outline(
            key: const Key('sandbox-device-limit-later'),
            onPressed: () => closeOverlay(dialogContext, false),
            child: const Text('Later'),
          ),
          GetPrioActionButton.primary(
            key: const Key('sandbox-device-limit-retry'),
            onPressed: () => closeOverlay(dialogContext, true),
            child: const Text('Retry notifications'),
          ),
        ],
      ),
    ).future;
    if (!mounted) return;
    _pushRegistrationDialogVisible = false;
    if (retry == true) {
      try {
        await widget.pushCoordinator?.retryRegistration();
      } catch (_) {
        // Push retry is best effort and must not block queue actions.
      }
    }
  }

  void _updateUser(AuthUser user) {
    final session = _session;
    if (session == null || !mounted) return;
    setState(() => _session = session.copyWith(user: user));
    unawaited(
      widget.authRepository.rememberedUserStore.write(user).catchError((
        Object error,
      ) {
        debugPrint('Could not update remembered login profile.');
      }),
    );
  }

  Future<void> _signOut() async {
    if (_session == null) return;
    _restore = Future<AuthSession?>.value(null);
    if (mounted) {
      setState(() {
        _session = null;
        _pushStarted = false;
      });
    }
    widget.directoryRepository.social?.clearSession();
    widget.ticketRepository.clearSession();
    await widget.pushCoordinator?.logout();
    await widget.authRepository.logout();
  }
}

class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('splash-loading-screen'),
      color: GetPrioTheme.paper,
      child: Center(
        child: SvgPicture.asset(
          'assets/branding/logo.svg',
          key: const Key('splash-logo'),
          width: 180,
          fit: BoxFit.contain,
          semanticsLabel: 'GetPrio logo',
        ),
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.inputKey,
    this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.onTap,
    this.onChanged,
    this.supportingText,
    this.supportingTextColor,
    this.inputFormatters,
    this.maxLength,
  });

  final String label;
  final String placeholder;
  final TextEditingController controller;
  final Key? inputKey;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final String? supportingText;
  final Color? supportingTextColor;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    FormValidation? validation;
    bool inputEnabled = true;
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is FormValidationMixin) {
        validation = (element.state as FormValidationMixin).formValidation;
        inputEnabled = !(element.state as FormValidationMixin).formBusy;
        return false;
      }
      return true;
    });
    final input = TextField(
      key: inputKey,
      enabled: inputEnabled,
      controller: controller,
      focusNode: focusNode,
      placeholder: Text(placeholder),
      keyboardType: keyboardType,
      obscureText: obscureText,
      onTap: onTap,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      onEditingComplete: _dismissKeyboard,
      onTapOutside: (_) => _dismissKeyboard(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.typography.small.copyWith(
            color: theme.colorScheme.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (validation == null)
          input
        else
          ValidatedField(
            validation: validation!,
            controller: controller,
            child: input,
          ),
        if (supportingText != null && supportingText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            supportingText!,
            style: theme.typography.small.copyWith(
              color: supportingTextColor ?? GetPrioTheme.mutedInk,
            ),
          ),
        ],
      ],
    );
  }
}

void _dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

class BiometricLoginPage extends StatefulWidget {
  const BiometricLoginPage({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
    this.sandbox = false,
  });

  final AuthRepository authRepository;
  final ValueChanged<AuthSession> onAuthenticated;
  final bool sandbox;

  @override
  State<BiometricLoginPage> createState() => _BiometricLoginPageState();
}

class _BiometricLoginPageState extends State<BiometricLoginPage> {
  late final Future<AuthUser?> _user = widget.authRepository.rememberedUserStore
      .read();

  @override
  Widget build(BuildContext context) => FutureBuilder<AuthUser?>(
    future: _user,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SplashLoadingScreen();
      }
      return SignInPage(
        authRepository: widget.authRepository,
        onAuthenticated: widget.onAuthenticated,
        rememberedUser: snapshot.data,
        biometricLogin: true,
        sandbox: widget.sandbox,
      );
    },
  );
}

class _RememberedLoginProfile extends StatelessWidget {
  const _RememberedLoginProfile({required this.user});
  final AuthUser user;

  String get _visibleName {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final fullName = user.profileName?.trim();
    if (fullName == null || fullName.isEmpty) return 'Your account';
    final parts = fullName.split(RegExp(r'\s+'));
    String mask(String part) {
      final letters = part.characters;
      return '${letters.first}***${letters.length > 2 ? letters.last : ''}';
    }

    if (parts.length == 1) return mask(parts.first);
    return [parts.first, ...parts.skip(1).map(mask)].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final visibleName = _visibleName;
    final url = user.avatarUrl?.trim();
    final fallback = Center(
      child: Text(_profileInitials(user.customerName)).h3(),
    );
    return Column(
      children: [
        Semantics(
          image: true,
          label: '$visibleName profile photo',
          child: ClipOval(
            child: Container(
              key: const Key('biometric-profile-avatar'),
              width: 72,
              height: 72,
              color: GetPrioTheme.paperAccent,
              child: url == null || url.isEmpty
                  ? fallback
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          visibleName,
          key: const Key('biometric-display-name'),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.authRepository,
    this.oauthFlow,
    this.rememberedUser,
    this.biometricLogin = false,
    this.sandbox = false,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final OAuthFlow? oauthFlow;
  final AuthUser? rememberedUser;
  final bool biometricLogin;
  final bool sandbox;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage>
    with FormValidationMixin<SignInPage> {
  @override
  bool get formBusy => _isBusy;

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaController = TextEditingController();
  final _recoveryController = TextEditingController();
  MfaChallenge? _challenge;
  String? _error;
  bool _isBusy = false;
  bool _useRecoveryCode = false;
  Timer? _keepFieldVisibleTimer;
  @override
  void initState() {
    super.initState();
    _identifierController.text = widget.rememberedUser?.email ?? '';
  }

  Future<void> _signInWithBiometrics() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final session = await widget.authRepository.restoreSession();
      if (!mounted) return;
      if (session != null) {
        widget.onAuthenticated(session);
      } else {
        setState(
          () => _error = 'Login was not completed. Tap the icon to try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not unlock your session. Try again or sign in with your password.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  void dispose() {
    _keepFieldVisibleTimer?.cancel();
    _identifierController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AspectRatio(
                    aspectRatio: 3 / 2,
                    child: Image(
                      image: AssetImage(
                        'assets/branding/login-biometric-scene.png',
                      ),
                      fit: BoxFit.contain,
                      semanticLabel:
                          'GetPrio customers waiting and checking in',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.sandbox
                        ? 'GetPrio Sandbox'
                        : widget.biometricLogin
                        ? 'Welcome back'
                        : 'Welcome to GetPrio',
                    textAlign: TextAlign.center,
                  ).h1(),
                  const SizedBox(height: 8),
                  Text(
                    challenge == null
                        ? widget.sandbox
                              ? 'Sign in with your Sandbox test-user credentials.'
                              : 'Sign in to manage your queue tickets.'
                        : 'Verify your identity to finish signing in.',
                    textAlign: challenge == null
                        ? TextAlign.center
                        : TextAlign.start,
                  ),
                  const SizedBox(height: 24),
                  if (challenge == null) ...[
                    if (widget.biometricLogin &&
                        widget.rememberedUser != null) ...[
                      _RememberedLoginProfile(user: widget.rememberedUser!),
                      const SizedBox(height: 20),
                    ] else
                      _LabeledTextField(
                        inputKey: const Key('sign-in-identifier'),
                        controller: _identifierController,
                        label: 'Email or username',
                        placeholder: 'you@example.com or username',
                        keyboardType: TextInputType.emailAddress,
                        onTap: () => _keepFieldVisible(_identifierController),
                      ),
                    const SizedBox(height: 12),
                    _LabeledTextField(
                      inputKey: const Key('sign-in-password'),
                      controller: _passwordController,
                      label: 'Password',
                      placeholder: 'Enter your password',
                      obscureText: true,
                      onTap: () => _keepFieldVisible(_passwordController),
                    ),
                    const SizedBox(height: 20),
                    GetPrioActionButton.primary(
                      key: const Key('sign-in-button'),
                      onPressed: _isBusy ? null : _signIn,
                      child: Text(_isBusy ? 'Signing in...' : 'Sign in'),
                    ),
                    const SizedBox(height: 8),
                    if (widget.biometricLogin) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              defaultTargetPlatform == TargetPlatform.iOS
                                  ? 'Sign in with Face ID'
                                  : 'Sign in with biometrics',
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Semantics(
                          label: defaultTargetPlatform == TargetPlatform.iOS
                              ? 'Sign in with Face ID'
                              : 'Sign in with biometrics',
                          child: IconButton.outline(
                            key: const Key('biometric-login-icon'),
                            onPressed: _isBusy ? null : _signInWithBiometrics,
                            icon: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                defaultTargetPlatform == TargetPlatform.iOS
                                    ? LucideIcons.scanFace
                                    : LucideIcons.fingerprint,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else if (!widget.sandbox) ...[
                      GetPrioActionButton.outline(
                        onPressed: _isBusy ? null : _openRegister,
                        child: const Text('Create customer account'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (!widget.sandbox)
                      Center(
                        child: LinkButton(
                          key: const Key('forgot-password-link'),
                          onPressed: _isBusy ? null : _openPasswordRecovery,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    if (!widget.sandbox &&
                        !widget.biometricLogin &&
                        widget.oauthFlow?.enabled == true) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Or continue with',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GetPrioActionButton.outline(
                              onPressed: _isBusy
                                  ? null
                                  : () => _signInWithOAuth('google'),
                              child: const Text('Google'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GetPrioActionButton.outline(
                              onPressed: _isBusy
                                  ? null
                                  : () => _signInWithOAuth('facebook'),
                              child: const Text('Facebook'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    if (_useRecoveryCode)
                      _LabeledTextField(
                        inputKey: const Key('mfa-recovery-code'),
                        controller: _recoveryController,
                        label: 'Recovery code',
                        placeholder: 'Enter a recovery code',
                        onTap: () => _keepFieldVisible(_recoveryController),
                      )
                    else
                      _LabeledTextField(
                        inputKey: const Key('mfa-code'),
                        controller: _mfaController,
                        label: 'Authenticator code',
                        placeholder: 'Enter your 6-digit code',
                        keyboardType: TextInputType.number,
                        onTap: () => _keepFieldVisible(_mfaController),
                      ),
                    const SizedBox(height: 12),
                    GetPrioActionButton.primary(
                      key: const Key('verify-mfa-button'),
                      onPressed: _isBusy ? null : () => _verifyMfa(challenge),
                      child: Text(
                        _isBusy ? 'Verifying...' : 'Verify and continue',
                      ),
                    ),
                    const SizedBox(height: 8),
                    GetPrioActionButton.outline(
                      onPressed: _isBusy
                          ? null
                          : () => setState(
                              () => _useRecoveryCode = !_useRecoveryCode,
                            ),
                      child: Text(
                        _useRecoveryCode
                            ? 'Use authenticator code'
                            : 'Use a recovery code',
                      ),
                    ),
                    const SizedBox(height: 8),
                    GetPrioActionButton.outline(
                      onPressed: _isBusy
                          ? null
                          : () => setState(() => _challenge = null),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    DestructiveBadge(child: Text(_error!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _keepFieldVisible(TextEditingController controller) {
    void ensureVisible() {
      final fieldContext = formValidation.keyFor(controller).currentContext;
      if (!mounted || fieldContext == null || !fieldContext.mounted) return;
      final fieldRenderObject = fieldContext.findRenderObject();
      final scrollable = Scrollable.maybeOf(fieldContext);
      if (fieldRenderObject is! RenderBox ||
          !fieldRenderObject.hasSize ||
          scrollable == null) {
        return;
      }

      final fieldTop = fieldRenderObject.localToGlobal(Offset.zero).dy;
      final fieldBottom = fieldTop + fieldRenderObject.size.height;
      final viewInsets = MediaQuery.viewInsetsOf(context);
      final keyboardTop = MediaQuery.sizeOf(context).height - viewInsets.bottom;
      const safeGap = 24.0;
      final scrollDelta = fieldBottom > keyboardTop - safeGap
          ? fieldBottom - (keyboardTop - safeGap)
          : fieldTop < safeGap
          ? fieldTop - safeGap
          : 0.0;
      if (scrollDelta == 0) return;

      final position = scrollable.position;
      final target = (position.pixels + scrollDelta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      position.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensureVisible();
      _keepFieldVisibleTimer?.cancel();
      _keepFieldVisibleTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) ensureVisible();
      });
    });
  }

  Future<void> _signIn() async {
    if (_isBusy ||
        !validateForm({
          _identifierController: requiredField(
            _identifierController.text,
            'Email or username',
          ),
          _passwordController: requiredField(
            _passwordController.text,
            'Password',
          ),
        })) {
      return;
    }
    setState(() {
      _error = null;
      _isBusy = true;
    });
    try {
      final result = await widget.authRepository.signIn(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      switch (result) {
        case AuthenticatedSession(:final session):
          widget.onAuthenticated(session);
        case final MfaChallenge challenge:
          if (widget.sandbox) {
            setState(() => _error = 'Sandbox test users do not use MFA.');
          } else {
            setState(() => _challenge = challenge);
          }
      }
    } catch (error) {
      if (mounted) showFormError(error, _authError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _verifyMfa(MfaChallenge challenge) async {
    if (_isBusy ||
        !validateForm({
          if (_useRecoveryCode)
            _recoveryController: requiredField(
              _recoveryController.text,
              'Recovery code',
            )
          else
            _mfaController: codeField(_mfaController.text),
        })) {
      return;
    }
    setState(() {
      _error = null;
      _isBusy = true;
    });
    try {
      final result = await widget.authRepository.verifyMfa(
        challengeToken: challenge.challengeToken,
        code: _useRecoveryCode ? null : _mfaController.text.trim(),
        recoveryCode: _useRecoveryCode ? _recoveryController.text.trim() : null,
      );
      if (!mounted) return;
      if (result case AuthenticatedSession(:final session)) {
        widget.onAuthenticated(session);
      } else {
        setState(() => _error = 'Another verification step is required.');
      }
    } catch (error) {
      if (mounted) showFormError(error, _authError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signInWithOAuth(String provider) async {
    final flow = widget.oauthFlow;
    if (flow == null) return;
    setState(() {
      _error = null;
      _isBusy = true;
    });
    try {
      final result = await flow.signIn(provider);
      if (!mounted) return;
      switch (result) {
        case AuthenticatedSession(:final session):
          widget.onAuthenticated(session);
        case final MfaChallenge challenge:
          setState(() => _challenge = challenge);
      }
    } catch (error) {
      if (mounted) showFormError(error, _authError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _openRegister() {
    Navigator.of(context).push(
      SwipeBackPageRoute<void>(
        builder: (context) => RegisterPage(
          authRepository: widget.authRepository,
          onAuthenticated: widget.onAuthenticated,
        ),
      ),
    );
  }

  void _openPasswordRecovery() {
    Navigator.of(context).push(
      SwipeBackPageRoute<void>(
        builder: (context) =>
            PasswordRecoveryPage(authRepository: widget.authRepository),
      ),
    );
  }

  String _authError(Object error) {
    if (error is ApiException && error.code == 'API_BASE_URL_MISSING') {
      return 'API URL is missing. Launch with --dart-define=GETPRIO_API_BASE_URL=<your-api-origin>.';
    }
    if (error is ApiException && error.message.isNotEmpty) return error.message;
    if (error is FormatException) return error.message;
    return 'We could not sign you in. Check your connection and try again.';
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with FormValidationMixin<RegisterPage> {
  @override
  bool get formBusy => _busy;

  final _name = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  Timer? _usernameCheckTimer;
  Timer? _passwordStrengthTimer;
  int _usernameCheckId = 0;
  int _passwordStrengthId = 0;
  bool _busy = false;
  bool _usernameManuallyEdited = false;
  bool _usernameAvailable = false;
  bool _checkingUsername = false;
  String _usernameMessage = '';
  PasswordStrength? _passwordStrength;
  CustomerRegistrationChallenge? _registrationChallenge;

  @override
  void initState() {
    super.initState();
    _name.addListener(_handleNameChanged);
    _nameFocusNode.addListener(_handleNameFocusChanged);
  }

  @override
  void dispose() {
    _usernameCheckTimer?.cancel();
    _passwordStrengthTimer?.cancel();
    _name.removeListener(_handleNameChanged);
    _nameFocusNode.removeListener(_handleNameFocusChanged);
    _name.dispose();
    _nameFocusNode.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _registrationChallenge;
    return ScrollNotificationObserver(
      child: Scaffold(
        headers: [
          ScrollAwareAppBar(
            title: Text(challenge == null ? 'Create account' : 'Verify email'),
            leading: [
              GhostButton(
                onPressed: () => Navigator.of(context).pop(),
                density: ButtonDensity.icon,
                child: const Icon(LucideIcons.arrowLeft),
              ),
            ],
          ),
        ],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: challenge == null
              ? _buildRegistrationForm(context)
              : _buildOtpForm(context, challenge),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Customer registration').h1(),
        const SizedBox(height: 8),
        const Text('Create your account to manage bookings and queue tickets.'),
        const SizedBox(height: 12),
        const SizedBox(
          height: 150,
          child: Image(
            image: AssetImage('assets/illustrations/customer-onboarding.png'),
            fit: BoxFit.contain,
            semanticLabel: 'Illustration of a customer using GetPrio',
          ),
        ),
        const SizedBox(height: 20),
        _LabeledTextField(
          inputKey: const Key('register-full-name'),
          controller: _name,
          focusNode: _nameFocusNode,
          label: 'Full name',
          placeholder: 'e.g. Carlo Abella',
        ),
        const SizedBox(height: 12),
        _LabeledTextField(
          inputKey: const Key('register-username'),
          controller: _username,
          label: 'Username',
          placeholder: 'Choose a username',
          onChanged: _handleUsernameChanged,
          supportingText: _checkingUsername
              ? 'Checking username...'
              : !_usernameAvailable
              ? null
              : _usernameMessage.isEmpty
              ? null
              : _usernameMessage,
          supportingTextColor: _checkingUsername
              ? GetPrioTheme.mutedInk
              : GetPrioTheme.teal,
        ),
        const SizedBox(height: 12),
        _LabeledTextField(
          inputKey: const Key('register-email'),
          controller: _email,
          label: 'Email address',
          placeholder: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _LabeledTextField(
          inputKey: const Key('register-password'),
          controller: _password,
          label: 'Password',
          placeholder: 'Create a password',
          obscureText: true,
          onChanged: _handlePasswordChanged,
        ),
        if (_passwordStrength != null && _password.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _PasswordStrengthIndicator(strength: _passwordStrength!),
        ],
        const SizedBox(height: 20),
        GetPrioActionButton.primary(
          key: const Key('register-submit'),
          onPressed: _busy || _checkingUsername ? null : _register,
          child: Text(
            _checkingUsername
                ? 'Checking username...'
                : _busy
                ? 'Sending code...'
                : 'Create account',
          ),
        ),
      ],
    );
  }

  Widget _buildOtpForm(
    BuildContext context,
    CustomerRegistrationChallenge challenge,
  ) {
    return Column(
      key: const Key('register-otp-screen'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Verify your email').h1(),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit verification code to ${challenge.deliveryTarget}.',
        ),
        const SizedBox(height: 20),
        _LabeledTextField(
          inputKey: const Key('register-otp'),
          controller: _otp,
          label: 'Verification code',
          placeholder: 'Enter your 6-digit code',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
        ),
        const SizedBox(height: 20),
        GetPrioActionButton.primary(
          key: const Key('register-otp-submit'),
          onPressed: _busy ? null : _verifyRegistrationOtp,
          child: Text(_busy ? 'Verifying...' : 'Verify email'),
        ),
        const SizedBox(height: 8),
        GetPrioActionButton.outline(
          key: const Key('register-otp-resend'),
          onPressed: _busy ? null : _resendRegistrationOtp,
          child: const Text('Resend code'),
        ),
        const SizedBox(height: 8),
        GetPrioActionButton.outline(
          key: const Key('register-otp-back'),
          onPressed: _busy
              ? null
              : () => setState(() {
                  _registrationChallenge = null;
                  _otp.clear();
                }),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }

  void _handleNameChanged() {
    if (_usernameManuallyEdited) return;
    _usernameCheckTimer?.cancel();
    ++_usernameCheckId;
    if (!mounted) return;
    setState(() {
      _usernameAvailable = false;
      _checkingUsername = false;
      _usernameMessage = '';
    });
  }

  void _handleNameFocusChanged() {
    if (_nameFocusNode.hasFocus || _usernameManuallyEdited) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _setControllerText(_username, '');
      _scheduleUsernameCheck('');
      return;
    }

    final username = buildUsernameFromName(name);
    _setControllerText(_username, username);
    _scheduleUsernameCheck(username, showCheckingImmediately: false);
  }

  void _handleUsernameChanged(String value) {
    _usernameManuallyEdited = true;
    _setControllerText(_username, normalizeUsernameInput(value));
    _scheduleUsernameCheck(_username.text);
  }

  void _handlePasswordChanged(String value) {
    _passwordStrengthTimer?.cancel();
    final requestId = ++_passwordStrengthId;
    if (value.isEmpty) {
      setState(() => _passwordStrength = null);
      return;
    }
    setState(() => _passwordStrength = null);
    _passwordStrengthTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || requestId != _passwordStrengthId) return;
      setState(() => _passwordStrength = evaluatePasswordStrength(value));
    });
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _scheduleUsernameCheck(
    String value, {
    bool debounce = true,
    bool showCheckingImmediately = true,
  }) {
    _usernameCheckTimer?.cancel();
    final requestId = ++_usernameCheckId;
    final username = value.trim();

    if (username.isEmpty) {
      setState(() {
        _usernameAvailable = false;
        _checkingUsername = false;
        _usernameMessage = '';
      });
      return;
    }

    if (!isUsernameFormatValid(username)) {
      setState(() {
        _usernameAvailable = false;
        _checkingUsername = false;
        _usernameMessage =
            'Use 3-30 lowercase letters, numbers, or underscores.';
      });
      return;
    }

    setState(() {
      _usernameAvailable = false;
      _checkingUsername = showCheckingImmediately;
      _usernameMessage = '';
    });
    Future<void> check() async {
      if (!mounted || requestId != _usernameCheckId) return;
      if (!showCheckingImmediately) {
        setState(() => _checkingUsername = true);
      }
      try {
        final result = await widget.authRepository.checkUsernameAvailability(
          username,
        );
        if (!mounted || requestId != _usernameCheckId) return;
        setState(() {
          _usernameAvailable = result.available && result.valid;
          _usernameMessage = result.message;
        });
      } catch (error) {
        if (!mounted || requestId != _usernameCheckId) return;
        setState(() {
          _usernameAvailable = false;
          _usernameMessage = _usernameCheckError(error);
        });
        showFeedbackToast(
          context,
          message: _usernameCheckError(error),
          isError: true,
        );
      } finally {
        if (mounted && requestId == _usernameCheckId) {
          setState(() => _checkingUsername = false);
        }
      }
    }

    if (debounce) {
      _usernameCheckTimer = Timer(const Duration(milliseconds: 300), check);
    } else {
      unawaited(check());
    }
  }

  String _usernameCheckError(Object error) {
    if (error is ApiException && error.message.isNotEmpty) {
      return error.message;
    }
    return 'We could not verify this username. Try again.';
  }

  Future<void> _register() async {
    if (_busy || _checkingUsername) return;
    if (!validateForm({
      _name: _name.text.trim().length < 2 ? 'Enter your full name.' : null,
      _username: !isUsernameFormatValid(_username.text.trim())
          ? 'Use 3–30 lowercase letters, numbers, or underscores.'
          : !_usernameAvailable
          ? (_usernameMessage.isNotEmpty
                ? _usernameMessage
                : 'Choose an available username.')
          : null,
      _email: emailField(_email.text),
      _password: newPasswordField(_password.text),
    })) {
      return;
    }
    setState(() => _busy = true);
    try {
      final challenge = await widget.authRepository.startCustomerRegistration(
        name: _name.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        setState(() => _registrationChallenge = challenge);
      }
    } catch (error) {
      if (mounted) {
        _showRegistrationError(_registrationError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyRegistrationOtp() async {
    final challenge = _registrationChallenge;
    if (_busy ||
        challenge == null ||
        !validateForm({_otp: codeField(_otp.text)})) {
      return;
    }
    final code = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showRegistrationError('Enter the 6-digit verification code.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.authRepository.verifyCustomerRegistration(
        challengeId: challenge.challengeId,
        code: code,
      );
      if (mounted) {
        widget.onAuthenticated(result.session);
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          _registrationError(error),
          field: error is ApiException && error.statusCode == 400 ? _otp : null,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendRegistrationOtp() async {
    final challenge = _registrationChallenge;
    if (challenge == null) return;
    setState(() => _busy = true);
    try {
      final nextChallenge = await widget.authRepository
          .resendCustomerRegistrationCode(challengeId: challenge.challengeId);
      if (mounted) {
        setState(() {
          _registrationChallenge = nextChallenge;
          _otp.clear();
        });
        showFeedbackToast(
          context,
          message: 'A new verification code was sent.',
        );
      }
    } catch (error) {
      if (mounted) _showRegistrationError(_registrationError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showRegistrationError(String message) {
    showFeedbackToast(context, message: message, isError: true);
  }

  String _registrationError(Object error) {
    if (error is ApiException && error.code == 'API_BASE_URL_MISSING') {
      return 'API URL is missing. Launch with --dart-define=GETPRIO_API_BASE_URL=<your-api-origin>.';
    }
    if (error is ApiException && error.message.isNotEmpty) return error.message;
    if (error is FormatException) return error.message;
    return 'We could not create your account. Check your connection and try again.';
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = strength.isValid
        ? GetPrioTheme.teal
        : strength.score >= 3
        ? GetPrioTheme.orange
        : theme.colorScheme.destructive;
    return Column(
      key: const Key('register-password-strength'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Password strength', style: theme.typography.small),
            Text(
              strength.label,
              style: theme.typography.small.copyWith(
                color: progressColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          key: const Key('register-password-strength-bar'),
          value: strength.score / 5,
          minHeight: 6,
          color: progressColor,
          backgroundColor: GetPrioTheme.paperAccent,
        ),
        const SizedBox(height: 8),
        _PasswordRequirement(
          label: '1 special character',
          met: strength.hasSpecialCharacter,
        ),
        _PasswordRequirement(
          label: 'At least 2 numbers',
          met: strength.hasTwoNumbers,
        ),
        _PasswordRequirement(
          label: '1 uppercase letter',
          met: strength.hasUppercase,
        ),
        _PasswordRequirement(
          label: 'At least 6 characters',
          met: strength.hasMinimumLength,
        ),
        _PasswordRequirement(
          label: 'Maximum 32 characters',
          met: strength.isWithinMaximumLength,
        ),
      ],
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            met ? LucideIcons.circleCheck : LucideIcons.circleX,
            size: 14,
            color: met ? GetPrioTheme.teal : GetPrioTheme.mutedInk,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.typography.small.copyWith(
              color: met ? GetPrioTheme.teal : GetPrioTheme.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage>
    with FormValidationMixin<PasswordRecoveryPage> {
  @override
  bool get formBusy => _busy;

  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollNotificationObserver(
      child: Scaffold(
        headers: [
          ScrollAwareAppBar(
            title: const Text('Password recovery'),
            leading: [
              GhostButton(
                onPressed: () => Navigator.of(context).pop(),
                density: ButtonDensity.icon,
                child: const Icon(LucideIcons.arrowLeft),
              ),
            ],
          ),
        ],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Reset your password').h1(),
              const SizedBox(height: 8),
              Text(
                _sent
                    ? 'If an account exists for this email, recovery instructions are on the way.'
                    : 'Enter your email and we will send recovery instructions.',
              ),
              const SizedBox(height: 20),
              if (!_sent) ...[
                _LabeledTextField(
                  controller: _email,
                  label: 'Email address',
                  placeholder: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                GetPrioActionButton.primary(
                  onPressed: _busy ? null : _request,
                  child: Text(_busy ? 'Sending...' : 'Send instructions'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _request() async {
    if (_busy || !validateForm({_email: emailField(_email.text)})) return;
    setState(() => _busy = true);
    try {
      await widget.authRepository.requestPasswordReset(_email.text.trim());
      if (mounted) {
        setState(() => _sent = true);
        showFeedbackToast(
          context,
          message: 'If an account exists for this email, recovery instructions are on the way.',
        );
      }
    } catch (_) {
      if (mounted) {
        showFormError(
          StateError('failed'),
          'Could not send recovery instructions. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    super.key,
    this.user,
    this.onSignOut,
    this.joinRepository,
    this.paymentApi,
    this.ticketRepository,
    this.queueRepository,
    this.directoryRepository,
    this.settingsRepository,
    this.securityRepository,
    this.profileRepository,
    this.onUserUpdated,
    this.paymentLinkSource,
    this.pushSignal,
    this.approvedVendorStore,
    this.allowedHosts = const {},
    this.sandbox = false,
  });

  final AuthUser? user;
  final VoidCallback? onSignOut;
  final JoinRepository? joinRepository;
  final PaymentApi? paymentApi;
  final QueueTicketRepository? ticketRepository;
  final QueueRepository? queueRepository;
  final DirectoryRepository? directoryRepository;
  final AccountSettingsRepository? settingsRepository;
  final SecurityRepository? securityRepository;
  final AccountProfileRepository? profileRepository;
  final ValueChanged<AuthUser>? onUserUpdated;
  final Set<String> allowedHosts;
  final PaymentLinkSource? paymentLinkSource;
  final ValueNotifier<PushSignal?>? pushSignal;
  final ApprovedVendorStore? approvedVendorStore;
  final bool sandbox;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell>
    with WidgetsBindingObserver {
  CustomerDestination _selectedDestination = CustomerDestination.home;
  Timer? _ticketRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.ticketRepository?.servedTicket.addListener(_promptServedTicket);
    widget.pushSignal?.addListener(_handlePushSignal);
    _startTicketRefreshFallback();
    _loadPendingInvitationAfterFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticketRefreshTimer?.cancel();
    widget.ticketRepository?.servedTicket.removeListener(_promptServedTicket);
    widget.pushSignal?.removeListener(_handlePushSignal);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.ticketRepository?.requestRefresh();
      _startTicketRefreshFallback();
      _loadPendingInvitationAfterFrame();
    } else {
      _ticketRefreshTimer?.cancel();
      _ticketRefreshTimer = null;
    }
  }

  void _promptServedTicket() {
    final ticket = widget.ticketRepository?.servedTicket.value;
    final social = widget.directoryRepository?.social;
    if (ticket == null || social == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await promptVendorRating(context, social, ticket);
    });
  }

  String? _lastInvitationNotificationId;
  final Set<String> _promptedInvitationIds = <String>{};
  final Set<String> _acceptingApprovedInvitationIds = <String>{};

  void _loadPendingInvitationAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_presentTicketInvitation());
    });
  }

  void _handlePushSignal() {
    final signal = widget.pushSignal?.value;
    if (!mounted ||
        signal == null ||
        signal.eventType != 'developer_ticket_invitation' ||
        signal.notificationId == _lastInvitationNotificationId) {
      return;
    }
    _lastInvitationNotificationId = signal.notificationId;
    _selectDestination(CustomerDestination.tickets);
    unawaited(_presentTicketInvitation(signal));
  }

  Future<void> _presentTicketInvitation([PushSignal? signal]) async {
    final repository = widget.ticketRepository;
    if (repository == null) return;
    var invitations = await repository.loadPendingInvitations();
    if (!mounted || invitations.isEmpty) return;

    invitations = await _acceptApprovedInvitations(repository, invitations);
    if (!mounted || invitations.isEmpty) return;

    TicketInvitation invitation = invitations.first;
    if (signal != null) {
      for (final candidate in invitations) {
        if (candidate.id == signal.ticketRef ||
            candidate.ticket.ticketNumber == signal.ticketRef) {
          invitation = candidate;
          break;
        }
      }
    }
    if (!_promptedInvitationIds.add(invitation.id)) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await showOverlay<bool>(
      context,
      DialogConfiguration(),
      builder: (dialogContext) {
        var alwaysAccept = false;
        final canApproveVendor =
            widget.sandbox &&
            widget.approvedVendorStore != null &&
            widget.user?.id.trim().isNotEmpty == true;
        final approvedVendor = ApprovedVendor.fromTicket(
          tenantSlug: invitation.ticket.tenantSlug,
          vendorName: invitation.ticket.vendorName,
        );
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            key: const Key('ticket-invitation-prompt'),
            leading: const Icon(LucideIcons.ticket),
            title: const Text('New ticket invitation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  invitation.ticket.locationName == null
                      ? '${invitation.ticket.vendorName ?? 'A queue'} created ticket '
                            '#${invitation.ticket.ticketNumber ?? invitation.ticket.lookupCode}. '
                            'Would you like to add it to your tickets?'
                      : '${invitation.ticket.vendorName ?? 'A queue'} · '
                            '${invitation.ticket.locationName}\n'
                            'Ticket #${invitation.ticket.ticketNumber ?? invitation.ticket.lookupCode}. '
                            'Would you like to add it to your tickets?',
                ),
                if (canApproveVendor) ...[
                  const SizedBox(height: 16),
                  Checkbox(
                    key: const Key('always-accept-ticket-invitations'),
                    state: alwaysAccept
                        ? CheckboxState.checked
                        : CheckboxState.unchecked,
                    onChanged: (state) => setDialogState(
                      () => alwaysAccept = state == CheckboxState.checked,
                    ),
                    trailing: const Text(
                      'Always accept ticket invitations from this vendor',
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              GetPrioActionButton.outline(
                onPressed: () => closeOverlay(dialogContext, false),
                child: const Text('Not now'),
              ),
              GetPrioActionButton.primary(
                onPressed: () async {
                  try {
                    await repository.acceptInvitation(invitation.id);
                    if (alwaysAccept && canApproveVendor) {
                      await widget.approvedVendorStore!.add(
                        widget.user!.id,
                        approvedVendor,
                      );
                    }
                    if (!dialogContext.mounted) return;
                    closeOverlay(dialogContext, true);
                    if (mounted) {
                      showFeedbackToast(context, message: 'Ticket accepted.');
                    }
                  } catch (_) {
                    if (mounted) {
                      showFeedbackToast(
                        context,
                        message: 'Could not accept ticket invitation.',
                        isError: true,
                      );
                    }
                  }
                },
                child: const Text('Accept ticket'),
              ),
            ],
          ),
        );
      },
    ).future;
  }

  Future<List<TicketInvitation>> _acceptApprovedInvitations(
    QueueTicketRepository repository,
    List<TicketInvitation> invitations,
  ) async {
    final store = widget.approvedVendorStore;
    final accountId = widget.user?.id;
    if (!widget.sandbox || store == null || accountId == null) {
      return invitations;
    }
    final approved = await store.load(accountId);
    if (approved.isEmpty) return invitations;
    final remaining = <TicketInvitation>[];
    for (final invitation in invitations) {
      final vendor = ApprovedVendor.fromTicket(
        tenantSlug: invitation.ticket.tenantSlug,
        vendorName: invitation.ticket.vendorName,
      );
      if (!approved.any((item) => item.key == vendor.key)) {
        remaining.add(invitation);
        continue;
      }
      if (!_acceptingApprovedInvitationIds.add(invitation.id)) continue;
      try {
        await repository.acceptInvitation(invitation.id);
        repository.requestRefresh();
      } catch (_) {
        remaining.add(invitation);
      } finally {
        _acceptingApprovedInvitationIds.remove(invitation.id);
      }
    }
    return remaining;
  }

  void _startTicketRefreshFallback() {
    _ticketRefreshTimer?.cancel();
    final repository = widget.ticketRepository;
    if (repository == null) return;
    _ticketRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (repository.hasActiveTickets) repository.requestRefresh();
      // Push delivery is best-effort. Keep checking pending invitations while
      // the app is foregrounded so a missed invitation push is recoverable.
      unawaited(_presentTicketInvitation());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: GetPrioTheme.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        footers: [
          CustomerNavigationBar(
            selectedDestination: _selectedDestination,
            onDestinationSelected: _selectDestination,
            onJoinQueue: _openJoin,
          ),
        ],
        child: SafeArea(
          top: true,
          bottom: false,
          child: IndexedStack(
            index: _selectedDestination.index,
            children: [
              HomePage(
                directoryRepository: widget.directoryRepository,
                onOpenVendor: _openFavoriteVendor,
                user: widget.user,
                ticketRepository: widget.ticketRepository,
                onOpenJoin: _openJoin,
                onOpenTicketDetails: _openTicketDetails,
              ),
              ExplorePage(
                repository: widget.directoryRepository,
                queueRepository: widget.queueRepository,
                onOpenJoin: (vendor, locationSlug) =>
                    unawaited(_openVendorJoin(vendor, locationSlug)),
              ),
              TicketsPage(
                ticketRepository: widget.ticketRepository,
                queueRepository: widget.queueRepository,
                directoryRepository: widget.directoryRepository,
              ),
              AccountPage(
                socialRepository: widget.directoryRepository?.social,
                onOpenVendor: _openFavoriteVendor,
                user: widget.user,
                onSignOut: widget.onSignOut,
                settingsRepository: widget.settingsRepository,
                securityRepository: widget.securityRepository,
                profileRepository: widget.profileRepository,
                onUserUpdated: widget.onUserUpdated,
                approvedVendorStore: widget.approvedVendorStore,
                sandbox: widget.sandbox,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFavoriteVendor(VendorSummary vendor) {
    final repository = widget.directoryRepository;
    if (repository == null) return;
    Navigator.of(context).push(
      SwipeBackPageRoute<void>(
        builder: (_) => VendorDetailPage(
          vendor: vendor,
          repository: repository,
          queueRepository: widget.queueRepository,
          onJoinLocation: (location) =>
              unawaited(_openVendorJoin(vendor, location.slug)),
        ),
      ),
    );
  }

  Future<void> _openJoin() async {
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      SwipeBackPageRoute<void>(
        builder: (context) => ScrollNotificationObserver(
          child: Scaffold(
            key: const Key('join-flow-shell'),
            headers: [
              ScrollAwareAppBar(
                title: const Text('Scan to join'),
                leading: [
                  GhostButton(
                    onPressed: () => Navigator.of(context).pop(),
                    density: ButtonDensity.icon,
                    child: const Icon(LucideIcons.arrowLeft),
                  ),
                ],
              ),
            ],
            child: JoinPage(
              repository: widget.joinRepository,
              allowedHosts: widget.allowedHosts,
              customerName: widget.user?.customerName ?? 'Customer',
              paymentApi: widget.paymentApi,
              paymentLinkSource: widget.paymentLinkSource,
              onJoined: (ticket) => _openJoinedTicket(navigator, ticket),
            ),
          ),
        ),
      ),
    );
    widget.ticketRepository?.requestRefresh();
  }

  Future<void> _openVendorJoin(
    VendorSummary vendor,
    String? locationSlug,
  ) async {
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      SwipeBackPageRoute<void>(
        builder: (context) => ScrollNotificationObserver(
          child: Scaffold(
            key: const Key('direct-join-flow-shell'),
            headers: [
              ScrollAwareAppBar(
                title: const Text('Join queue'),
                leading: [
                  GhostButton(
                    onPressed: () => Navigator.of(context).pop(),
                    density: ButtonDensity.icon,
                    child: const Icon(LucideIcons.arrowLeft),
                  ),
                ],
              ),
            ],
            child: JoinPage(
              repository: widget.joinRepository,
              allowedHosts: widget.allowedHosts,
              customerName: widget.user?.customerName ?? 'Customer',
              directTenantSlug: vendor.slug,
              directLocationSlug: locationSlug,
              paymentApi: widget.paymentApi,
              paymentLinkSource: widget.paymentLinkSource,
              onJoined: (ticket) => _openJoinedTicket(navigator, ticket),
            ),
          ),
        ),
      ),
    );
    widget.ticketRepository?.requestRefresh();
  }

  void _openJoinedTicket(NavigatorState navigator, QueueTicket ticket) {
    if (!navigator.mounted) return;
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !navigator.mounted) return;
      unawaited(
        navigator.push<void>(
          SwipeBackPageRoute<void>(
            builder: (context) => TicketDetailsPage(
              ticket: ticket,
              ticketRepository: widget.ticketRepository,
              directoryRepository: widget.directoryRepository,
              queueRepository: widget.queueRepository,
              showJoinConfirmation: true,
              onCancel:
                  ticket.canBeCancelled &&
                      ticket.tenantSlug != null &&
                      widget.queueRepository != null
                  ? () => _confirmCancellation(ticket)
                  : null,
            ),
          ),
        ),
      );
    });
  }

  void _openTicketDetails(QueueTicket ticket) {
    Navigator.of(context).push(
      SwipeBackPageRoute<void>(
        builder: (context) => TicketDetailsPage(
          ticket: ticket,
          ticketRepository: widget.ticketRepository,
          directoryRepository: widget.directoryRepository,
          queueRepository: widget.queueRepository,
          onCancel:
              ticket.canBeCancelled &&
                  ticket.tenantSlug != null &&
                  widget.queueRepository != null
              ? () => _confirmCancellation(ticket)
              : null,
        ),
      ),
    );
  }

  Future<QueueTicket?> _confirmCancellation(QueueTicket ticket) async {
    final confirmed = await showOverlay<bool>(
      context,
      DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        key: const Key('cancel-ticket-dialog'),
        leading: const Icon(LucideIcons.triangleAlert),
        title: const Text('Cancel this ticket?'),
        content: const Text(
          'You will leave the queue and this action cannot be undone.',
        ),
        actions: [
          GetPrioActionButton.outline(
            onPressed: () => closeOverlay(dialogContext, false),
            child: const Text('Keep ticket'),
          ),
          GetPrioActionButton.destructive(
            onPressed: () => closeOverlay(dialogContext, true),
            child: const Text('Cancel ticket'),
          ),
        ],
      ),
    ).future;
    if (confirmed == true && mounted) return _cancelTicket(ticket);
    return null;
  }

  Future<QueueTicket?> _cancelTicket(QueueTicket ticket) async {
    final repository = widget.queueRepository;
    final tenantSlug = ticket.tenantSlug;
    if (repository == null || tenantSlug == null) return null;
    try {
      final cancelled = await repository.cancelTicket(
        tenantSlug: tenantSlug,
        ticket: ticket,
        locationSlug: ticket.locationSlug,
      );
      if (mounted) {
        widget.ticketRepository?.requestRefresh();
        showFeedbackToast(context, message: 'Ticket cancelled.');
      }
      return cancelled;
    } catch (_) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: 'Could not cancel ticket.',
          isError: true,
        );
      }
      return null;
    }
  }

  void _selectDestination(CustomerDestination destination) {
    if (destination == CustomerDestination.explore) return;
    setState(() => _selectedDestination = destination);
    if (destination == CustomerDestination.tickets) {
      widget.ticketRepository?.requestRefresh();
    }
  }
}

const homeGreetingOpeners = <String>[
  'Welcome back',
  'Good to see you',
  'Ready when you are',
  "Let's keep things moving",
  "Here's your queue at a glance",
];

String chooseHomeGreeting({Random? random}) {
  final source = random ?? Random();
  return homeGreetingOpeners[source.nextInt(homeGreetingOpeners.length)];
}

String homeGreetingName(AuthUser? user) {
  final displayName = user?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;

  final profileName = user?.profileName?.trim();
  if (profileName == null || profileName.isEmpty) return 'there';
  return profileName.split(RegExp(r'\s+')).first;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.directoryRepository,
    this.onOpenVendor,
    this.user,
    this.ticketRepository,
    this.onOpenJoin,
    this.onOpenTicketDetails,
  });

  final DirectoryRepository? directoryRepository;
  final ValueChanged<VendorSummary>? onOpenVendor;
  final AuthUser? user;
  final QueueTicketRepository? ticketRepository;
  final VoidCallback? onOpenJoin;
  final ValueChanged<QueueTicket>? onOpenTicketDetails;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final String _greeting;

  @override
  void initState() {
    super.initState();
    _greeting = chooseHomeGreeting();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshTrigger(
      key: const Key('home-refresh'),
      onRefresh: _refresh,
      child: ListView(
        key: const Key('home-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text('$_greeting, ${homeGreetingName(widget.user)}').h2(),
          const SizedBox(height: 4),
          const Text('Stay up to date with your queue tickets.'),
          const SizedBox(height: 20),
          _ActiveTicketCard(
            ticketRepository: widget.ticketRepository,
            onOpenJoin: widget.onOpenJoin,
            onOpenTicketDetails: widget.onOpenTicketDetails,
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          const Text('Your stats').h3(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatMetric(label: 'Tickets joined', value: '0'),
              ),
              const SizedBox(
                height: 48,
                child: VerticalDivider(width: 1, thickness: 1),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _StatMetric(label: 'Tickets served', value: '0'),
              ),
            ],
          ),
          if (widget.directoryRepository?.social case final repository?) ...[
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
            const Text('Favorites').h3(),
            DrawerOverlay(
              child: FavoritesList(
                repository: repository,
                onOpen: widget.onOpenVendor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      await widget.directoryRepository?.social?.loadFavorites();
    } catch (_) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: 'Could not refresh favorites.',
          isError: true,
        );
      }
    }
    final repository = widget.ticketRepository;
    if (repository == null) return;
    repository.requestRefresh();
    if (mounted) {
      showFeedbackToast(context, message: 'Tickets refreshed.');
    }
  }
}

class _ActiveTicketCard extends StatelessWidget {
  const _ActiveTicketCard({
    this.ticketRepository,
    this.onOpenJoin,
    this.onOpenTicketDetails,
  });

  final QueueTicketRepository? ticketRepository;
  final VoidCallback? onOpenJoin;
  final ValueChanged<QueueTicket>? onOpenTicketDetails;

  @override
  Widget build(BuildContext context) {
    final repository = ticketRepository;
    if (repository == null) return _emptyCard(context);
    return ValueListenableBuilder<int>(
      valueListenable: repository.refreshVersion,
      builder: (context, refreshVersion, child) =>
          FutureBuilder<List<QueueTicket>>(
            future: repository.loadOverview(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const HomeActiveTicketSkeleton();
              }
              if (snapshot.hasError) {
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Active ticket').h3(),
                      const SizedBox(height: 12),
                      const Text('We could not refresh your active ticket.'),
                      const SizedBox(height: 12),
                      GetPrioActionButton.outline(
                        onPressed: repository.requestRefresh,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                );
              }
              final active =
                  snapshot.data?.where((ticket) => ticket.isActive).toList() ??
                  [];
              return active.isEmpty
                  ? _emptyCard(context)
                  : _ticketCard(context, active.first);
            },
          ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return Card(
      key: const Key('empty-active-ticket-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Active ticket', textAlign: TextAlign.center).h3(),
          const SizedBox(
            height: 130,
            child: Image(
              image: AssetImage('assets/illustrations/dashboard-empty.png'),
              fit: BoxFit.contain,
              semanticLabel: 'Illustration of an empty queue dashboard',
            ),
          ),
          const SizedBox(height: 16),
          const Text('No active tickets', textAlign: TextAlign.center).h3(),
          const SizedBox(height: 4),
          const Text(
            'Scan a vendor QR code when you are ready to join.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GetPrioActionButton.primary(
              key: const Key('scan-to-join-button'),
              onPressed: onOpenJoin,
              leading: const Icon(LucideIcons.scanQrCode),
              child: const Text('Scan to join'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard(BuildContext context, QueueTicket ticket) {
    return GestureDetector(
      onTap: onOpenTicketDetails == null
          ? null
          : () => onOpenTicketDetails!(ticket),
      child: Semantics(
        button: onOpenTicketDetails != null,
        label: onOpenTicketDetails == null
            ? null
            : 'Open ticket details for ${ticket.vendorName ?? 'queue'}',
        child: Card(
          key: ValueKey('home-active-ticket-${ticket.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Active ticket').h3(),
                  _TicketStatusBadge(ticket: ticket),
                ],
              ),
              const SizedBox(height: 12),
              Text(ticket.vendorName ?? 'Queue ticket').h4(),
              const SizedBox(height: 8),
              Text(
                '#${ticket.ticketNumber ?? ticket.lookupCode}',
                style: GetPrioTheme.ticketStyle(Theme.of(context)),
              ),
              if (ticket.locationName != null) ...[
                const SizedBox(height: 4),
                Text(ticket.locationName!),
              ],
              if (ticket.position != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TicketMetric(
                        label: 'Position',
                        value: '${ticket.position}',
                      ),
                    ),
                    const SizedBox(
                      height: 44,
                      child: VerticalDivider(width: 1, thickness: 1),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _TicketMetric(
                        label: 'Estimated wait',
                        value: '${ticket.estimatedWaitMinutes ?? 0} min',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _TicketProgress(ticket: ticket),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GetPrioActionButton.outline(
                  onPressed: onOpenJoin,
                  child: const Text('Join another queue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatMetric extends StatelessWidget {
  const _StatMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GetPrioTheme.ticketStyle(Theme.of(context))),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

class _TicketStatusBadge extends StatelessWidget {
  const _TicketStatusBadge({required this.ticket});

  final QueueTicket ticket;

  @override
  Widget build(BuildContext context) {
    final status = ticket.status;
    final label = ticket.displayStatusLabel.toUpperCase();
    return switch (status) {
      TicketStatus.waiting => SecondaryBadge(child: Text(label)),
      TicketStatus.pendingCarryOver => SecondaryBadge(child: Text(label)),
      TicketStatus.called => PrimaryBadge(child: Text(label)),
      TicketStatus.served => SecondaryBadge(child: Text(label)),
      TicketStatus.skipped => DestructiveBadge(child: Text(label)),
      TicketStatus.cancelled => DestructiveBadge(child: Text(label)),
      TicketStatus.unserved => DestructiveBadge(child: Text(label)),
      TicketStatus.expired => DestructiveBadge(child: Text(label)),
      TicketStatus.unknown => OutlineBadge(child: Text(label)),
    };
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    this.repository,
    this.queueRepository,
    this.onOpenJoin,
  });

  final DirectoryRepository? repository;
  final QueueRepository? queueRepository;
  final void Function(VendorSummary, String?)? onOpenJoin;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  Future<List<VendorSummary>>? _vendors;
  String _query = '';
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _vendors = widget.repository?.loadVendors();
  }

  @override
  void didUpdateWidget(covariant ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.queueRepository != widget.queueRepository) {
      _vendors = widget.repository?.loadVendors();
    }
  }

  Future<void> _reloadVendors() async {
    final repository = widget.repository;
    if (repository == null) return;
    final vendors = repository.loadVendors();
    setState(() {
      _vendors = vendors;
    });
    try {
      await vendors;
      if (mounted) {
        showFeedbackToast(context, message: 'Vendors refreshed.');
      }
    } catch (_) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: 'Could not refresh vendors.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final directoryRepository = widget.repository;
    return RefreshTrigger(
      key: const Key('explore-refresh'),
      onRefresh: _reloadVendors,
      child: ListView(
        key: const Key('explore-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const Text('Explore vendors').h2(),
          const SizedBox(height: 4),
          const Text('Browse vendors with queueing available.'),
          const SizedBox(height: 20),
          TextField(
            key: const Key('vendor-search-field'),
            placeholder: const Text('Search vendors'),
            features: const [InputFeature.leading(Icon(LucideIcons.search))],
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: 20),
          if (directoryRepository == null)
            Card(
              child: Text('Vendor directory is not configured for this build.'),
            )
          else
            FutureBuilder<List<VendorSummary>>(
              future: _vendors,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const VendorDirectorySkeleton();
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DestructiveBadge(
                        child: Text('We could not load vendors.'),
                      ),
                      const SizedBox(height: 12),
                      GetPrioActionButton.outline(
                        key: const Key('retry-vendor-directory'),
                        onPressed: _reloadVendors,
                        child: const Text('Try again'),
                      ),
                    ],
                  );
                }
                final vendors = snapshot.data ?? const <VendorSummary>[];
                if (vendors.isEmpty) {
                  return const Card(
                    child: Text('No queue-capable vendors found.'),
                  );
                }

                final categories =
                    vendors
                        .map((vendor) => vendor.category?.trim())
                        .whereType<String>()
                        .where((category) => category.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();
                final filters = ['All', 'Open now', ...categories];
                final visible = vendors.where(_matchesFilters).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: filters
                            .map(
                              (filter) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Chip(
                                  key: ValueKey('vendor-filter-$filter'),
                                  style: filter == _filter
                                      ? const ButtonStyle.primary(
                                          density: ButtonDensity.compact,
                                        )
                                      : const ButtonStyle.outline(
                                          density: ButtonDensity.compact,
                                        ),
                                  onPressed: () =>
                                      setState(() => _filter = filter),
                                  child: Text(filter),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No vendors match your search and filters.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...visible.map(
                        (vendor) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _VendorCard(
                            vendor: vendor,
                            repository: directoryRepository,
                            queueRepository: widget.queueRepository,
                            onOpenJoin: widget.onOpenJoin,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  bool _matchesFilters(VendorSummary vendor) {
    final query = _query.toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        vendor.name.toLowerCase().contains(query) ||
        (vendor.category?.toLowerCase().contains(query) ?? false);
    if (!matchesQuery) return false;
    if (_filter == 'All') return true;
    if (_filter == 'Open now') {
      return vendor.locations.any((location) => location.queueAvailable);
    }
    return vendor.category == _filter;
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.repository,
    this.queueRepository,
    this.onOpenJoin,
  });

  final VendorSummary vendor;
  final DirectoryRepository repository;
  final QueueRepository? queueRepository;
  final void Function(VendorSummary, String?)? onOpenJoin;

  @override
  Widget build(BuildContext context) {
    return CardButton(
      onPressed: () {
        Navigator.of(context).push(
          SwipeBackPageRoute<void>(
            builder: (context) => VendorDetailPage(
              vendor: vendor,
              repository: repository,
              queueRepository: queueRepository,
              onJoinLocation: onOpenJoin == null
                  ? null
                  : (location) => onOpenJoin!(vendor, location.slug),
            ),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VendorDirectoryMedia(vendor: vendor),
              const SizedBox(height: 6),
              _VendorDirectoryRating(vendor: vendor, repository: repository),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendor.name).h3(),
                if (vendor.category != null) ...[
                  const SizedBox(height: 4),
                  Text(vendor.category!),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${vendor.locations.length} queue-capable location(s)',
                      ),
                    ),
                    if (vendor.locations.any(
                      (location) => location.queueAvailable,
                    ))
                      const SecondaryBadge(child: Text('OPEN')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(LucideIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}

class _VendorDirectoryRating extends StatefulWidget {
  const _VendorDirectoryRating({
    required this.vendor,
    required this.repository,
  });

  final VendorSummary vendor;
  final DirectoryRepository repository;

  @override
  State<_VendorDirectoryRating> createState() => _VendorDirectoryRatingState();
}

class _VendorDirectoryRatingState extends State<_VendorDirectoryRating> {
  Future<VendorReviewsPage>? _rating;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _rating = widget.repository.social?.reviews(
      widget.vendor.slug,
      pageSize: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _VendorDirectoryRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vendor != widget.vendor ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<VendorReviewsPage>(
    future: _rating,
    builder: (context, snapshot) {
      final rating = snapshot.connectionState == ConnectionState.done
          ? snapshot.data
          : null;
      final rated = rating != null && rating.count > 0;
      return Semantics(
        key: ValueKey('vendor-directory-rating-${widget.vendor.slug}'),
        label: rated
            ? '${rating.average.toStringAsFixed(1)} out of 5 stars'
            : rating == null
            ? 'Rating unavailable'
            : 'Not yet rated',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rated ? Icons.star : Icons.star_border,
              size: 14,
              color: GetPrioTheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              rated ? rating.average.toStringAsFixed(1) : '—',
              style: const TextStyle(
                fontSize: GetPrioTypography.labelSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _VendorDirectoryMedia extends StatelessWidget {
  const _VendorDirectoryMedia({required this.vendor});

  final VendorSummary vendor;

  @override
  Widget build(BuildContext context) {
    final imageUrl = vendor.logoUrl ?? vendor.imageUrl;
    return Semantics(
      key: ValueKey('vendor-profile-media-${vendor.slug}'),
      container: true,
      image: true,
      excludeSemantics: true,
      label: imageUrl == null
          ? '${vendor.name} profile media unavailable'
          : '${vendor.name} profile media',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 64,
          height: 64,
          child: ColoredBox(
            color: GetPrioTheme.paperAccent,
            child: imageUrl == null
                ? _fallback()
                : Image.network(
                    imageUrl,
                    fit: _vendorBoxFit(vendor.logoFit, BoxFit.cover),
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) => _fallback(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: SvgPicture.asset(
        'assets/branding/logo.svg',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}

class VendorDetailPage extends StatefulWidget {
  const VendorDetailPage({
    super.key,
    required this.vendor,
    required this.repository,
    this.queueRepository,
    this.onJoinQueue,
    this.onJoinLocation,
    this.contactLauncher = const ExternalVendorContactLauncher(),
  });

  final VendorSummary vendor;
  final DirectoryRepository repository;
  final QueueRepository? queueRepository;
  final VoidCallback? onJoinQueue;
  final ValueChanged<VendorLocation>? onJoinLocation;
  final VendorContactLauncher contactLauncher;

  @override
  State<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends State<VendorDetailPage> {
  late Future<VendorSummary> _details;
  int _queueRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    _details = widget.repository.loadVendor(widget.vendor.slug);
  }

  @override
  void didUpdateWidget(covariant VendorDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.vendor.slug != widget.vendor.slug ||
        oldWidget.queueRepository != widget.queueRepository) {
      _details = widget.repository.loadVendor(widget.vendor.slug);
    }
  }

  Future<void> _refresh() async {
    final details = widget.repository.loadVendor(widget.vendor.slug);
    setState(() {
      _details = details;
      _queueRefreshVersion++;
    });
    try {
      await details;
      if (mounted) {
        showFeedbackToast(context, message: 'Vendor details refreshed.');
      }
    } catch (_) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: 'Could not refresh vendor details.',
          isError: true,
        );
      }
    }
  }

  Widget _refreshableMessage(Widget child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: GetPrioTheme.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Stack(
        children: [
          CustomScrollView(
            key: const Key('vendor-details-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: child),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _VendorBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectJoinLocation(
    BuildContext context,
    VendorSummary vendor,
  ) async {
    final locations = vendor.locations;
    VendorLocation? selected;
    if (locations.length == 1) {
      selected = locations.single;
    } else if (locations.isNotEmpty) {
      selected = await openDrawerOverlay<VendorLocation>(
        context: context,
        position: OverlayPosition.bottom,
        expands: false,
        draggable: true,
        transformBackdrop: false,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                GetPrioTheme.bottomSheetTopPadding,
                20,
                20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select a location').h3(),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: locations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final location = locations[index];
                        return CardButton(
                          key: ValueKey('join-location-${location.id}'),
                          onPressed: location.slug?.trim().isNotEmpty == true
                              ? () => closeDrawer(sheetContext, location)
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(location.name).bold(),
                              if (location.address != null)
                                Text(location.address!),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).future;
    }
    if (!mounted) return;
    if (selected != null && selected.slug?.trim().isNotEmpty == true) {
      if (widget.onJoinLocation != null) {
        widget.onJoinLocation!(selected);
      } else {
        widget.onJoinQueue?.call();
      }
    } else if (locations.isEmpty && context.mounted) {
      showFeedbackToast(
        context,
        message: 'No queue locations are available.',
        isError: true,
      );
    }
  }

  void _openContactSheet(BuildContext context, VendorSummary vendor) {
    final email = vendor.contactEmail;
    if (email == null) return;
    openDrawerOverlay<void>(
      context: context,
      position: OverlayPosition.bottom,
      expands: true,
      draggable: true,
      useSafeArea: false,
      borderRadius: _VendorContactSheet.borderRadius,
      transformBackdrop: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      builder: (context) => _VendorContactSheet(
        vendor: vendor,
        recipient: email,
        launcher: widget.contactLauncher,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerOverlay(
      child: Scaffold(
        child: RefreshTrigger(
          key: const Key('vendor-details-refresh'),
          onRefresh: _refresh,
          child: FutureBuilder<VendorSummary>(
            future: _details,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return _refreshableMessage(const VendorDetailsSkeleton());
              }
              if (snapshot.hasError) {
                return _refreshableMessage(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DestructiveBadge(
                        child: Text('Vendor details are unavailable.'),
                      ),
                      const SizedBox(height: 12),
                      GetPrioActionButton.outline(
                        key: const Key('retry-vendor-details'),
                        onPressed: _refresh,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                );
              }
              final details = snapshot.data ?? widget.vendor;
              final openLocations = details.locations
                  .where((location) => location.queueAvailable)
                  .length;
              return _VendorProfileView(
                socialRepository: widget.repository.social,
                vendor: details,
                openLocations: openLocations,
                queueRepository: widget.queueRepository,
                queueRefreshVersion: _queueRefreshVersion,
                onBack: () => Navigator.of(context).pop(),
                onJoinQueue:
                    widget.onJoinLocation == null && widget.onJoinQueue == null
                    ? null
                    : () => _selectJoinLocation(context, details),
                onContact: details.contactEmail == null
                    ? null
                    : () => _openContactSheet(context, details),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VendorProfileView extends StatelessWidget {
  const _VendorProfileView({
    this.socialRepository,
    required this.vendor,
    required this.openLocations,
    required this.queueRepository,
    required this.queueRefreshVersion,
    required this.onBack,
    required this.onJoinQueue,
    required this.onContact,
  });

  static const surfaceOverlap = 44.0;
  static const logoSize = 104.0;

  final VendorSocialRepository? socialRepository;
  final VendorSummary vendor;
  final int openLocations;
  final QueueRepository? queueRepository;
  final int queueRefreshVersion;
  final VoidCallback onBack;
  final VoidCallback? onJoinQueue;
  final VoidCallback? onContact;

  void _openStoreHoursSheet(BuildContext context, VendorLocation location) {
    openDrawerOverlay<void>(
      context: context,
      position: OverlayPosition.bottom,
      expands: true,
      draggable: true,
      useSafeArea: false,
      borderRadius: _VendorStoreHoursSheet.borderRadius,
      transformBackdrop: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      builder: (context) => _VendorStoreHoursSheet(location: location),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverHeight = (MediaQuery.sizeOf(context).height * 0.5).clamp(
      360.0,
      480.0,
    );
    final surface = Padding(
      padding: EdgeInsets.only(top: coverHeight - surfaceOverlap),
      child: Container(
        key: const Key('vendor-detail-surface'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 48),
        decoration: const BoxDecoration(
          color: GetPrioTheme.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x245B422A),
              blurRadius: 28,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor.name, style: theme.typography.h1),
                      if (vendor.category != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          vendor.category!,
                          style: theme.typography.p.copyWith(
                            color: GetPrioTheme.mutedInk,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _VendorContactButton(onPressed: onContact),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _VendorHighlight(
                    value: '${vendor.locations.length}',
                    label: vendor.locations.length == 1
                        ? 'Location'
                        : 'Locations',
                  ),
                ),
                const SizedBox(
                  height: 52,
                  child: VerticalDivider(width: 1, thickness: 1),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _VendorHighlight(
                    value: '$openLocations',
                    label: openLocations == 1 ? 'Queue open' : 'Queues open',
                  ),
                ),
              ],
            ),
            if (vendor.description != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              const Text('About').h3(),
              const SizedBox(height: 10),
              _ExpandableVendorDescription(description: vendor.description!),
            ],
            const SizedBox(height: 32),
            const Text('Queue-capable locations').h3(),
            const SizedBox(height: 8),
            if (vendor.locations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No queue-capable locations are listed.'),
              )
            else ...[
              for (var index = 0; index < vendor.locations.length; index++) ...[
                _VendorLocationRow(
                  location: vendor.locations[index],
                  onShowStoreHours: () =>
                      _openStoreHoursSheet(context, vendor.locations[index]),
                ),
                if (queueRepository != null)
                  _VendorQueueStatus(
                    vendor: vendor,
                    location: vendor.locations[index],
                    queueRepository: queueRepository!,
                    refreshVersion: queueRefreshVersion,
                  ),
                if (index < vendor.locations.length - 1) const Divider(),
              ],
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            const Text('Reviews').h3(),
            const SizedBox(height: 12),
            if (socialRepository case final repository?)
              VendorReviews(repository: repository, slug: vendor.slug)
            else
              const Text('Reviews are unavailable.'),
            const SizedBox(height: 20),
            Container(
              key: const Key('vendor-join-instructions'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GetPrioTheme.paperAccent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.scanQrCode, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'To join, scan the QR code displayed at the location.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: GetPrioTheme.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: _VendorProfileParallax(
        socialRepository: socialRepository,
        vendor: vendor,
        coverHeight: coverHeight,
        logoSize: logoSize,
        onBack: onBack,
        onJoinQueue: onJoinQueue,
        surface: surface,
      ),
    );
  }
}

class _VendorProfileParallax extends StatefulWidget {
  const _VendorProfileParallax({
    this.socialRepository,
    required this.vendor,
    required this.coverHeight,
    required this.logoSize,
    required this.onBack,
    required this.onJoinQueue,
    required this.surface,
  });

  final VendorSocialRepository? socialRepository;
  final VendorSummary vendor;
  final double coverHeight;
  final double logoSize;
  final VoidCallback onBack;
  final VoidCallback? onJoinQueue;
  final Widget surface;

  @override
  State<_VendorProfileParallax> createState() => _VendorProfileParallaxState();
}

class _VendorProfileParallaxState extends State<_VendorProfileParallax> {
  static const coverParallaxFactor = 0.28;
  static const logoParallaxFactor = 0.7;
  static const logoFadeViewportFraction = 0.5;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoTop = (widget.coverHeight - widget.logoSize) / 2;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              final scrollOffset = _scrollController.hasClients
                  ? _scrollController.offset.clamp(0.0, double.infinity)
                  : 0.0;
              return Transform.translate(
                offset: Offset(0, -scrollOffset * coverParallaxFactor),
                child: child,
              );
            },
            child: _VendorProfileCover(
              vendor: widget.vendor,
              height: widget.coverHeight,
            ),
          ),
        ),
        Positioned(
          top: logoTop,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              final scrollOffset = _scrollController.hasClients
                  ? _scrollController.offset.clamp(0.0, double.infinity)
                  : 0.0;
              final fadeDistance =
                  MediaQuery.sizeOf(context).height * logoFadeViewportFraction;
              final logoOpacity = fadeDistance <= 0
                  ? 0.0
                  : (1 - scrollOffset / fadeDistance).clamp(0.0, 1.0);
              return Opacity(
                key: const Key('vendor-profile-logo-opacity'),
                opacity: logoOpacity.toDouble(),
                child: Transform.translate(
                  offset: Offset(0, scrollOffset * logoParallaxFactor),
                  child: child,
                ),
              );
            },
            child: Center(
              child: _VendorLogo(vendor: widget.vendor, size: widget.logoSize),
            ),
          ),
        ),
        ListView(
          key: const Key('vendor-details-scroll'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: 96 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [widget.surface],
        ),
        if (widget.socialRepository case final repository?)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 20,
            child: AnimatedBuilder(
              animation: _scrollController,
              child: VendorSocialHeader(
                repository: repository,
                vendor: widget.vendor,
              ),
              builder: (context, child) {
                final scrollOffset = _scrollController.hasClients
                    ? _scrollController.offset
                    : 0.0;
                final progress = (scrollOffset / 100).clamp(0.0, 1.0);
                final slide = Curves.easeIn.transform(progress);
                return IgnorePointer(
                  ignoring: progress >= 1,
                  child: ExcludeSemantics(
                    excluding: progress >= 1,
                    child: Transform.translate(
                      offset: Offset(20 * slide, 0),
                      child: FractionalTranslation(
                        key: const Key('vendor-social-parallax'),
                        translation: Offset(slide, 0),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          left: 20,
          child: _VendorBackButton(onPressed: widget.onBack, onImage: true),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            key: const Key('vendor-join-queue-action-surface'),
            color: GetPrioTheme.paper,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: GetPrioActionButton.primary(
              key: const Key('vendor-join-queue-button'),
              onPressed: widget.onJoinQueue,
              child: const Text('Join Queue'),
            ),
          ),
        ),
      ],
    );
  }
}

class _VendorProfileCover extends StatelessWidget {
  const _VendorProfileCover({required this.vendor, required this.height});

  final VendorSummary vendor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = vendor.coverImageUrl;
    return SizedBox(
      key: const Key('vendor-profile-cover'),
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl == null)
            _vendorCoverFallback()
          else
            Image.network(
              imageUrl,
              fit: _vendorBoxFit(vendor.coverImageFit, BoxFit.cover),
              semanticLabel: '${vendor.name} profile cover',
              errorBuilder: (context, error, stackTrace) =>
                  _vendorCoverFallback(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x75000000), Color(0x00000000)],
                stops: [0, 0.55],
              ),
            ),
          ),
          const DecoratedBox(
            key: Key('profile-cover-surface-fade'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [GetPrioTheme.paper, Color(0x00FBF7F1)],
                stops: [0.0, 0.3],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vendorCoverFallback() {
    return Container(
      color: GetPrioTheme.paperAccent,
      padding: const EdgeInsets.fromLTRB(48, 64, 48, 36),
      child: const Image(
        image: AssetImage(
          'assets/illustrations/hero-queue-scene-transparent.png',
        ),
        fit: BoxFit.contain,
        semanticLabel: 'Illustration of a customer at a queue',
      ),
    );
  }
}

class _VendorLogo extends StatelessWidget {
  const _VendorLogo({required this.vendor, required this.size});

  final VendorSummary vendor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = vendor.logoUrl;
    return SizedBox(
      key: const Key('vendor-logo'),
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: GetPrioTheme.card,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xF2FFFFFF), width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x3D23180F),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ClipOval(
            child: imageUrl == null
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: SvgPicture.asset(
                      'assets/branding/logo.svg',
                      fit: BoxFit.contain,
                      semanticsLabel: 'GetPrio vendor logo placeholder',
                    ),
                  )
                : Image.network(
                    imageUrl,
                    fit: _vendorBoxFit(vendor.logoFit, BoxFit.cover),
                    semanticLabel: '${vendor.name} logo',
                    errorBuilder: (context, error, stackTrace) => Padding(
                      padding: const EdgeInsets.all(18),
                      child: SvgPicture.asset(
                        'assets/branding/logo.svg',
                        fit: BoxFit.contain,
                        semanticsLabel: 'GetPrio vendor logo placeholder',
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _VendorBackButton extends StatelessWidget {
  const _VendorBackButton({required this.onPressed, this.onImage = false});

  final VoidCallback onPressed;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onImage ? GetPrioTheme.card.withAlpha(224) : GetPrioTheme.card,
          shape: BoxShape.circle,
          border: Border.all(color: GetPrioTheme.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x245B422A),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: GhostButton(
          onPressed: onPressed,
          density: ButtonDensity.icon,
          child: const Icon(LucideIcons.arrowLeft, size: 22),
        ),
      ),
    );
  }
}

class _VendorContactButton extends StatelessWidget {
  const _VendorContactButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: onPressed == null
          ? 'Vendor contact email unavailable'
          : 'Contact vendor',
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: GetPrioTheme.card,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: GetPrioTheme.line)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F5B422A),
              blurRadius: 16,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: GhostButton(
          key: const Key('vendor-contact-button'),
          onPressed: onPressed,
          density: ButtonDensity.icon,
          child: Icon(
            LucideIcons.messageCircle,
            size: 23,
            color: onPressed == null
                ? GetPrioTheme.disabled
                : GetPrioTheme.orange,
          ),
        ),
      ),
    );
  }
}

class _VendorContactSheet extends StatefulWidget {
  const _VendorContactSheet({
    required this.vendor,
    required this.recipient,
    required this.launcher,
  });

  static const borderRadius = BorderRadius.vertical(top: Radius.circular(28));

  final VendorSummary vendor;
  final String recipient;
  final VendorContactLauncher launcher;

  @override
  State<_VendorContactSheet> createState() => _VendorContactSheetState();
}

class _VendorContactSheetState extends State<_VendorContactSheet>
    with FormValidationMixin<_VendorContactSheet> {
  @override
  bool get formBusy => _busy;

  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _continueToEmail() async {
    if (_busy ||
        !validateForm({
          _subject: requiredField(_subject.text, 'Subject'),
          _message: requiredField(_message.text, 'Message'),
        })) {
      return;
    }
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      setState(() => _error = 'Add a subject and message to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    var opened = false;
    try {
      opened = await widget.launcher.openEmail(
        recipient: widget.recipient,
        subject: subject,
        message: message,
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (opened) {
      await closeSheet(context);
      return;
    }
    setState(() => _busy = false);
    showFormError(
      StateError('unavailable'),
      'No email app is available on this device.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('vendor-contact-sheet'),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: GetPrioTheme.card,
        borderRadius: _VendorContactSheet.borderRadius,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            GetPrioTheme.bottomSheetTopPadding,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Contact ${widget.vendor.name}',
                      style: theme.typography.h2,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close contact form',
                    child: GhostButton(
                      onPressed: () => closeSheet(context),
                      density: ButtonDensity.icon,
                      child: const Icon(LucideIcons.x),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Write your message here, then continue in your email app.',
                style: theme.typography.p.copyWith(
                  color: GetPrioTheme.mutedInk,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: GetPrioTheme.paperAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.mail, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.recipient)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Subject',
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ValidatedField(
                validation: formValidation,
                controller: _subject,
                child: TextField(
                  key: const Key('vendor-contact-subject'),
                  enabled: !_busy,
                  controller: _subject,
                  placeholder: const Text('What would you like to ask?'),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Message',
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ValidatedField(
                validation: formValidation,
                controller: _message,
                child: TextArea(
                  key: const Key('vendor-contact-message'),
                  enabled: !_busy,
                  controller: _message,
                  placeholder: const Text('Write your message'),
                  initialHeight: 132,
                  minHeight: 132,
                  maxHeight: 220,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                DestructiveBadge(child: Text(_error!)),
              ],
              const SizedBox(height: 20),
              GetPrioActionButton.primary(
                key: const Key('vendor-contact-continue'),
                onPressed: _busy ? null : _continueToEmail,
                leading: const Icon(LucideIcons.externalLink, size: 18),
                child: Text(_busy ? 'Opening email...' : 'Continue to email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandableVendorDescription extends StatefulWidget {
  const _ExpandableVendorDescription({required this.description});

  final String description;

  @override
  State<_ExpandableVendorDescription> createState() =>
      _ExpandableVendorDescriptionState();
}

class _ExpandableVendorDescriptionState
    extends State<_ExpandableVendorDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final canExpand = widget.description.length > 320;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.description,
          maxLines: canExpand && !_expanded ? 7 : null,
          overflow: canExpand && !_expanded
              ? TextOverflow.ellipsis
              : TextOverflow.visible,
        ),
        if (canExpand) ...[
          const SizedBox(height: 8),
          GhostButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            density: ButtonDensity.compact,
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
        ],
      ],
    );
  }
}

BoxFit _vendorBoxFit(String? value, BoxFit fallback) {
  return switch (value?.trim().toLowerCase()) {
    'contain' => BoxFit.contain,
    'fill' => BoxFit.fill,
    'fitwidth' || 'fit-width' => BoxFit.fitWidth,
    'fitheight' || 'fit-height' => BoxFit.fitHeight,
    'none' => BoxFit.none,
    'scaledown' || 'scale-down' => BoxFit.scaleDown,
    'cover' => BoxFit.cover,
    _ => fallback,
  };
}

class _VendorHighlight extends StatelessWidget {
  const _VendorHighlight({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).typography.h2),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

class _VendorLocationRow extends StatelessWidget {
  const _VendorLocationRow({
    required this.location,
    required this.onShowStoreHours,
  });

  final VendorLocation location;
  final VoidCallback onShowStoreHours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: GetPrioTheme.paperAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.mapPin, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        location.name,
                        style: theme.typography.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    location.queueAvailable
                        ? const SecondaryBadge(child: Text('STORE OPEN'))
                        : const DestructiveBadge(child: Text('UNAVAILABLE')),
                  ],
                ),
                if (location.address != null) ...[
                  const SizedBox(height: 5),
                  Text(location.address!, style: theme.typography.textMuted),
                ],
                if (location.openStatus != null ||
                    location.hours.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  GetPrioActionButton.outline(
                    key: ValueKey(
                      'store-hours-button-${location.slug ?? location.id}',
                    ),
                    onPressed: onShowStoreHours,
                    leading: const Icon(LucideIcons.clock, size: 18),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    child: const Text('Show store hours'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorStoreHoursSheet extends StatelessWidget {
  const _VendorStoreHoursSheet({required this.location});

  static const borderRadius = BorderRadius.vertical(top: Radius.circular(28));

  final VendorLocation location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = [...location.hours]
      ..sort((left, right) => left.weekday.compareTo(right.weekday));
    return Container(
      key: const Key('vendor-store-hours-sheet'),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: GetPrioTheme.card,
        borderRadius: borderRadius,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            GetPrioTheme.bottomSheetTopPadding,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Store hours', style: theme.typography.h2),
                        const SizedBox(height: 4),
                        Text(
                          location.name,
                          style: theme.typography.p.copyWith(
                            color: GetPrioTheme.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close store hours',
                    child: GhostButton(
                      onPressed: () => closeSheet(context),
                      density: ButtonDensity.icon,
                      child: const Icon(LucideIcons.x),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (hours.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GetPrioTheme.paperAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    location.openStatus ?? 'Store hours are unavailable.',
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: GetPrioTheme.paper,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GetPrioTheme.line),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < hours.length; index++) ...[
                        _VendorStoreHoursRow(hour: hours[index]),
                        if (index < hours.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorStoreHoursRow extends StatelessWidget {
  const _VendorStoreHoursRow({required this.hour});

  final VendorStoreHour hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _storeHourWeekdayLabel(hour.weekday),
              style: theme.typography.p.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _storeHourRangeLabel(hour),
            textAlign: TextAlign.right,
            style: theme.typography.p.copyWith(
              color: hour.isClosed ? GetPrioTheme.mutedInk : GetPrioTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

const _storeHourWeekdays = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

String _storeHourWeekdayLabel(int weekday) {
  if (weekday < 0 || weekday >= _storeHourWeekdays.length) {
    return 'Day ${weekday + 1}';
  }
  return _storeHourWeekdays[weekday];
}

String _storeHourRangeLabel(VendorStoreHour hour) {
  if (hour.isClosed) return 'Closed';
  if (hour.opensAt.isEmpty || hour.closesAt.isEmpty) {
    return 'Hours unavailable';
  }
  if (hour.opensAt == '00:00' && hour.closesAt == '00:00') {
    return 'Open 24 hours';
  }

  final opensAt = _storeHourTimeLabel(hour.opensAt);
  final closesAt = _storeHourTimeLabel(hour.closesAt);
  final opensMinutes = _storeHourMinutes(hour.opensAt);
  final closesMinutes = _storeHourMinutes(hour.closesAt);
  if (opensAt == null || closesAt == null) {
    return '${hour.opensAt} - ${hour.closesAt}';
  }
  final nextDay =
      opensMinutes != null &&
      closesMinutes != null &&
      closesMinutes < opensMinutes;
  return '$opensAt – $closesAt${nextDay ? ' next day' : ''}';
}

String? _storeHourTimeLabel(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}

int? _storeHourMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return hour * 60 + minute;
}

class _VendorQueueStatus extends StatefulWidget {
  const _VendorQueueStatus({
    required this.vendor,
    required this.location,
    required this.queueRepository,
    required this.refreshVersion,
  });

  final VendorSummary vendor;
  final VendorLocation location;
  final QueueRepository queueRepository;
  final int refreshVersion;

  @override
  State<_VendorQueueStatus> createState() => _VendorQueueStatusState();
}

class _VendorQueueStatusState extends State<_VendorQueueStatus> {
  late Future<QueueSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _loadSnapshot();
  }

  @override
  void didUpdateWidget(covariant _VendorQueueStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queueRepository != widget.queueRepository ||
        oldWidget.vendor.slug != widget.vendor.slug ||
        oldWidget.location.slug != widget.location.slug ||
        oldWidget.refreshVersion != widget.refreshVersion) {
      _snapshot = _loadSnapshot();
    }
  }

  Future<QueueSnapshot> _loadSnapshot() {
    return widget.queueRepository.loadQueueSnapshot(
      tenantSlug: widget.vendor.slug,
      locationSlug: widget.location.slug,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52, bottom: 12),
      child: Card(
        key: ValueKey(
          'vendor-queue-status-${widget.location.slug ?? widget.location.id}',
        ),
        child: FutureBuilder<QueueSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LiveQueueStatusSkeleton();
            }
            if (snapshot.hasError) {
              return const Text('Live queue status is unavailable right now.');
            }
            return _content(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _content(QueueSnapshot snapshot) {
    final isClosed =
        snapshot.locationStatus?.isOpen == false ||
        snapshot.queueDay.isClosed ||
        snapshot.queueDay.state == 'closed' ||
        snapshot.queueIntake.state == 'closed';
    final isPaused =
        !isClosed &&
        (snapshot.queueDay.isPaused ||
            snapshot.queueDay.intakeMode == 'paused' ||
            snapshot.queueIntake.state == 'paused');
    final status = isClosed
        ? const DestructiveBadge(child: Text('QUEUE CLOSED'))
        : isPaused
        ? const SecondaryBadge(child: Text('PAUSED'))
        : const PrimaryBadge(child: Text('QUEUE OPEN'));
    final current =
        snapshot.current?.ticketNumber ??
        snapshot.stats.currentTicketNumber ??
        '--';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Current queue').h4(), status],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _VendorQueueMetric(
                value: '${snapshot.stats.waitingCount} waiting',
                label: 'in line',
              ),
            ),
            const SizedBox(
              height: 42,
              child: VerticalDivider(width: 1, thickness: 1),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _VendorQueueMetric(
                value:
                    '${snapshot.stats.estimatedWaitMinutes} min estimated wait',
                label: 'for a new join',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Currently serving $current'),
      ],
    );
  }
}

class _VendorQueueMetric extends StatelessWidget {
  const _VendorQueueMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).typography.p
              .copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).typography.textMuted),
      ],
    );
  }
}

class TicketsPage extends StatefulWidget {
  const TicketsPage({
    super.key,
    this.ticketRepository,
    this.queueRepository,
    this.directoryRepository,
  });

  final QueueTicketRepository? ticketRepository;
  final QueueRepository? queueRepository;
  final DirectoryRepository? directoryRepository;

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  late Future<List<QueueTicket>> _tickets;
  List<QueueTicket>? _visibleTickets;
  List<TicketInvitation>? _visibleInvitations;
  int _loadGeneration = 0;
  String? _cancellingTicketId;
  String? _acceptingInvitationId;

  @override
  void initState() {
    super.initState();
    widget.ticketRepository?.refreshVersion.addListener(_reload);
    _tickets = _loadTickets();
    unawaited(_loadInvitations());
  }

  @override
  void dispose() {
    widget.ticketRepository?.refreshVersion.removeListener(_reload);
    super.dispose();
  }

  Future<List<QueueTicket>> _loadTickets() async {
    final repository = widget.ticketRepository;
    if (repository == null) return const [];
    final generation = ++_loadGeneration;
    final tickets = await repository.loadAllTickets();
    if (mounted && generation == _loadGeneration) {
      setState(() => _visibleTickets = tickets);
    }
    return tickets;
  }

  Future<List<TicketInvitation>> _loadInvitations() async {
    final repository = widget.ticketRepository;
    if (repository == null) return const [];
    try {
      final invitations = await repository.loadPendingInvitations();
      if (mounted) setState(() => _visibleInvitations = invitations);
      return invitations;
    } catch (_) {
      if (mounted) setState(() => _visibleInvitations = const []);
      return const [];
    }
  }

  void _reload() {
    if (!mounted) return;
    final tickets = _loadTickets();
    unawaited(_loadInvitations());
    setState(() {
      _cancellingTicketId = null;
      _tickets = tickets;
    });
  }

  Future<void> _refreshTickets() async {
    _reload();
    try {
      await _tickets;
      if (mounted) {
        showFeedbackToast(context, message: 'Tickets refreshed.');
      }
    } catch (_) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: 'Could not refresh tickets.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QueueTicket>>(
      future: _tickets,
      builder: (context, snapshot) {
        final tickets =
            _visibleTickets ?? snapshot.data ?? const <QueueTicket>[];
        final active = tickets.where((ticket) => ticket.isActive).toList();
        final history = tickets.where((ticket) => !ticket.isActive).toList();
        final isInitialLoading =
            _visibleTickets == null &&
            snapshot.connectionState == ConnectionState.waiting;
        final hasInitialError = _visibleTickets == null && snapshot.hasError;
        return RefreshTrigger(
          key: const Key('tickets-refresh'),
          onRefresh: _refreshTickets,
          child: ListView(
            key: const Key('tickets-page'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const Text('My tickets').h2(),
              const SizedBox(height: 4),
              const Text('Active and historical queue tickets.'),
              const SizedBox(height: 20),
              if (_visibleInvitations?.isNotEmpty == true) ...[
                _ticketInvitationCard(_visibleInvitations!),
                const SizedBox(height: 24),
              ],
              if (isInitialLoading)
                const TicketsSkeleton()
              else if (hasInitialError) ...[
                const DestructiveBadge(
                  child: Text('We could not load your tickets.'),
                ),
                const SizedBox(height: 12),
                GetPrioActionButton.outline(
                  onPressed: _reload,
                  child: const Text('Try again'),
                ),
              ] else if (tickets.isEmpty)
                Card(
                  child: Column(
                    children: [
                      Icon(LucideIcons.ticket, size: 40),
                      SizedBox(height: 12),
                      Text('No tickets yet').h3(),
                      SizedBox(height: 4),
                      Text('Your queue tickets will appear here.'),
                    ],
                  ),
                )
              else ...[
                if (active.isNotEmpty) ...[
                  const Text('Active').h3(),
                  const SizedBox(height: 12),
                  ...active.map(_activeTicketCard),
                ],
                if (history.isNotEmpty) ...[
                  if (active.isNotEmpty) const SizedBox(height: 28),
                  const Text('History').h3(),
                  const SizedBox(height: 8),
                  for (var index = 0; index < history.length; index++) ...[
                    _historyTicketRow(history[index]),
                    if (index < history.length - 1) const Divider(),
                  ],
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _ticketInvitationCard(List<TicketInvitation> invitations) {
    return Card(
      key: const Key('ticket-invitations'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New ticket invitation').h3(),
          const SizedBox(height: 6),
          const Text(
            'A queue ticket was created for your GetPrio email. Accept it to add it to your tickets.',
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < invitations.length; index++) ...[
            if (index > 0) const Divider(),
            _ticketInvitationRow(invitations[index]),
          ],
        ],
      ),
    );
  }

  Widget _ticketInvitationRow(TicketInvitation invitation) {
    final ticket = invitation.ticket;
    final isAccepting = _acceptingInvitationId == invitation.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ticket.vendorName ?? 'Queue ticket').h4(),
        if (ticket.locationName != null) ...[
          const SizedBox(height: 4),
          Text(ticket.locationName!),
        ],
        const SizedBox(height: 4),
        Text('Ticket #${ticket.ticketNumber ?? ticket.lookupCode}'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GetPrioActionButton.primary(
                key: ValueKey('accept-ticket-invitation-${invitation.id}'),
                onPressed: isAccepting
                    ? null
                    : () => _acceptInvitation(invitation),
                child: Text(isAccepting ? 'Accepting...' : 'Accept ticket'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GetPrioActionButton.outline(
                onPressed: isAccepting
                    ? null
                    : () => setState(
                        () => _visibleInvitations = _visibleInvitations
                            ?.where((item) => item.id != invitation.id)
                            .toList(growable: false),
                      ),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _acceptInvitation(TicketInvitation invitation) async {
    final repository = widget.ticketRepository;
    if (repository == null) return;
    setState(() => _acceptingInvitationId = invitation.id);
    try {
      final acceptedTicket = await repository.acceptInvitation(invitation.id);
      if (mounted) {
        setState(() {
          _acceptingInvitationId = null;
          _visibleInvitations = _visibleInvitations
              ?.where((item) => item.id != invitation.id)
              .toList(growable: false);
          final currentTickets = _visibleTickets ?? const <QueueTicket>[];
          _visibleTickets = [
            acceptedTicket,
            ...currentTickets.where((ticket) => ticket.id != acceptedTicket.id),
          ];
        });
        showFeedbackToast(context, message: 'Ticket accepted.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _acceptingInvitationId = null);
        showFeedbackToast(
          context,
          message: 'Could not accept ticket invitation.',
          isError: true,
        );
      }
    }
  }

  Widget _activeTicketCard(QueueTicket ticket) {
    final canCancel =
        ticket.canBeCancelled &&
        ticket.tenantSlug != null &&
        widget.queueRepository != null;
    final isCancelling = _cancellingTicketId == ticket.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openTicketDetails(ticket),
        child: Semantics(
          button: true,
          label: 'Open ticket details for ${ticket.vendorName ?? 'queue'}',
          child: Card(
            key: ValueKey('active-ticket-${ticket.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ticket.vendorName ?? 'Queue ticket').h3(),
                    _TicketStatusBadge(ticket: ticket),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '#${ticket.ticketNumber ?? ticket.lookupCode}',
                  style: GetPrioTheme.ticketStyle(Theme.of(context)),
                ),
                if (ticket.locationName != null) ...[
                  const SizedBox(height: 4),
                  Text(ticket.locationName!),
                ],
                if (ticket.position != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _TicketMetric(
                          label: 'Position',
                          value: '${ticket.position}',
                        ),
                      ),
                      const SizedBox(
                        height: 44,
                        child: VerticalDivider(width: 1, thickness: 1),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _TicketMetric(
                          label: 'Estimated wait',
                          value: '${ticket.estimatedWaitMinutes ?? 0} min',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _TicketProgress(ticket: ticket),
                if (canCancel) ...[
                  const SizedBox(height: 20),
                  GetPrioActionButton.destructive(
                    onPressed: isCancelling
                        ? null
                        : () => _confirmCancellation(ticket),
                    child: Text(
                      isCancelling ? 'Cancelling...' : 'Cancel ticket',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyTicketRow(QueueTicket ticket) {
    return GestureDetector(
      onTap: () => _openTicketDetails(ticket),
      child: Semantics(
        button: true,
        label: 'Open ticket details for ${ticket.vendorName ?? 'queue'}',
        child: Padding(
          key: ValueKey('history-ticket-${ticket.id}'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GetPrioTheme.paperAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.ticket, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticket.vendorName ?? 'Queue ticket').h4(),
                    const SizedBox(height: 4),
                    Text('Ticket #${ticket.ticketNumber ?? ticket.lookupCode}'),
                    if (ticket.locationName != null) Text(ticket.locationName!),
                    if (ticket.joinedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(_formatTicketDate(ticket.joinedAt!)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TicketStatusBadge(ticket: ticket),
            ],
          ),
        ),
      ),
    );
  }

  void _openTicketDetails(QueueTicket ticket) {
    Navigator.of(context).push(
      SwipeBackPageRoute<void>(
        builder: (context) => TicketDetailsPage(
          ticket: ticket,
          directoryRepository: widget.directoryRepository,
          queueRepository: widget.queueRepository,
          onCancel: ticket.canBeCancelled
              ? () => _confirmCancellation(ticket)
              : null,
        ),
      ),
    );
  }

  String _formatTicketDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  Future<QueueTicket?> _confirmCancellation(QueueTicket ticket) async {
    final confirmed = await showOverlay<bool>(
      context,
      DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        key: const Key('cancel-ticket-dialog'),
        leading: const Icon(LucideIcons.triangleAlert),
        title: const Text('Cancel this ticket?'),
        content: const Text(
          'You will leave the queue and this action cannot be undone.',
        ),
        actions: [
          GetPrioActionButton.outline(
            onPressed: () => closeOverlay(dialogContext, false),
            child: const Text('Keep ticket'),
          ),
          GetPrioActionButton.destructive(
            onPressed: () => closeOverlay(dialogContext, true),
            child: const Text('Cancel ticket'),
          ),
        ],
      ),
    ).future;
    if (confirmed == true && mounted) return _cancel(ticket);
    return null;
  }

  Future<QueueTicket?> _cancel(QueueTicket ticket) async {
    final repository = widget.queueRepository;
    final tenantSlug = ticket.tenantSlug;
    if (repository == null || tenantSlug == null) return null;
    setState(() => _cancellingTicketId = ticket.id);
    try {
      final cancelled = await repository.cancelTicket(
        tenantSlug: tenantSlug,
        ticket: ticket,
        locationSlug: ticket.locationSlug,
      );
      if (mounted) {
        final ticketRepository = widget.ticketRepository;
        if (ticketRepository == null) {
          _reload();
        } else {
          ticketRepository.requestRefresh();
        }
        showFeedbackToast(context, message: 'Ticket cancelled.');
      }
      return cancelled;
    } catch (_) {
      if (mounted) {
        setState(() => _cancellingTicketId = null);
        showFeedbackToast(
          context,
          message: 'Could not cancel ticket.',
          isError: true,
        );
      }
      return null;
    }
  }
}

class TicketDetailsPage extends StatefulWidget {
  const TicketDetailsPage({
    super.key,
    required this.ticket,
    this.showJoinConfirmation = false,
    this.ticketRepository,
    this.directoryRepository,
    this.queueRepository,
    this.onCancel,
  });

  final QueueTicket ticket;
  final bool showJoinConfirmation;
  final QueueTicketRepository? ticketRepository;
  final DirectoryRepository? directoryRepository;
  final QueueRepository? queueRepository;
  final Future<QueueTicket?> Function()? onCancel;

  @override
  State<TicketDetailsPage> createState() => _TicketDetailsPageState();
}

class _TicketDetailsPageState extends State<TicketDetailsPage> {
  late Future<_TicketDetailsData> _details;
  QueueTicket? _displayedTicket;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _details = _loadDetails();
    widget.ticketRepository?.refreshVersion.addListener(
      _handleTicketRepositoryRefresh,
    );
  }

  @override
  void dispose() {
    widget.ticketRepository?.refreshVersion.removeListener(
      _handleTicketRepositoryRefresh,
    );
    super.dispose();
  }

  void _handleTicketRepositoryRefresh() {
    if (!mounted) return;
    final details = _loadDetails(refreshTicket: true);
    setState(() {
      _details = details;
    });
  }

  Future<_TicketDetailsData> _loadDetails({bool refreshTicket = false}) async {
    var ticket = widget.ticket;
    if (refreshTicket) {
      final ticketRepository = widget.ticketRepository;
      if (ticketRepository != null) {
        final latestTickets = await ticketRepository.loadAllTickets();
        for (final latestTicket in latestTickets) {
          if (latestTicket.id == ticket.id ||
              latestTicket.lookupCode == ticket.lookupCode) {
            ticket = latestTicket;
            break;
          }
        }
      }
    }

    final vendor = await _loadVendor(ticket);
    final repository = widget.queueRepository;
    final tenantSlug = ticket.tenantSlug;
    if (repository == null || tenantSlug == null || ticket.lookupCode.isEmpty) {
      return _TicketDetailsData(ticket: ticket, vendor: vendor);
    }

    final snapshot = await repository.loadQueueSnapshot(
      tenantSlug: tenantSlug,
      locationSlug: ticket.locationSlug,
      lookupCode: ticket.lookupCode,
    );
    final snapshotTicket =
        snapshot.focusTicket?.copyWith(
          vendorName: ticket.vendorName,
          locationName: ticket.locationName,
          tenantSlug: ticket.tenantSlug,
          locationSlug: ticket.locationSlug,
        ) ??
        ticket;
    return _TicketDetailsData(
      ticket: snapshotTicket,
      snapshot: snapshot,
      vendor: vendor,
    );
  }

  Future<VendorSummary> _loadVendor(QueueTicket ticket) async {
    final repository = widget.directoryRepository;
    final tenantSlug = ticket.tenantSlug?.trim();
    if (repository == null || tenantSlug == null || tenantSlug.isEmpty) {
      return _fallbackVendor(ticket);
    }
    try {
      return await repository.loadVendor(tenantSlug);
    } catch (_) {
      return _fallbackVendor(ticket);
    }
  }

  VendorSummary _fallbackVendor(QueueTicket ticket) {
    final locationName = ticket.locationName;
    return VendorSummary(
      slug: ticket.tenantSlug?.trim().isNotEmpty == true
          ? ticket.tenantSlug!.trim()
          : 'queue-ticket',
      name: ticket.vendorName ?? 'Queue ticket',
      queueAvailable: ticket.isActive,
      locations: locationName == null
          ? const []
          : [
              VendorLocation(
                id: ticket.locationSlug ?? 'ticket-location',
                name: locationName,
                slug: ticket.locationSlug,
                queueAvailable: ticket.isActive,
              ),
            ],
    );
  }

  Future<void> _refresh() async {
    final details = _loadDetails(refreshTicket: true);
    setState(() {
      _details = details;
    });
    try {
      await details;
      if (mounted) {
        showFeedbackToast(context, message: 'Ticket status refreshed.');
      }
    } catch (_) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: 'Could not refresh ticket status.',
          isError: true,
        );
      }
    }
  }

  Future<void> _cancelTicket() async {
    final onCancel = widget.onCancel;
    if (onCancel == null || _isCancelling) return;
    setState(() => _isCancelling = true);
    try {
      final cancelled = await onCancel();
      if (!mounted) return;
      setState(() {
        _displayedTicket = cancelled ?? _displayedTicket;
        _isCancelling = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: GetPrioTheme.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ScrollNotificationObserver(
        child: Scaffold(
          headers: [
            ScrollAwareAppBar(
              title: const Text('Ticket details'),
              leading: [
                GhostButton(
                  key: const Key('ticket-details-back'),
                  onPressed: () => Navigator.of(context).pop(),
                  density: ButtonDensity.icon,
                  child: const Icon(LucideIcons.arrowLeft),
                ),
              ],
            ),
          ],
          child: FutureBuilder<_TicketDetailsData>(
            future: _details,
            builder: (context, snapshot) {
              final details = snapshot.data;
              final ticket =
                  _displayedTicket ?? details?.ticket ?? widget.ticket;
              return RefreshTrigger(
                key: const Key('ticket-details-refresh'),
                onRefresh: _refresh,
                child: ListView(
                  key: const Key('ticket-details-page'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      key: const Key('ticket-details-surface'),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                      decoration: const BoxDecoration(
                        color: GetPrioTheme.paper,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x245B422A),
                            blurRadius: 28,
                            offset: Offset(0, -6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.showJoinConfirmation) ...[
                            _TicketJoinSuccessNotice(ticket: ticket),
                            const SizedBox(height: 20),
                          ],
                          Container(
                            padding: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context).colorScheme.border,
                                ),
                              ),
                            ),
                            child: Text(
                              'Your queue ticket',
                              style: Theme.of(context).typography.h2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(ticket.vendorName ?? 'Queue ticket'),
                          if (ticket.status == TicketStatus.served &&
                              widget.directoryRepository?.social != null) ...[
                            const SizedBox(height: 16),
                            TicketReviewAction(
                              key: ValueKey('review-${ticket.lookupCode}'),
                              repository: widget.directoryRepository!.social!,
                              ticket: ticket,
                              prompt:
                                  widget.ticket.status != TicketStatus.served,
                            ),
                          ],
                          if (ticket.locationName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              ticket.locationName!,
                              style: TextStyle(color: GetPrioTheme.mutedInk),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Card(
                            key: const Key('ticket-details-card'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Ticket number'),
                                        const SizedBox(height: 4),
                                        Text(
                                          ticket.ticketNumber ??
                                              ticket.lookupCode,
                                          style: GetPrioTheme.ticketStyle(
                                            Theme.of(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    _TicketDetailStatus(ticket: ticket),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Divider(),
                                const SizedBox(height: 16),
                                _TicketDetailRow(
                                  label: 'Joined',
                                  value: ticket.joinedAt == null
                                      ? 'Unavailable'
                                      : _formatTicketDateTime(ticket.joinedAt!),
                                ),
                                if (ticket.position != null)
                                  _TicketDetailRow(
                                    label: 'Position',
                                    value: '#${ticket.position}',
                                  ),
                                _TicketDetailRow(
                                  label: 'Estimated wait',
                                  value: ticket.estimatedWaitMinutes == null
                                      ? 'Unavailable'
                                      : '${ticket.estimatedWaitMinutes} min',
                                ),
                                if (ticket.customerFriendlyStatusReason != null)
                                  _TicketDetailRow(
                                    label: 'Note',
                                    value: ticket.customerFriendlyStatusReason!,
                                    textAlign: TextAlign.left,
                                  ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),
                                const Text(
                                  'Show this barcode when your ticket is called.',
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  key: const Key('ticket-details-barcode'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  color: Colors.white,
                                  child: BarcodeWidget(
                                    data:
                                        ticket.verificationCode ??
                                        ticket.lookupCode,
                                    barcode: Barcode.code128(),
                                    height: 72,
                                    drawText: false,
                                    color: GetPrioTheme.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    ticket.verificationCode ??
                                        ticket.lookupCode,
                                    style: const TextStyle(
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (ticket.canBeCancelled &&
                              widget.onCancel != null) ...[
                            const SizedBox(height: 16),
                            GetPrioActionButton.destructive(
                              key: const Key('ticket-details-cancel'),
                              onPressed: _isCancelling ? null : _cancelTicket,
                              child: Text(
                                _isCancelling
                                    ? 'Cancelling...'
                                    : 'Cancel ticket',
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _TicketQueueStatusCard(
                            ticket: ticket,
                            snapshot: details?.snapshot,
                          ),
                          if (snapshot.hasError) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Live queue details are temporarily unavailable.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TicketJoinSuccessNotice extends StatelessWidget {
  const _TicketJoinSuccessNotice({required this.ticket});

  final QueueTicket ticket;

  @override
  Widget build(BuildContext context) {
    final ticketNumber = ticket.ticketNumber ?? ticket.lookupCode;
    return Container(
      key: const Key('ticket-join-success-notice'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GetPrioTheme.teal,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.circleCheck,
            color: GetPrioTheme.onPrimary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are in the queue',
                  style: Theme.of(context).typography.h3
                      .copyWith(color: GetPrioTheme.onPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ticket $ticketNumber is confirmed. Keep this page handy while you wait.',
                  style: const TextStyle(color: GetPrioTheme.onPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketDetailsData {
  const _TicketDetailsData({
    required this.ticket,
    required this.vendor,
    this.snapshot,
  });

  final QueueTicket ticket;
  final VendorSummary vendor;
  final QueueSnapshot? snapshot;
}

class _TicketDetailStatus extends StatelessWidget {
  const _TicketDetailStatus({required this.ticket});

  final QueueTicket ticket;

  @override
  Widget build(BuildContext context) {
    return _TicketStatusBadge(ticket: ticket);
  }
}

class _TicketDetailRow extends StatelessWidget {
  const _TicketDetailRow({
    required this.label,
    required this.value,
    this.textAlign = TextAlign.end,
  });

  final String label;
  final String value;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: GetPrioTheme.mutedInk),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(child: Text(value, textAlign: textAlign)),
        ],
      ),
    );
  }
}

class _TicketQueueStatusCard extends StatelessWidget {
  const _TicketQueueStatusCard({required this.ticket, this.snapshot});

  final QueueTicket ticket;
  final QueueSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final message = switch (ticket.status) {
      TicketStatus.waiting => 'You are in the queue. Keep this ticket ready.',
      TicketStatus.called when ticket.customerConfirmedAt != null =>
        'Your arrival was confirmed. Please wait for staff to begin service.',
      TicketStatus.called => 'Your ticket was called. Proceed to the vendor.',
      TicketStatus.served => 'This ticket has already been served.',
      TicketStatus.pendingCarryOver =>
        'Your ticket is saved for the next eligible queue day.',
      _ => 'This ticket is no longer active.',
    };
    return Container(
      key: const Key('ticket-details-queue-status'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GetPrioTheme.paperAccent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (snapshot != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TicketQueueMetric(
                          value: '${snapshot!.stats.estimatedWaitMinutes} min',
                          label: 'Estimated wait',
                        ),
                      ),
                      const SizedBox(
                        height: 40,
                        child: VerticalDivider(width: 1, thickness: 1),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TicketQueueMetric(
                          value: '${snapshot!.stats.waitingCount}',
                          label: 'Waiting now',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TicketQueueMetric(
                    value: '${snapshot!.stats.servedToday}',
                    label: 'Completed today',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Currently serving ${snapshot!.current?.ticketNumber ?? snapshot!.stats.currentTicketNumber ?? '--'}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketQueueMetric extends StatelessWidget {
  const _TicketQueueMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).typography.p
              .copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).typography.textMuted),
      ],
    );
  }
}

String _formatTicketDateTime(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.year}-$month-$day, $hour:$minute $period';
}

class _TicketMetric extends StatelessWidget {
  const _TicketMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(value).h3(), const SizedBox(height: 2), Text(label)],
    );
  }
}

class _TicketProgress extends StatelessWidget {
  const _TicketProgress({required this.ticket});

  final QueueTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Queue progress').h4(),
        const SizedBox(height: 12),
        _TimelineStep(
          label: 'Joined queue',
          caption: ticket.joinedAt == null
              ? 'Ticket confirmed'
              : _timeLabel(ticket.joinedAt!),
          color: GetPrioTheme.success,
        ),
        _TimelineStep(
          label: ticket.displayStatusLabel,
          caption: _statusCaption(ticket),
          color: _statusColor(ticket.status),
          isLast: true,
        ),
      ],
    );
  }

  String _statusCaption(QueueTicket ticket) {
    if (ticket.status == TicketStatus.waiting && ticket.position != null) {
      return 'Position ${ticket.position} in line';
    }
    return switch (ticket.status) {
      TicketStatus.called when ticket.isConfirmed =>
        'Arrival confirmed; waiting for service',
      TicketStatus.called => 'Please proceed to the service area',
      TicketStatus.pendingCarryOver => 'Waiting for queue confirmation',
      _ => 'Current ticket status',
    };
  }

  Color _statusColor(TicketStatus status) {
    return switch (status) {
      TicketStatus.called => GetPrioTheme.orange,
      TicketStatus.pendingCarryOver => GetPrioTheme.warning,
      TicketStatus.waiting => GetPrioTheme.teal,
      TicketStatus.served => GetPrioTheme.success,
      TicketStatus.skipped ||
      TicketStatus.cancelled ||
      TicketStatus.unserved ||
      TicketStatus.expired => GetPrioTheme.destructive,
      TicketStatus.unknown => GetPrioTheme.disabled,
    };
  }

  String _timeLabel(DateTime date) {
    final local = date.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.hour}:$minute';
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.caption,
    required this.color,
    this.isLast = false,
  });

  final String label;
  final String caption;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Container(width: 2, height: 34, color: GetPrioTheme.line),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(label), const SizedBox(height: 2), Text(caption)],
            ),
          ),
        ),
      ],
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    this.socialRepository,
    this.onOpenVendor,
    this.user,
    this.onSignOut,
    this.settingsRepository,
    this.securityRepository,
    this.profileRepository,
    this.onUserUpdated,
    this.approvedVendorStore,
    this.sandbox = false,
  });

  final VendorSocialRepository? socialRepository;
  final ValueChanged<VendorSummary>? onOpenVendor;
  final AuthUser? user;
  final VoidCallback? onSignOut;
  final AccountSettingsRepository? settingsRepository;
  final SecurityRepository? securityRepository;
  final AccountProfileRepository? profileRepository;
  final ValueChanged<AuthUser>? onUserUpdated;
  final ApprovedVendorStore? approvedVendorStore;
  final bool sandbox;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  AuthUser? _user;
  bool _avatarBusy = false;
  Future<NotificationSettings?>? _notificationSettingsFuture;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _primeNotificationSettings();
  }

  @override
  void didUpdateWidget(covariant AccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) _user = widget.user;
    if (widget.settingsRepository != oldWidget.settingsRepository) {
      _primeNotificationSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _dismissKeyboard(),
      child: DrawerOverlay(
        child: Builder(
          builder: (overlayContext) {
            final user = _user ?? widget.user;
            final displayName = user?.customerName ?? 'Customer';
            final email = user?.email ?? '';
            return ListView(
              key: const Key('account-page'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                const Text('Profile').h2(),
                const SizedBox(height: 4),
                const Text('Manage your profile and app preferences.'),
                const SizedBox(height: 20),
                Card(
                  child: Row(
                    children: [
                      _ProfileAvatar(
                        user: user,
                        busy: _avatarBusy,
                        onPressed: _pickAvatar,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName).h3(),
                            const SizedBox(height: 4),
                            Text(email),
                            if (user != null && !user.emailVerified) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Email not verified',
                                style: TextStyle(
                                  color: GetPrioTheme.destructive,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GhostButton(
                        key: const Key('profile-edit-button'),
                        onPressed: () => _openPersonalInfoSheet(overlayContext),
                        density: ButtonDensity.icon,
                        child: const Icon(LucideIcons.pencil),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Account').h3(),
                const SizedBox(height: 8),
                if (widget.socialRepository case final repository?) ...[
                  _AccountAction(
                    icon: LucideIcons.heart,
                    title: 'Favorites',
                    subtitle: 'Manage your favorite vendors.',
                    onPressed: () => showFavoritesSheet(
                      overlayContext,
                      repository,
                      onOpen: widget.onOpenVendor,
                    ),
                  ),
                  const Divider(),
                ],
                _AccountAction(
                  key: const Key('profile-personal-info'),
                  icon: LucideIcons.userRound,
                  title: 'Personal info',
                  subtitle: 'Name, display name, email, and phone number.',
                  onPressed: () => _openPersonalInfoSheet(overlayContext),
                ),
                const Divider(),
                const SizedBox(height: 20),
                const Text('Settings').h3(),
                const SizedBox(height: 8),
                if (widget.sandbox && widget.approvedVendorStore != null) ...[
                  _AccountAction(
                    key: const Key('profile-approved-vendors'),
                    icon: LucideIcons.store,
                    title: 'Approved Vendors',
                    subtitle: 'Manage vendors whose invitations are accepted automatically.',
                    onPressed: () => _openApprovedVendorsSheet(overlayContext),
                  ),
                  const Divider(),
                ],
                _AccountAction(
                  key: const Key('profile-notifications'),
                  icon: LucideIcons.bell,
                  title: 'Notifications',
                  subtitle: widget.settingsRepository == null
                      ? 'Queue alerts unavailable'
                      : 'Manage queue alerts and app preferences.',
                  onPressed: () => _openNotificationsSheet(overlayContext),
                ),
                const Divider(),
                const Text('Security').h3(),
                const SizedBox(height: 8),
                _AccountAction(
                  key: const Key('profile-biometrics'),
                  icon: LucideIcons.fingerprint,
                  title: 'Biometrics',
                  subtitle: 'Manage Face ID, Touch ID, or fingerprint sign-in.',
                  onPressed: () => _openSecuritySheet(
                    overlayContext,
                    SecuritySection.biometrics,
                  ),
                ),
                if (!widget.sandbox) ...[
                  const Divider(),
                  _AccountAction(
                    key: const Key('profile-password'),
                    icon: LucideIcons.lockKeyhole,
                    title: 'Password',
                    subtitle: 'Change your account password.',
                    onPressed: () => _openSecuritySheet(
                      overlayContext,
                      SecuritySection.password,
                    ),
                  ),
                  const Divider(),
                  _AccountAction(
                    key: const Key('profile-mfa'),
                    icon: LucideIcons.shieldCheck,
                    title: 'MFA Setup',
                    subtitle: 'Set up an authenticator app and recovery codes.',
                    onPressed: () =>
                        _openSecuritySheet(overlayContext, SecuritySection.mfa),
                  ),
                ],
                const Divider(),
                _AccountAction(
                  key: const Key('profile-logout'),
                  icon: LucideIcons.logOut,
                  title: 'Log out',
                  subtitle: 'Sign out of this device.',
                  onPressed: widget.onSignOut == null
                      ? null
                      : () => _confirmSignOut(overlayContext),
                  destructive: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openPersonalInfoSheet(BuildContext context) async {
    final completer = openDrawerOverlay<AuthUser>(
      context: context,
      position: OverlayPosition.bottom,
      expands: false,
      draggable: true,
      useSafeArea: false,
      borderRadius: _ProfileSheetContent.borderRadius,
      transformBackdrop: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      builder: (sheetContext) => _PersonalInfoSheet(
        user: _user ?? widget.user,
        repository: widget.profileRepository,
        onUserUpdated: (user) {
          if (!mounted) return;
          setState(() => _user = user);
          widget.onUserUpdated?.call(user);
        },
      ),
    );
    final updated = await completer.future;
    if (!mounted || updated == null) return;
    setState(() => _user = updated);
    widget.onUserUpdated?.call(updated);
    showFeedbackToast(this.context, message: 'Profile updated.');
  }

  Future<void> _openNotificationsSheet(BuildContext context) async {
    final settings = await (_notificationSettingsFuture ??=
        _loadNotificationSettings());
    if (!mounted || !context.mounted) return;
    final completer = openDrawerOverlay<void>(
      context: context,
      position: OverlayPosition.bottom,
      expands: false,
      draggable: true,
      useSafeArea: false,
      borderRadius: _ProfileSheetContent.borderRadius,
      transformBackdrop: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      builder: (sheetContext) => _NotificationsSheet(
        repository: widget.settingsRepository,
        initialSettings: settings,
      ),
    );
    await completer.future;
    if (mounted) _primeNotificationSettings();
  }

  Future<void> _openApprovedVendorsSheet(BuildContext context) async {
    final store = widget.approvedVendorStore;
    final accountId = _user?.id ?? widget.user?.id;
    if (store == null || accountId == null) return;
    await openDrawerOverlay<void>(
      context: context,
      position: OverlayPosition.bottom,
      expands: false,
      transformBackdrop: false,
      builder: (sheetContext) => SocialSheet(
        key: const Key('profile-approved-vendors-sheet'),
        title: 'Approved Vendors',
        topPadding: GetPrioTheme.bottomSheetTopPadding,
        headerSpacing: 8,
        child: _ApprovedVendorsList(accountId: accountId, store: store),
      ),
    ).future;
  }

  void _primeNotificationSettings() {
    _notificationSettingsFuture = widget.settingsRepository == null
        ? null
        : _loadNotificationSettings();
  }

  Future<NotificationSettings?> _loadNotificationSettings() async {
    final repository = widget.settingsRepository;
    if (repository == null) return null;
    try {
      return await repository.loadNotificationSettings();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSecuritySheet(
    BuildContext context,
    SecuritySection section,
  ) async {
    final biometricLogin = context
        .findAncestorWidgetOfExactType<AuthGate>()
        ?.authRepository
        .biometricLogin;
    final completer = openDrawerOverlay<void>(
      context: context,
      position: OverlayPosition.bottom,
      expands: false,
      draggable: true,
      useSafeArea: false,
      borderRadius: _ProfileSheetContent.borderRadius,
      transformBackdrop: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      builder: (sheetContext) => SecurityPage(
        repository: widget.securityRepository,
        biometricLogin: biometricLogin,
        onPasswordChanged: widget.onSignOut,
        asSheet: true,
        section: section,
      ),
    );
    await completer.future;
  }

  Future<void> _pickAvatar() async {
    final repository = widget.profileRepository;
    if (repository == null || _avatarBusy) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final contentType =
        picked.mimeType ?? _profileImageContentType(picked.name);
    if (!['image/jpeg', 'image/png', 'image/webp'].contains(contentType)) {
      showFeedbackToast(
        context,
        message: 'Choose a JPEG, PNG, or WebP image.',
        isError: true,
      );
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      showFeedbackToast(
        context,
        message: 'Choose an image no larger than 5 MB.',
        isError: true,
      );
      return;
    }

    setState(() => _avatarBusy = true);
    try {
      final updated = await repository.uploadAvatar(
        fileName: picked.name,
        contentType: contentType,
        bytes: bytes,
      );
      if (mounted) {
        setState(() => _user = updated);
        widget.onUserUpdated?.call(updated);
        showFeedbackToast(context, message: 'Profile photo updated.');
      }
    } catch (error) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: _profileErrorMessage(
            error,
            'Could not upload profile photo.',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final onSignOut = widget.onSignOut;
    if (onSignOut == null) return;
    _dismissKeyboard();
    final confirmed = await showOverlay<bool>(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        key: const Key('logout-confirmation-dialog'),
        leading: const Icon(LucideIcons.logOut),
        title: const Text('Log out?'),
        content: const Text(
          'You will be signed out of this device. You can sign in again anytime.',
        ),
        actions: [
          GetPrioActionButton.outline(
            key: const Key('logout-cancel'),
            onPressed: () => closeOverlay(dialogContext, false),
            child: const Text('Stay signed in'),
          ),
          GetPrioActionButton.destructive(
            key: const Key('logout-confirm'),
            onPressed: () => closeOverlay(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    ).future;
    if (confirmed == true && mounted) onSignOut();
  }
}

class _ApprovedVendorsList extends StatefulWidget {
  const _ApprovedVendorsList({required this.accountId, required this.store});

  final String accountId;
  final ApprovedVendorStore store;

  @override
  State<_ApprovedVendorsList> createState() => _ApprovedVendorsListState();
}

class _ApprovedVendorsListState extends State<_ApprovedVendorsList> {
  List<ApprovedVendor>? _vendors;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final vendors = await widget.store.load(widget.accountId);
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_vendors == null) {
      return _error == null
          ? const Center(child: Text('Loading approved vendors…'))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load approved vendors.'),
                GhostButton(onPressed: _load, child: const Text('Try again')),
              ],
            );
    }
    final vendors = _vendors!;
    if (vendors.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No vendors are approved for automatic acceptance.'),
      );
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final vendor in vendors) ...[
            Row(
              key: ValueKey('approved-vendor-${vendor.key}'),
              children: [
                Expanded(child: Text(vendor.name).h4()),
                GhostButton(
                  key: ValueKey('remove-approved-vendor-${vendor.key}'),
                  density: ButtonDensity.icon,
                  onPressed: () => _confirmRemove(context, vendor),
                  child: const Icon(
                    LucideIcons.trash2,
                    semanticLabel: 'Remove approved vendor',
                  ),
                ),
              ],
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    ApprovedVendor vendor,
  ) async {
    final confirmed = await showOverlay<bool>(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        key: const Key('approved-vendor-remove-dialog'),
        leading: const Icon(LucideIcons.trash2),
        title: const Text('Remove approved vendor?'),
        content: Text(
          'New ticket invitations from ${vendor.name} will ask before being added again.',
        ),
        actions: [
          GetPrioActionButton.outline(
            key: const Key('approved-vendor-remove-cancel'),
            onPressed: () => closeOverlay(dialogContext, false),
            child: const Text('Keep vendor'),
          ),
          GetPrioActionButton.destructive(
            key: const Key('approved-vendor-remove-confirm'),
            onPressed: () => closeOverlay(dialogContext, true),
            child: const Text('Remove vendor'),
          ),
        ],
      ),
    ).future;
    if (confirmed != true || !mounted) return;
    final feedbackContext = context;
    try {
      await widget.store.remove(widget.accountId, vendor.key);
      if (!feedbackContext.mounted) return;
      final vendors = await widget.store.load(widget.accountId);
      if (!feedbackContext.mounted) return;
      setState(() => _vendors = vendors);
      showFeedbackToast(feedbackContext, message: 'Approved vendor removed.');
    } catch (_) {
      if (feedbackContext.mounted) {
        showFeedbackToast(
          feedbackContext,
          message: 'Could not remove approved vendor.',
          isError: true,
        );
      }
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
    required this.busy,
    required this.onPressed,
  });

  final AuthUser? user;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        key: const Key('profile-avatar-button'),
        onTap: busy ? null : onPressed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: GetPrioTheme.paperAccent,
                shape: BoxShape.circle,
                image: hasAvatar
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: hasAvatar
                  ? null
                  : Text(
                      _profileInitials(user?.customerName ?? 'Customer'),
                      style: Theme.of(context).typography.h3,
                    ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: GetPrioTheme.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: GetPrioTheme.paper, width: 3),
                ),
                child: Icon(
                  busy ? LucideIcons.loaderCircle : LucideIcons.camera,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSheetContent extends StatelessWidget {
  const _ProfileSheetContent({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.child,
    this.maxHeight,
  });

  static const borderRadius = BorderRadius.vertical(top: Radius.circular(28));

  final String title;
  final String closeLabel;
  final Widget child;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final maxBodyHeight = MediaQuery.sizeOf(context).height * 0.78;
    final body = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _dismissKeyboard(),
      child: child,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            GetPrioTheme.bottomSheetTopPadding,
            24,
            12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title).h3()),
                  Semantics(
                    button: true,
                    label: closeLabel,
                    child: GhostButton(
                      key: ValueKey(closeLabel),
                      onPressed: () {
                        _dismissKeyboard();
                        closeOverlay(context);
                      },
                      density: ButtonDensity.icon,
                      child: const Icon(LucideIcons.x),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (maxHeight == null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxBodyHeight),
                  child: body,
                )
              else
                Flexible(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalInfoSheet extends StatefulWidget {
  const _PersonalInfoSheet({
    required this.user,
    required this.repository,
    required this.onUserUpdated,
  });

  final AuthUser? user;
  final AccountProfileRepository? repository;
  final ValueChanged<AuthUser> onUserUpdated;

  @override
  State<_PersonalInfoSheet> createState() => _PersonalInfoSheetState();
}

enum _PersonalInfoStep { form, currentEmailCode, newEmailCode, phoneCode }

class _PersonalInfoSheetState extends State<_PersonalInfoSheet>
    with FormValidationMixin<_PersonalInfoSheet> {
  @override
  bool get formBusy => _busy;

  late final TextEditingController _name;
  late final TextEditingController _displayName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _code;
  late final TextEditingController _password;
  late AuthUser _currentUser;
  _PersonalInfoStep _step = _PersonalInfoStep.form;
  ProfileChangeChallenge? _challenge;
  String? _pendingPhone;
  String? _error;
  bool _busy = false;
  bool _editingEmail = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user ?? const AuthUser(id: '', email: '');
    _name = TextEditingController(text: _currentUser.profileName ?? '');
    _displayName = TextEditingController(text: _currentUser.displayName ?? '');
    _email = TextEditingController(text: _currentUser.email);
    _phone = TextEditingController(
      text: formatPhilippineMobileNumber(_currentUser.phone ?? ''),
    );
    _code = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _displayName.dispose();
    _email.dispose();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSheetContent(
      key: const Key('profile-personal-info-sheet'),
      title: _step == _PersonalInfoStep.form
          ? 'Personal info'
          : 'Verify your changes',
      closeLabel: 'Close personal info',
      child: SingleChildScrollView(
        child: switch (_step) {
          _PersonalInfoStep.form => _buildForm(context),
          _PersonalInfoStep.currentEmailCode => _buildEmailCode(
            context,
            title: 'Verify your current email',
            description:
                'Enter the 6-digit code sent to ${_challenge?.deliveryTarget ?? 'your current email address'}.',
            action: 'Verify current email',
            onSubmit: _verifyCurrentEmail,
          ),
          _PersonalInfoStep.newEmailCode => _buildEmailCode(
            context,
            title: 'Verify your new email',
            description:
                'Enter the 6-digit code sent to ${_challenge?.deliveryTarget ?? 'your new email address'}.',
            action: 'Confirm new email',
            onSubmit: _verifyNewEmail,
          ),
          _PersonalInfoStep.phoneCode => _buildPhoneCode(context),
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Keep your contact details current so queue updates reach you.',
        ),
        const SizedBox(height: 20),
        _LabeledTextField(
          inputKey: const Key('profile-full-name'),
          controller: _name,
          label: 'Full name',
          placeholder: 'Enter your full name',
        ),
        const SizedBox(height: 16),
        _LabeledTextField(
          inputKey: const Key('profile-display-name'),
          controller: _displayName,
          label: 'Display name',
          placeholder: 'How should we call you?',
          supportingText: 'Used as your customer-facing name.',
        ),
        const SizedBox(height: 16),
        if (_editingEmail)
          _LabeledTextField(
            inputKey: const Key('profile-email'),
            controller: _email,
            label: 'Email address',
            placeholder: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            supportingText:
                'Verify your current and new email addresses after saving.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Email address'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentUser.email,
                      key: const Key('profile-email-value'),
                    ),
                  ),
                  TextButton(
                    key: const Key('profile-email-update'),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _editingEmail = true),
                    child: const Text('Update'),
                  ),
                ],
              ),
              Text(
                _currentUser.emailVerified
                    ? 'Verified email address.'
                    : 'This email address is not verified yet.',
                style: Theme.of(context).typography.small.copyWith(
                  color: _currentUser.emailVerified
                      ? GetPrioTheme.mutedInk
                      : GetPrioTheme.destructive,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        _LabeledTextField(
          inputKey: const Key('profile-phone'),
          controller: _phone,
          label: 'Phone number',
          placeholder: '(0917) 123-4567',
          keyboardType: TextInputType.phone,
          onChanged: _formatPhoneField,
          supportingText: 'Philippine mobile number format.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          DestructiveBadge(child: Text(_error!)),
        ],
        const SizedBox(height: 20),
        GetPrioActionButton.primary(
          key: const Key('profile-save'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving...' : 'Save changes'),
        ),
      ],
    );
  }

  Widget _buildEmailCode(
    BuildContext context, {
    required String title,
    required String description,
    required String action,
    required Future<void> Function() onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title).h3(),
        const SizedBox(height: 8),
        Text('$description It expires in 10 minutes.'),
        const SizedBox(height: 20),
        _LabeledTextField(
          inputKey: const Key('profile-email-code'),
          controller: _code,
          label: '6-digit code',
          placeholder: 'Enter the code',
          keyboardType: TextInputType.number,
          onChanged: (value) => _limitDigits(_code, value),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          DestructiveBadge(child: Text(_error!)),
        ],
        const SizedBox(height: 20),
        GetPrioActionButton.primary(
          key: const Key('profile-verify-code'),
          onPressed: _busy || _code.text.trim().length != 6
              ? null
              : () => unawaited(onSubmit()),
          child: Text(_busy ? 'Verifying...' : action),
        ),
        const SizedBox(height: 8),
        GetPrioActionButton.outline(
          onPressed: _busy
              ? null
              : () => setState(() => _step = _PersonalInfoStep.form),
          child: const Text('Back to personal info'),
        ),
      ],
    );
  }

  Widget _buildPhoneCode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Verify your phone number').h3(),
        const SizedBox(height: 8),
        Text(
          'Enter the code sent to ${_challenge?.deliveryTarget ?? 'your email address'} and your current password.',
        ),
        const SizedBox(height: 20),
        _LabeledTextField(
          inputKey: const Key('profile-phone-code'),
          controller: _code,
          label: '6-digit code',
          placeholder: 'Enter the code',
          keyboardType: TextInputType.number,
          onChanged: (value) => _limitDigits(_code, value),
        ),
        const SizedBox(height: 16),
        _LabeledTextField(
          inputKey: const Key('profile-phone-password'),
          controller: _password,
          label: 'Current password',
          placeholder: 'Enter your current password',
          obscureText: true,
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          DestructiveBadge(child: Text(_error!)),
        ],
        const SizedBox(height: 20),
        GetPrioActionButton.primary(
          key: const Key('profile-verify-phone'),
          onPressed:
              _busy || _code.text.trim().length != 6 || _password.text.isEmpty
              ? null
              : () => unawaited(_verifyPhone()),
          child: Text(_busy ? 'Verifying...' : 'Confirm phone number'),
        ),
        const SizedBox(height: 8),
        GetPrioActionButton.outline(
          onPressed: _busy
              ? null
              : () => setState(() => _step = _PersonalInfoStep.form),
          child: const Text('Back to personal info'),
        ),
      ],
    );
  }

  void _formatPhoneField(String value) {
    final formatted = formatPhilippineMobileNumber(value);
    if (_phone.text == formatted) return;
    _phone.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  void _limitDigits(TextEditingController controller, String value) {
    final digits = value
        .replaceAll(RegExp(r'\D'), '')
        .substring(
          0,
          value.replaceAll(RegExp(r'\D'), '').length > 6
              ? 6
              : value.replaceAll(RegExp(r'\D'), '').length,
        );
    if (controller.text == digits) {
      setState(() {});
      return;
    }
    controller.value = TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
    setState(() {});
  }

  Future<void> _save() async {
    if (_busy ||
        !validateForm({
          _name: requiredField(_name.text, 'Full name'),
          _email: emailField(_email.text),
          _phone:
              (_phone.text.trim().isNotEmpty ||
                      (_currentUser.phone?.isNotEmpty ?? false)) &&
                  !isPhilippineMobileNumber(
                    normalizePhilippineMobileNumber(_phone.text),
                  )
              ? 'Enter a valid Philippine mobile number.'
              : null,
        })) {
      return;
    }
    final repository = widget.repository;
    if (repository == null) {
      showFormError(
        StateError('unavailable'),
        'Profile editing is unavailable right now.',
      );
      return;
    }
    final name = _name.text.trim();
    final displayName = _displayName.text.trim();
    final email = _email.text.trim();
    final normalizedPhone = normalizePhilippineMobileNumber(_phone.text);
    final currentPhone = normalizePhilippineMobileNumber(
      _currentUser.phone ?? '',
    );
    if (name.isEmpty) {
      setState(() => _error = 'Full name is required.');
      return;
    }
    if (normalizedPhone.isNotEmpty &&
        !isPhilippineMobileNumber(normalizedPhone)) {
      setState(() => _error = 'Enter a valid Philippine mobile number.');
      return;
    }
    if (normalizedPhone.isEmpty && currentPhone.isNotEmpty) {
      setState(() => _error = 'Enter a valid Philippine mobile number.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _pendingPhone = normalizedPhone == currentPhone ? null : normalizedPhone;
    });
    try {
      var updated = _currentUser;
      if (name != (_currentUser.profileName ?? '') ||
          displayName != (_currentUser.displayName ?? '')) {
        updated = await repository.updateProfile(
          name: name,
          displayName: displayName,
        );
        _currentUser = updated;
      }
      if (email.toLowerCase() != updated.email.toLowerCase()) {
        _challenge = await repository.startEmailChange(newEmail: email);
        _code.clear();
        formValidation.clear(_code);
        if (mounted) {
          _dismissKeyboard();
          setState(() => _step = _PersonalInfoStep.currentEmailCode);
        }
        return;
      }
      if (_pendingPhone != null) {
        await _startPhoneChange(repository, _pendingPhone!);
        return;
      }
      _finish(updated);
    } catch (error) {
      if (mounted) {
        showFormError(error, 'Could not save your profile.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCurrentEmail() async {
    if (_busy || !validateForm({_code: codeField(_code.text)})) return;
    final repository = widget.repository;
    final challenge = _challenge;
    if (repository == null || challenge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _challenge = await repository.verifyCurrentEmail(
        challengeId: challenge.challengeId,
        code: _code.text.trim(),
      );
      _code.clear();
      if (mounted) setState(() => _step = _PersonalInfoStep.newEmailCode);
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          'Could not verify that code.',
          field: error is ApiException && error.statusCode == 400
              ? _code
              : null,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyNewEmail() async {
    if (_busy || !validateForm({_code: codeField(_code.text)})) return;
    final repository = widget.repository;
    final challenge = _challenge;
    if (repository == null || challenge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _currentUser = await repository.verifyNewEmail(
        challengeId: challenge.challengeId,
        code: _code.text.trim(),
      );
      if (!mounted) return;
      _code.clear();
      _email.text = _currentUser.email;
      formValidation.clear(_code);
      _dismissKeyboard();
      setState(() {
        _editingEmail = false;
        _challenge = null;
        _step = _PersonalInfoStep.form;
      });
      widget.onUserUpdated(_currentUser);
      showFeedbackToast(context, message: 'Email address updated.');
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          'Could not verify that code.',
          field: error is ApiException && error.statusCode == 400
              ? _code
              : null,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startPhoneChange(
    AccountProfileRepository repository,
    String phone,
  ) async {
    _challenge = await repository.startPhoneChange(newPhone: phone);
    _code.clear();
    _password.clear();
    if (mounted) setState(() => _step = _PersonalInfoStep.phoneCode);
  }

  Future<void> _verifyPhone() async {
    if (_busy ||
        !validateForm({
          _code: codeField(_code.text),
          _password: requiredField(_password.text, 'Current password'),
        })) {
      return;
    }
    final repository = widget.repository;
    final challenge = _challenge;
    if (repository == null || challenge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _currentUser = await repository.verifyPhoneChange(
        challengeId: challenge.challengeId,
        code: _code.text.trim(),
        password: _password.text,
      );
      _finish(_currentUser);
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          'Could not verify that code.',
          field: error is ApiException && error.statusCode == 400
              ? _code
              : null,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finish(AuthUser user) {
    closeOverlay(context, user);
  }
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet({required this.repository, this.initialSettings});

  final AccountSettingsRepository? repository;
  final NotificationSettings? initialSettings;

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool? _queueAlerts;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _queueAlerts = widget.initialSettings?.queueAlerts;
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.initialSettings;
    return _ProfileSheetContent(
      key: const Key('profile-notifications-sheet'),
      title: 'Notifications',
      closeLabel: 'Close notifications',
      child: settings == null
          ? const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(LucideIcons.bellOff, size: 40),
                  SizedBox(height: 12),
                  Text('Queue alerts unavailable'),
                  SizedBox(height: 4),
                  Text('Notification settings could not be loaded.'),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Choose which updates you want to receive.'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(LucideIcons.bell),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Queue alerts'),
                            SizedBox(height: 4),
                            Text(
                              'Receive notifications about your queue tickets.',
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: const Key('profile-queue-alerts'),
                        value: _queueAlerts ?? settings.queueAlerts,
                        onChanged: _saving ? null : _updateQueueAlerts,
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    DestructiveBadge(child: Text(_error!)),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _updateQueueAlerts(bool enabled) async {
    if (_saving) return;
    final repository = widget.repository;
    if (repository == null) return;
    final previous = _queueAlerts;
    setState(() {
      _saving = true;
      _queueAlerts = enabled;
      _error = null;
    });
    try {
      final settings = await repository.updateNotificationSettings(
        queueAlerts: enabled,
      );
      if (mounted) {
        setState(() => _queueAlerts = settings.queueAlerts);
        showFeedbackToast(context, message: 'Notification preferences saved.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _queueAlerts = previous;
          _error = _profileErrorMessage(
            error,
            'Could not save notification settings.',
          );
        });
        showFeedbackToast(context, message: _error!, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? GetPrioTheme.destructive : GetPrioTheme.ink;
    return SizedBox(
      width: double.infinity,
      child: GhostButton(
        alignment: Alignment.centerLeft,
        leading: Icon(icon, color: color),
        trailing: Icon(LucideIcons.chevronRight, color: color, size: 18),
        onPressed: onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color)),
            const SizedBox(height: 2),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

String _profileInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final values = parts.toList(growable: false);
  if (values.isEmpty) return '?';
  if (values.length == 1) return values.first.substring(0, 1).toUpperCase();
  return '${values.first.substring(0, 1)}${values.last.substring(0, 1)}'
      .toUpperCase();
}

String _profileImageContentType(String fileName) {
  final extension = fileName.toLowerCase().split('.').last;
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'application/octet-stream',
  };
}

String _profileErrorMessage(Object error, String fallback) {
  if (error is ApiException &&
      error.statusCode == 403 &&
      error.message.contains('Only vendor users')) {
    return 'Phone number updates are not available for customer accounts yet.';
  }
  return error is ApiException ? error.message : fallback;
}

enum SecuritySection { biometrics, password, mfa }

class SecurityPage extends StatefulWidget {
  const SecurityPage({
    super.key,
    required this.repository,
    this.biometricLogin,
    this.onPasswordChanged,
    this.asSheet = false,
    this.section,
  });

  final SecurityRepository? repository;
  final BiometricLogin? biometricLogin;
  final VoidCallback? onPasswordChanged;
  final bool asSheet;
  final SecuritySection? section;

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage>
    with FormValidationMixin<SecurityPage> {
  @override
  bool get formBusy => _busy;

  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _mfaCode = TextEditingController();
  MfaEnrollment? _enrollment;
  List<String>? _recoveryCodes;
  String? _message;
  bool _busy = false;
  bool _mfaSetupInitiated = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _mfaCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final title = switch (section) {
      SecuritySection.biometrics => 'Biometrics',
      SecuritySection.password => 'Password',
      SecuritySection.mfa => 'MFA Setup',
      null => 'Privacy and security',
    };
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section == null || section == SecuritySection.biometrics) ...[
            if (widget.biometricLogin != null)
              _BiometricLoginSetting(
                login: widget.biometricLogin!,
                showHeading: section == null,
              )
            else if (section == SecuritySection.biometrics)
              const Text('Biometric login is unavailable in this session.'),
            if (section == null && widget.biometricLogin != null)
              const SizedBox(height: 28),
          ],
          if (section == null || section == SecuritySection.password) ...[
            if (section == null) ...[
              const Text('Change password').h2(),
              const SizedBox(height: 12),
            ],
            _LabeledTextField(
              inputKey: const Key('change-current-password'),
              controller: _currentPassword,
              label: 'Current password',
              placeholder: 'Enter your current password',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              inputKey: const Key('change-new-password'),
              supportingText: 'Use 6–32 characters, at least 1 uppercase letter, 2 numbers, and 1 special character.',
              onChanged: (_) => formValidation.clear(_confirmPassword),
              controller: _newPassword,
              label: 'New password',
              placeholder: 'Enter your new password',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            _LabeledTextField(
              inputKey: const Key('change-confirm-password'),
              controller: _confirmPassword,
              label: 'Confirm new password',
              placeholder: 'Re-enter your new password',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            GetPrioActionButton.primary(
              key: const Key('change-password-submit'),
              onPressed: _busy ? null : _changePassword,
              child: Text(_busy ? 'Saving...' : 'Change password'),
            ),
          ],
          if (section == null || section == SecuritySection.mfa) ...[
            if (section == null) ...[
              const SizedBox(height: 28),
              const Text('Authenticator app').h2(),
              const SizedBox(height: 8),
            ],
            const Text(
              'Add an authenticator app for an extra sign-in factor. Recovery codes are shown only after setup.',
            ),
            const SizedBox(height: 12),
            if (_enrollment != null) ...[
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan this QR code with your authenticator app.',
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Semantics(
                        image: true,
                        label: 'MFA setup QR code',
                        child: BarcodeWidget(
                          key: const Key('mfa-enrollment-qr'),
                          data: _enrollment!.otpauthUri.toString(),
                          barcode: Barcode.qrCode(),
                          backgroundColor: Colors.white,
                          drawText: false,
                          width: 220,
                          height: 220,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Can’t scan? Enter this setup key manually.'),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SelectableText(
                            _enrollment!.secret,
                            key: const Key('mfa-enrollment-key'),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: 'Copy MFA setup key',
                          child: IconButton.ghost(
                            key: const Key('mfa-copy-key-button'),
                            icon: const Icon(LucideIcons.clipboardCopy),
                            onPressed: _copyMfaKey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _LabeledTextField(
                controller: _mfaCode,
                label: 'Authenticator code',
                placeholder: 'Enter your 6-digit code',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              GetPrioActionButton.primary(
                key: const Key('mfa-confirm-button'),
                onPressed: _busy ? null : _confirmMfa,
                child: Text(_busy ? 'Confirming...' : 'Confirm MFA setup'),
              ),
            ] else if (!_mfaSetupInitiated)
              GetPrioActionButton.outline(
                key: const Key('mfa-setup-button'),
                onPressed: _busy ? null : _startMfa,
                child: const Text('Set up MFA'),
              ),
            if (_recoveryCodes != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Save your recovery codes').h3(),
                    const SizedBox(height: 8),
                    const Text(
                      'Each code can be used once if you lose access to your authenticator app.',
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _recoveryCodes!.join('\n'),
                      key: const Key('mfa-recovery-codes'),
                    ),
                    const SizedBox(height: 12),
                    GetPrioActionButton.outline(
                      key: const Key('mfa-copy-recovery-codes-button'),
                      onPressed: _copyRecoveryCodes,
                      child: const Text('Copy recovery codes'),
                    ),
                    const SizedBox(height: 8),
                    GetPrioActionButton.outline(
                      onPressed: () => setState(() => _recoveryCodes = null),
                      child: const Text('I saved these codes'),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
        ],
      ),
    );
    if (widget.asSheet) {
      return _ProfileSheetContent(
        key: ValueKey(
          section == null
              ? 'profile-security-sheet'
              : 'profile-${section.name}-sheet',
        ),
        title: title,
        closeLabel: 'Close $title',
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        child: content,
      );
    }
    return ScrollNotificationObserver(
      child: Scaffold(
        headers: [
          ScrollAwareAppBar(
            title: const Text('Security and MFA'),
            leading: [
              GhostButton(
                onPressed: () => Navigator.of(context).pop(),
                density: ButtonDensity.icon,
                child: const Icon(LucideIcons.arrowLeft),
              ),
            ],
          ),
        ],
        child: content,
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_busy) return;
    if (!validateForm({
      _currentPassword: requiredField(
        _currentPassword.text,
        'Current password',
      ),
      _newPassword:
          newPasswordField(_newPassword.text) ??
          (_newPassword.text == _currentPassword.text
              ? 'Choose a different password from your current password.'
              : null),
      _confirmPassword: _confirmPassword.text.isEmpty
          ? 'Confirm your new password.'
          : _confirmPassword.text != _newPassword.text
          ? 'Passwords do not match.'
          : null,
    })) {
      return;
    }
    final repository = widget.repository;
    if (repository == null) {
      showFormError(
        StateError('unavailable'),
        'Password change is unavailable right now.',
      );
      return;
    }
    _dismissKeyboard();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await repository.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      showFeedbackToast(
        context,
        message: 'Password changed. Please sign in again.',
      );
      widget.onPasswordChanged?.call();
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          'Could not change your password. Try again.',
          field:
              error is ApiException &&
                  error.message.toLowerCase().contains('current password')
              ? _currentPassword
              : null,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startMfa() async {
    if (_busy) return;
    final repository = widget.repository;
    if (repository == null) {
      showFormError(
        StateError('unavailable'),
        'Security settings are unavailable right now.',
      );
      return;
    }
    _dismissKeyboard();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final enrollment = await repository.startMfaEnrollment();
      if (mounted) {
        setState(() {
          _enrollment = enrollment;
          _mfaSetupInitiated = true;
        });
      }
    } catch (error) {
      if (mounted) {
        showFormError(error, 'Could not start MFA setup. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyMfaKey() async {
    final enrollment = _enrollment;
    if (enrollment == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: enrollment.secret));
      if (mounted) showFeedbackToast(context, message: 'MFA setup key copied.');
    } catch (_) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: 'Could not copy the MFA setup key.',
          isError: true,
        );
      }
    }
  }

  Future<void> _confirmMfa() async {
    if (_busy || !validateForm({_mfaCode: codeField(_mfaCode.text)})) return;
    final repository = widget.repository;
    if (repository == null) {
      showFormError(
        StateError('unavailable'),
        'Security settings are unavailable right now.',
      );
      return;
    }
    _dismissKeyboard();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final codes = await repository.confirmMfaEnrollment(_mfaCode.text.trim());
      if (mounted) {
        setState(() {
          _recoveryCodes = codes;
          _enrollment = null;
        });
        showFeedbackToast(
          context,
          message: 'MFA enabled. Save your recovery codes.',
        );
      }
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          'Could not confirm MFA. Try again.',
          field: error is ApiException && error.statusCode == 400
              ? _mfaCode
              : null,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyRecoveryCodes() async {
    final recoveryCodes = _recoveryCodes;
    if (recoveryCodes == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: recoveryCodes.join('\n')));
      if (mounted) {
        showFeedbackToast(context, message: 'Recovery codes copied.');
      }
    } catch (_) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: 'Could not copy the recovery codes.',
          isError: true,
        );
      }
    }
  }
}

class _BiometricLoginSetting extends StatefulWidget {
  const _BiometricLoginSetting({required this.login, this.showHeading = true});
  final BiometricLogin login;
  final bool showHeading;

  @override
  State<_BiometricLoginSetting> createState() => _BiometricLoginSettingState();
}

class _BiometricLoginSettingState extends State<_BiometricLoginSetting> {
  bool _enabled = false;
  bool _available = false;
  bool _busy = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await widget.login.isEnabled();
      final available = await widget.login.isAvailable();
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _available = available;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final next = !_enabled;
      if (next) {
        if (!await widget.login.enable()) {
          if (mounted) {
            showFeedbackToast(
              context,
              message: 'Biometric verification was not completed. Try again or use normal sign-in.',
              isError: true,
            );
          }
          return;
        }
      } else {
        await widget.login.disable();
      }
      if (mounted) {
        setState(() => _enabled = next);
        showFeedbackToast(
          context,
          message: next
              ? 'Biometric login enabled.'
              : 'Biometric login disabled.',
        );
      }
    } catch (_) {
      if (mounted) {
        showFeedbackToast(
          context,
          message: 'Could not update biometric login. Try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showHeading) ...[
        const Text('Biometric login').h2(),
        const SizedBox(height: 8),
      ],
      Text(
        _loadFailed
            ? 'Could not load biometric settings. Reopen Biometrics to retry.'
            : _busy
            ? 'Checking biometric login…'
            : !_available
            ? 'Set up Face ID, Touch ID, or fingerprint recognition in your device settings to use biometric login.'
            : 'Use biometrics to unlock your saved session when you launch GetPrio. You can always sign in normally.',
      ),
      const SizedBox(height: 12),
      GetPrioActionButton.outline(
        key: const Key('biometric-login-toggle'),
        onPressed: _busy || _loadFailed || (!_available && !_enabled)
            ? null
            : _toggle,
        child: Text(
          _enabled ? 'Disable biometric login' : 'Enable biometric login',
        ),
      ),
    ],
  );
}
