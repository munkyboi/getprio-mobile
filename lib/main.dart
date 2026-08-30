import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'auth/auth_models.dart';
import 'auth/auth_repository.dart';
import 'account/ticket_repository.dart';
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
        allowedHosts: _allowedHosts(),
        pushCoordinator: pushCoordinator,
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
    required this.allowedHosts,
    this.pushCoordinator,
  });

  final AuthRepository authRepository;
  final JoinRepository joinRepository;
  final QueueTicketRepository ticketRepository;
  final QueueRepository queueRepository;
  final DirectoryRepository directoryRepository;
  final Set<String> allowedHosts;
  final PushCoordinator? pushCoordinator;

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
    this.ticketRepository,
    this.queueRepository,
    this.directoryRepository,
    this.allowedHosts = const {},
  });

  final AuthUser? user;
  final VoidCallback? onSignOut;
  final JoinRepository? joinRepository;
  final QueueTicketRepository? ticketRepository;
  final QueueRepository? queueRepository;
  final DirectoryRepository? directoryRepository;
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
  const ExplorePage({super.key, this.repository});

  final DirectoryRepository? repository;

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
        if (repository == null)
          Card(
            child: Text('Vendor directory is not configured for this build.'),
          )
        else
          FutureBuilder<List<VendorSummary>>(
            future: repository!.loadVendors(),
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
                    .map((vendor) => _VendorCard(vendor: vendor))
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor});

  final VendorSummary vendor;

  @override
  Widget build(BuildContext context) {
    return Card(
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
