import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart'
    show FirebaseMessaging;
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'auth/auth_models.dart';
import 'auth/oauth_flow.dart';
import 'auth/auth_repository.dart';
import 'account/ticket_repository.dart';
import 'account/account_settings_repository.dart';
import 'account/security_repository.dart';
import 'directory/directory_repository.dart';
import 'queue/auth_queue_api.dart';
import 'queue/join_repository.dart';
import 'queue/join_ui.dart';
import 'queue/queue_models.dart';
import 'queue/queue_repository.dart';
import 'push/push_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final firebaseEnabled = await initializeFirebase();
  if (firebaseEnabled) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(GetPrioApp(firebaseEnabled: firebaseEnabled));
}

class GetPrioApp extends StatelessWidget {
  GetPrioApp({
    super.key,
    AuthRepository? authRepository,
    this.firebaseEnabled = false,
  }) : authRepository = authRepository ?? _defaultAuthRepository();

  final AuthRepository authRepository;
  final bool firebaseEnabled;

  @override
  Widget build(BuildContext context) {
    const baseUrl = String.fromEnvironment('GETPRIO_API_BASE_URL');
    final apiClient = AuthenticatedApiClient(
      baseUrl: baseUrl,
      authRepository: authRepository,
    );
    final joinRepository = JoinRepository(RestJoinApi(apiClient));
    final oauthFlow = OAuthFlow(
      baseUrl: baseUrl,
      authRepository: authRepository,
      api: RestOAuthApi(baseUrl: baseUrl),
    );
    final ticketRepository = QueueTicketRepository(
      RestAccountQueueApi(apiClient),
    );
    final pushCoordinator = firebaseEnabled
        ? PushCoordinator(
            messaging: FirebaseMessagingPort(),
            api: RestPushRegistrationApi(apiClient),
            installationStore: SecureInstallationStore(),
            platform: 'ios',
            appVersion: '1.0.0',
            locale: 'en-PH',
            onSignal: (_) async => ticketRepository.requestRefresh(),
          )
        : null;
    return ShadcnApp(
      title: 'GetPrio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: LegacyColorSchemes.lightZinc(),
        radius: 0.8,
      ),
      home: AuthGate(
        authRepository: authRepository,
        joinRepository: joinRepository,
        ticketRepository: ticketRepository,
        queueRepository: QueueRepository(RestQueueApi(apiClient)),
        directoryRepository: DirectoryRepository(RestDirectoryApi(apiClient)),
        settingsRepository: AccountSettingsRepository(
          RestAccountSettingsApi(apiClient),
        ),
        securityRepository: SecurityRepository(RestSecurityApi(apiClient)),
        allowedHosts: _allowedHosts(),
        pushCoordinator: pushCoordinator,
        oauthFlow: oauthFlow,
      ),
    );
  }

  static AuthRepository _defaultAuthRepository() {
    const baseUrl = String.fromEnvironment('GETPRIO_API_BASE_URL');
    return AuthRepository(
      api: RestAuthApi(baseUrl: baseUrl),
      tokenStore: SecureTokenStore(),
    );
  }

  static Set<String> _allowedHosts() {
    const configuredHosts = String.fromEnvironment('GETPRIO_APPROVED_HOSTS');
    const baseUrl = String.fromEnvironment('GETPRIO_API_BASE_URL');
    final hosts = configuredHosts
        .split(',')
        .map((host) => host.trim().toLowerCase())
        .where((host) => host.isNotEmpty)
        .toSet();
    final baseHost = Uri.tryParse(baseUrl)?.host;
    if (baseHost != null && baseHost.isNotEmpty) hosts.add(baseHost);
    return hosts;
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authRepository,
    required this.joinRepository,
    required this.ticketRepository,
    required this.queueRepository,
    required this.directoryRepository,
    required this.settingsRepository,
    required this.securityRepository,
    required this.allowedHosts,
    this.pushCoordinator,
    this.oauthFlow,
  });

  final AuthRepository authRepository;
  final JoinRepository joinRepository;
  final QueueTicketRepository ticketRepository;
  final QueueRepository queueRepository;
  final DirectoryRepository directoryRepository;
  final AccountSettingsRepository settingsRepository;
  final SecurityRepository securityRepository;
  final Set<String> allowedHosts;
  final PushCoordinator? pushCoordinator;
  final OAuthFlow? oauthFlow;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<AuthSession?> _restore;
  AuthSession? _session;
  bool _pushStarted = false;

  @override
  void initState() {
    super.initState();
    _restore = widget.authRepository.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      return CustomerShell(
        user: _session!.user,
        joinRepository: widget.joinRepository,
        ticketRepository: widget.ticketRepository,
        queueRepository: widget.queueRepository,
        directoryRepository: widget.directoryRepository,
        settingsRepository: widget.settingsRepository,
        securityRepository: widget.securityRepository,
        allowedHosts: widget.allowedHosts,
        onSignOut: () async {
          await widget.pushCoordinator?.logout();
          await widget.authRepository.logout();
          if (mounted) setState(() => _session = null);
        },
      );
    }

    return FutureBuilder<AuthSession?>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('Loading GetPrio...'));
        }
        if (snapshot.hasData) {
          _session = snapshot.data;
          unawaited(_startPush());
          return CustomerShell(
            user: snapshot.data!.user,
            joinRepository: widget.joinRepository,
            ticketRepository: widget.ticketRepository,
            queueRepository: widget.queueRepository,
            directoryRepository: widget.directoryRepository,
            settingsRepository: widget.settingsRepository,
            securityRepository: widget.securityRepository,
            allowedHosts: widget.allowedHosts,
            onSignOut: () async {
              await widget.pushCoordinator?.logout();
              await widget.authRepository.logout();
              if (mounted) setState(() => _session = null);
            },
          );
        }
        return SignInPage(
          authRepository: widget.authRepository,
          oauthFlow: widget.oauthFlow,
          onAuthenticated: (session) {
            setState(() => _session = session);
            unawaited(_startPush());
          },
        );
      },
    );
  }

  Future<void> _startPush() async {
    if (_pushStarted || widget.pushCoordinator == null) return;
    _pushStarted = true;
    try {
      await widget.pushCoordinator!.initialize();
    } catch (_) {
      // Push is best effort and must never block queue actions.
    }
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.authRepository,
    this.oauthFlow,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final OAuthFlow? oauthFlow;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaController = TextEditingController();
  final _recoveryController = TextEditingController();
  MfaChallenge? _challenge;
  String? _error;
  bool _isBusy = false;
  bool _useRecoveryCode = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(LucideIcons.ticket, size: 56),
              const SizedBox(height: 20),
              const Text('Welcome to GetPrio').h1(),
              const SizedBox(height: 8),
              Text(
                challenge == null
                    ? 'Sign in to manage your queue tickets.'
                    : 'Verify your identity to finish signing in.',
              ),
              const SizedBox(height: 24),
              if (challenge == null) ...[
                TextField(
                  key: const Key('sign-in-identifier'),
                  controller: _identifierController,
                  hintText: 'Email or username',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('sign-in-password'),
                  controller: _passwordController,
                  hintText: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  key: const Key('sign-in-button'),
                  onPressed: _isBusy ? null : _signIn,
                  child: Text(_isBusy ? 'Signing in...' : 'Sign in'),
                ),
                const SizedBox(height: 8),
                OutlineButton(
                  onPressed: _isBusy ? null : _openRegister,
                  child: const Text('Create customer account'),
                ),
                const SizedBox(height: 8),
                OutlineButton(
                  onPressed: _isBusy ? null : _openPasswordRecovery,
                  child: const Text('Forgot password?'),
                ),
                if (widget.oauthFlow?.enabled == true) ...[
                  const SizedBox(height: 16),
                  const Text('Or continue with', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlineButton(
                          onPressed: _isBusy
                              ? null
                              : () => _signInWithOAuth('google'),
                          child: const Text('Google'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlineButton(
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
                  TextField(
                    key: const Key('mfa-recovery-code'),
                    controller: _recoveryController,
                    hintText: 'Recovery code',
                  )
                else
                  TextField(
                    key: const Key('mfa-code'),
                    controller: _mfaController,
                    hintText: '6-digit authenticator code',
                    keyboardType: TextInputType.number,
                  ),
                const SizedBox(height: 12),
                PrimaryButton(
                  key: const Key('verify-mfa-button'),
                  onPressed: _isBusy ? null : () => _verifyMfa(challenge),
                  child: Text(_isBusy ? 'Verifying...' : 'Verify and continue'),
                ),
                const SizedBox(height: 8),
                OutlineButton(
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
                OutlineButton(
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
    );
  }

  Future<void> _signIn() async {
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
          setState(() => _challenge = challenge);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _verifyMfa(MfaChallenge challenge) async {
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
      if (mounted) setState(() => _error = _authError(error));
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
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _openRegister() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => RegisterPage(
          authRepository: widget.authRepository,
          onAuthenticated: widget.onAuthenticated,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _openPasswordRecovery() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PasswordRecoveryPage(authRepository: widget.authRepository),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  String _authError(Object error) {
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

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Create account'),
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
            const Text('Customer registration').h1(),
            const SizedBox(height: 8),
            const Text(
              'Use a display name when you want staff to call you by a preferred name.',
            ),
            const SizedBox(height: 20),
            TextField(controller: _name, hintText: 'Profile name'),
            const SizedBox(height: 12),
            TextField(controller: _username, hintText: 'Username'),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              hintText: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              onPressed: _busy ? null : _register,
              child: Text(_busy ? 'Creating...' : 'Create account'),
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

  Future<void> _register() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.authRepository.registerCustomer(
        name: _name.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        widget.onAuthenticated(result.session);
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
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
    return Scaffold(
      headers: [
        AppBar(
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
      child: Padding(
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
              TextField(
                controller: _email,
                hintText: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                onPressed: _busy ? null : _request,
                child: Text(_busy ? 'Sending...' : 'Send instructions'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await widget.authRepository.requestPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _sent = true);
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
    this.ticketRepository,
    this.queueRepository,
    this.directoryRepository,
    this.settingsRepository,
    this.securityRepository,
    this.allowedHosts = const {},
  });

  final AuthUser? user;
  final VoidCallback? onSignOut;
  final JoinRepository? joinRepository;
  final QueueTicketRepository? ticketRepository;
  final QueueRepository? queueRepository;
  final DirectoryRepository? directoryRepository;
  final AccountSettingsRepository? settingsRepository;
  final SecurityRepository? securityRepository;
  final Set<String> allowedHosts;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  static const _titles = ['Home', 'Explore', 'Join', 'My Tickets', 'Account'];
  static const _subtitles = [
    'Your queue activity at a glance',
    'Find a vendor and view queue availability',
    'Scan a vendor QR code to join',
    'Manage your active and past tickets',
    'Profile, security, and notifications',
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: Text(_titles[_selectedIndex]),
          subtitle: Text(_subtitles[_selectedIndex]),
        ),
        const Divider(),
      ],
      footers: [
        const Divider(),
        NavigationBar(
          selectedKey: ValueKey(_selectedIndex),
          onSelected: (key) {
            if (key is ValueKey<int>) {
              setState(() => _selectedIndex = key.value);
            }
          },
          children: [
            _navItem('Home', LucideIcons.house, 0),
            _navItem('Explore', LucideIcons.compass, 1),
            _navItem('Join', LucideIcons.scanQrCode, 2),
            _navItem('Tickets', LucideIcons.ticket, 3),
            _navItem('Account', LucideIcons.circleUserRound, 4),
          ],
        ),
      ],
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            user: widget.user,
            ticketRepository: widget.ticketRepository,
            onOpenJoin: () => setState(() => _selectedIndex = 2),
          ),
          ExplorePage(repository: widget.directoryRepository),
          JoinPage(
            repository: widget.joinRepository,
            allowedHosts: widget.allowedHosts,
            customerName: widget.user?.customerName ?? 'Customer',
          ),
          TicketsPage(
            ticketRepository: widget.ticketRepository,
            queueRepository: widget.queueRepository,
          ),
          AccountPage(
            user: widget.user,
            onSignOut: widget.onSignOut,
            settingsRepository: widget.settingsRepository,
            securityRepository: widget.securityRepository,
          ),
        ],
      ),
    );
  }

  NavigationItem _navItem(String label, IconData icon, int index) {
    return NavigationItem(
      key: ValueKey(index),
      label: Text(label),
      child: Icon(icon),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.user,
    this.ticketRepository,
    this.onOpenJoin,
  });

  final AuthUser? user;
  final QueueTicketRepository? ticketRepository;
  final VoidCallback? onOpenJoin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home-page'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Good morning, ${user?.customerName ?? 'there'}').h2(),
        const SizedBox(height: 4),
        const Text('Stay up to date with your queue tickets.'),
        const SizedBox(height: 20),
        _ActiveTicketCard(
          ticketRepository: ticketRepository,
          onOpenJoin: onOpenJoin,
        ),
        const SizedBox(height: 20),
        const Text('Your stats').h3(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(label: 'Tickets joined', value: '0'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(label: 'Tickets served', value: '0'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActiveTicketCard extends StatelessWidget {
  const _ActiveTicketCard({this.ticketRepository, this.onOpenJoin});

  final QueueTicketRepository? ticketRepository;
  final VoidCallback? onOpenJoin;

  @override
  Widget build(BuildContext context) {
    if (ticketRepository == null) return _emptyCard();
    return FutureBuilder<List<QueueTicket>>(
      future: ticketRepository!.loadOverview(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Text('Loading active tickets...'));
        }
        final active =
            snapshot.data?.where((ticket) => ticket.isActive).toList() ?? [];
        return active.isEmpty ? _emptyCard() : _ticketCard(active.first);
      },
    );
  }

  Widget _emptyCard() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Active ticket').h3(),
          const SizedBox(height: 16),
          const Text('No active tickets').h3(),
          const SizedBox(height: 4),
          const Text('Scan a vendor QR code when you are ready to join.'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
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

  Widget _ticketCard(QueueTicket ticket) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active ticket').h3(),
              PrimaryBadge(child: Text(ticket.status.label.toUpperCase())),
            ],
          ),
          const SizedBox(height: 12),
          Text(ticket.vendorName ?? 'Queue ticket'),
          if (ticket.locationName != null) Text(ticket.locationName!),
          if (ticket.position != null) ...[
            const SizedBox(height: 12),
            Text('Position ${ticket.position}'),
            if (ticket.estimatedWaitMinutes != null)
              Text('${ticket.estimatedWaitMinutes} minutes estimated'),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlineButton(
              onPressed: onOpenJoin,
              child: const Text('Join another queue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(value).h2(), const SizedBox(height: 4), Text(label)],
      ),
    );
  }
}

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key, this.repository});

  final DirectoryRepository? repository;

  @override
  Widget build(BuildContext context) {
    final directoryRepository = repository;
    return ListView(
      key: const Key('explore-page'),
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Explore vendors').h2(),
        const SizedBox(height: 4),
        const Text('Browse vendors with queueing available.'),
        const SizedBox(height: 20),
        TextField(
          placeholder: const Text('Search vendors'),
          features: const [InputFeature.leading(Icon(LucideIcons.search))],
        ),
        const SizedBox(height: 20),
        if (directoryRepository == null)
          Card(
            child: Text('Vendor directory is not configured for this build.'),
          )
        else
          FutureBuilder<List<VendorSummary>>(
            future: directoryRepository.loadVendors(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Text('Loading vendors...'));
              }
              if (snapshot.hasError) {
                return const DestructiveBadge(
                  child: Text('We could not load vendors. Try again later.'),
                );
              }
              if (snapshot.data?.isEmpty ?? true) {
                return const Card(
                  child: Text('No queue-capable vendors found.'),
                );
              }
              return Column(
                children: snapshot.data!
                    .map(
                      (vendor) => _VendorCard(
                        vendor: vendor,
                        repository: directoryRepository,
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor, required this.repository});

  final VendorSummary vendor;
  final DirectoryRepository repository;

  @override
  Widget build(BuildContext context) {
    return CardButton(
      onPressed: () {
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) =>
                VendorDetailPage(vendor: vendor, repository: repository),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) => FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: Row(
        children: [
          const Icon(LucideIcons.store),
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
                Text('${vendor.locations.length} queue-capable location(s)'),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight),
        ],
      ),
    );
  }
}

class VendorDetailPage extends StatelessWidget {
  const VendorDetailPage({
    super.key,
    required this.vendor,
    required this.repository,
  });

  final VendorSummary vendor;
  final DirectoryRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: Text(vendor.name),
          leading: [
            GhostButton(
              onPressed: () => Navigator.of(context).pop(),
              density: ButtonDensity.icon,
              child: const Icon(LucideIcons.arrowLeft),
            ),
          ],
        ),
      ],
      child: FutureBuilder<VendorSummary>(
        future: repository.loadVendor(vendor.slug),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Text('Loading vendor details...'));
          }
          if (snapshot.hasError) {
            return const Center(
              child: DestructiveBadge(
                child: Text('Vendor details are unavailable.'),
              ),
            );
          }
          final details = snapshot.data ?? vendor;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(details.name).h1(),
              if (details.category != null) ...[
                const SizedBox(height: 4),
                Text(details.category!),
              ],
              const SizedBox(height: 20),
              const Text('Queue-capable locations').h3(),
              const SizedBox(height: 12),
              if (details.locations.isEmpty)
                const Card(
                  child: Text('No queue-capable locations are listed.'),
                )
              else
                ...details.locations.map(
                  (location) => Card(
                    child: Row(
                      children: [
                        const Icon(LucideIcons.mapPin),
                        const SizedBox(width: 12),
                        Expanded(child: Text(location.name)),
                        PrimaryBadge(
                          child: Text(
                            location.queueAvailable
                                ? 'QUEUE OPEN'
                                : 'UNAVAILABLE',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'To join a queue, use the Join tab and scan the QR code displayed at the location.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key, this.ticketRepository, this.queueRepository});

  final QueueTicketRepository? ticketRepository;
  final QueueRepository? queueRepository;

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  late Future<List<QueueTicket>> _tickets;
  String? _confirmingTicketId;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    widget.ticketRepository?.refreshVersion.addListener(_reload);
    _tickets = _loadTickets();
  }

  @override
  void dispose() {
    widget.ticketRepository?.refreshVersion.removeListener(_reload);
    super.dispose();
  }

  Future<List<QueueTicket>> _loadTickets() async {
    final repository = widget.ticketRepository;
    if (repository == null) return const [];
    final active = await repository.loadOverview();
    final history = await repository.loadHistory();
    return [...active, ...history];
  }

  void _reload() {
    setState(() {
      _confirmingTicketId = null;
      _tickets = _loadTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QueueTicket>>(
      future: _tickets,
      builder: (context, snapshot) {
        return ListView(
          key: const Key('tickets-page'),
          padding: const EdgeInsets.all(20),
          children: [
            const Text('My tickets').h2(),
            const SizedBox(height: 4),
            const Text('Active and historical queue tickets.'),
            const SizedBox(height: 20),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Card(child: Text('Loading tickets...'))
            else if (snapshot.hasError) ...[
              const DestructiveBadge(
                child: Text('We could not load your tickets.'),
              ),
              const SizedBox(height: 12),
              OutlineButton(onPressed: _reload, child: const Text('Try again')),
            ] else if (snapshot.data?.isEmpty ?? true)
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
            else
              ...snapshot.data!.map(_ticketCard),
          ],
        );
      },
    );
  }

  Widget _ticketCard(QueueTicket ticket) {
    final canCancel =
        ticket.status == TicketStatus.waiting &&
        ticket.tenantSlug != null &&
        widget.queueRepository != null;
    final isConfirming = _confirmingTicketId == ticket.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ticket.vendorName ?? 'Queue ticket').h3(),
                PrimaryBadge(child: Text(ticket.status.label.toUpperCase())),
              ],
            ),
            const SizedBox(height: 8),
            Text('Ticket ${ticket.ticketNumber ?? ticket.lookupCode}'),
            if (ticket.locationName != null) Text(ticket.locationName!),
            if (ticket.position != null) ...[
              const SizedBox(height: 8),
              Text(
                'Position ${ticket.position} · ${ticket.estimatedWaitMinutes ?? 0} min estimated',
              ),
            ],
            if (canCancel && !isConfirming) ...[
              const SizedBox(height: 12),
              DestructiveButton(
                onPressed: () =>
                    setState(() => _confirmingTicketId = ticket.id),
                child: const Text('Cancel ticket'),
              ),
            ],
            if (isConfirming) ...[
              const SizedBox(height: 12),
              const Text('Cancel this waiting ticket? This cannot be undone.'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlineButton(
                      onPressed: _isCancelling
                          ? null
                          : () => setState(() => _confirmingTicketId = null),
                      child: const Text('Keep ticket'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DestructiveButton(
                      onPressed: _isCancelling ? null : () => _cancel(ticket),
                      child: Text(_isCancelling ? 'Cancelling...' : 'Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(QueueTicket ticket) async {
    final repository = widget.queueRepository;
    final tenantSlug = ticket.tenantSlug;
    if (repository == null || tenantSlug == null) return;
    setState(() => _isCancelling = true);
    try {
      await repository.cancelTicket(tenantSlug: tenantSlug, ticket: ticket);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCancelling = false;
          _confirmingTicketId = null;
        });
      }
    }
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    this.user,
    this.onSignOut,
    this.settingsRepository,
    this.securityRepository,
  });

  final AuthUser? user;
  final VoidCallback? onSignOut;
  final AccountSettingsRepository? settingsRepository;
  final SecurityRepository? securityRepository;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late Future<NotificationSettings?> _settings;
  bool? _queueAlerts;

  @override
  void initState() {
    super.initState();
    _settings = _loadSettings();
  }

  Future<NotificationSettings?> _loadSettings() {
    final repository = widget.settingsRepository;
    return repository == null
        ? Future.value()
        : repository.loadNotificationSettings();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('account-page'),
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Account').h2(),
        const SizedBox(height: 4),
        const Text('Manage your profile and app preferences.'),
        const SizedBox(height: 20),
        Card(
          child: Row(
            children: [
              const Icon(LucideIcons.circleUserRound, size: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.user?.customerName ?? 'Customer').h3(),
                  const SizedBox(height: 4),
                  Text(widget.user?.email ?? ''),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<NotificationSettings?>(
          future: _settings,
          builder: (context, snapshot) {
            final settings = snapshot.data;
            if (settings == null) {
              return const Card(
                child: Text('Notification settings unavailable.'),
              );
            }
            return Card(
              child: Row(
                children: [
                  const Icon(LucideIcons.bell),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Queue alerts').h3(),
                        SizedBox(height: 4),
                        Text('Receive notifications about your queue tickets.'),
                      ],
                    ),
                  ),
                  Switch(
                    value: _queueAlerts ?? settings.queueAlerts,
                    onChanged: _updateQueueAlerts,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlineButton(
          leading: const Icon(LucideIcons.shieldCheck),
          onPressed: () => Navigator.of(context).push(
            PageRouteBuilder<void>(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  SecurityPage(
                    repository: widget.securityRepository,
                    onPasswordChanged: widget.onSignOut,
                  ),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) => FadeTransition(opacity: animation, child: child),
            ),
          ),
          child: const Text('Password, security, and MFA'),
        ),
        const SizedBox(height: 12),
        OutlineButton(
          leading: const Icon(LucideIcons.logOut),
          onPressed: widget.onSignOut,
          child: const Text('Log out'),
        ),
      ],
    );
  }

  Future<void> _updateQueueAlerts(bool enabled) async {
    final repository = widget.settingsRepository;
    if (repository == null) return;
    final previous = _queueAlerts;
    setState(() => _queueAlerts = enabled);
    try {
      final settings = await repository.updateNotificationSettings(
        queueAlerts: enabled,
      );
      if (mounted) setState(() => _queueAlerts = settings.queueAlerts);
    } catch (_) {
      if (mounted) setState(() => _queueAlerts = previous);
    }
  }
}

class SecurityPage extends StatefulWidget {
  const SecurityPage({
    super.key,
    required this.repository,
    this.onPasswordChanged,
  });

  final SecurityRepository? repository;
  final VoidCallback? onPasswordChanged;

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _mfaCode = TextEditingController();
  MfaEnrollment? _enrollment;
  List<String>? _recoveryCodes;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _mfaCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
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
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Change password').h2(),
          const SizedBox(height: 12),
          TextField(
            controller: _currentPassword,
            hintText: 'Current password',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPassword,
            hintText: 'New password',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            onPressed: _busy ? null : _changePassword,
            child: Text(_busy ? 'Saving...' : 'Change password'),
          ),
          const SizedBox(height: 28),
          const Text('Authenticator app').h2(),
          const SizedBox(height: 8),
          const Text(
            'Add an authenticator app for an extra sign-in factor. Recovery codes are shown only after setup.',
          ),
          const SizedBox(height: 12),
          if (_enrollment == null)
            OutlineButton(
              onPressed: _busy ? null : _startMfa,
              child: const Text('Set up MFA'),
            )
          else ...[
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scan this setup URI in your authenticator app.'),
                  const SizedBox(height: 8),
                  SelectableText(_enrollment!.otpauthUri.toString()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mfaCode,
              hintText: '6-digit authenticator code',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              onPressed: _busy ? null : _confirmMfa,
              child: Text(_busy ? 'Confirming...' : 'Confirm MFA setup'),
            ),
          ],
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
                  SelectableText(_recoveryCodes!.join('\n')),
                  const SizedBox(height: 12),
                  OutlineButton(
                    onPressed: () => setState(() => _recoveryCodes = null),
                    child: const Text('I saved these codes'),
                  ),
                ],
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final repository = widget.repository;
    if (repository == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await repository.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      widget.onPasswordChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _message = 'Password change failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startMfa() async {
    final repository = widget.repository;
    if (repository == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final enrollment = await repository.startMfaEnrollment();
      if (mounted) setState(() => _enrollment = enrollment);
    } catch (error) {
      if (mounted) setState(() => _message = 'MFA setup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmMfa() async {
    final repository = widget.repository;
    if (repository == null) return;
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
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'MFA confirmation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
