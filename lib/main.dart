import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'auth/auth_models.dart';
import 'auth/auth_repository.dart';
import 'queue/auth_queue_api.dart';
import 'queue/join_repository.dart';
import 'queue/join_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(GetPrioApp());
}

class GetPrioApp extends StatelessWidget {
  GetPrioApp({super.key, AuthRepository? authRepository})
    : authRepository = authRepository ?? _defaultAuthRepository();

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    const baseUrl = String.fromEnvironment('GETPRIO_API_BASE_URL');
    final joinRepository = JoinRepository(
      RestJoinApi(
        AuthenticatedApiClient(
          baseUrl: baseUrl,
          authRepository: authRepository,
        ),
      ),
    );
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
        allowedHosts: _allowedHosts(),
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
    required this.allowedHosts,
  });

  final AuthRepository authRepository;
  final JoinRepository joinRepository;
  final Set<String> allowedHosts;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<AuthSession?> _restore;
  AuthSession? _session;

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
        allowedHosts: widget.allowedHosts,
        onSignOut: () async {
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
          return CustomerShell(
            user: snapshot.data!.user,
            joinRepository: widget.joinRepository,
            allowedHosts: widget.allowedHosts,
            onSignOut: () async {
              await widget.authRepository.logout();
              if (mounted) setState(() => _session = null);
            },
          );
        }
        return SignInPage(
          authRepository: widget.authRepository,
          onAuthenticated: (session) => setState(() => _session = session),
        );
      },
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
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

  String _authError(Object error) {
    if (error is ApiException && error.message.isNotEmpty) return error.message;
    if (error is FormatException) return error.message;
    return 'We could not sign you in. Check your connection and try again.';
  }
}

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    super.key,
    this.user,
    this.onSignOut,
    this.joinRepository,
    this.allowedHosts = const {},
  });

  final AuthUser? user;
  final VoidCallback? onSignOut;
  final JoinRepository? joinRepository;
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
          HomePage(user: widget.user),
          const ExplorePage(),
          JoinPage(
            repository: widget.joinRepository,
            allowedHosts: widget.allowedHosts,
            customerName: widget.user?.customerName ?? 'Customer',
          ),
          const TicketsPage(),
          AccountPage(onSignOut: widget.onSignOut),
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
  const HomePage({super.key, this.user});

  final AuthUser? user;

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
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Active ticket'),
                  PrimaryBadge(child: const Text('WAITING')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('No active tickets').h3(),
              const SizedBox(height: 4),
              const Text('Scan a vendor QR code when you are ready to join.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  key: const Key('scan-to-join-button'),
                  onPressed: () {},
                  leading: const Icon(LucideIcons.scanQrCode),
                  child: const Text('Scan to join'),
                ),
              ),
            ],
          ),
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
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
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
        Card(
          child: Row(
            children: [
              const Icon(LucideIcons.store),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vendor directory').h3(),
                    const SizedBox(height: 4),
                    const Text(
                      'Vendor details and queue availability will appear here.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('tickets-page'),
      padding: const EdgeInsets.all(20),
      children: [
        const Text('My tickets').h2(),
        const SizedBox(height: 4),
        const Text('Active and historical queue tickets.'),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              const Icon(LucideIcons.ticket, size: 40),
              const SizedBox(height: 12),
              const Text('No tickets yet').h3(),
              const SizedBox(height: 4),
              const Text('Your queue tickets will appear here.'),
            ],
          ),
        ),
      ],
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

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
                  const Text('Carlo Abella').h3(),
                  const SizedBox(height: 4),
                  const Text('carlo@example.com'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlineButton(
          leading: const Icon(LucideIcons.bell),
          onPressed: () {},
          child: const Text('Notification settings'),
        ),
        const SizedBox(height: 12),
        OutlineButton(
          leading: const Icon(LucideIcons.shieldCheck),
          onPressed: () {},
          child: const Text('Password, security, and MFA'),
        ),
        const SizedBox(height: 12),
        OutlineButton(
          leading: const Icon(LucideIcons.logOut),
          onPressed: onSignOut,
          child: const Text('Log out'),
        ),
      ],
    );
  }
}
