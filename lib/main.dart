import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const GetPrioApp());
}

class GetPrioApp extends StatelessWidget {
  const GetPrioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'GetPrio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: LegacyColorSchemes.lightZinc(),
        radius: 0.8,
      ),
      home: const CustomerShell(),
    );
  }
}

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

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
        children: const [
          HomePage(),
          ExplorePage(),
          JoinPage(),
          TicketsPage(),
          AccountPage(),
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
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home-page'),
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Good morning, Carlo').h2(),
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

class JoinPage extends StatelessWidget {
  const JoinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.scanQrCode, size: 72),
            const SizedBox(height: 20),
            const Text('Join a queue').h2(),
            const SizedBox(height: 8),
            const Text(
              'Scan the QR code displayed by a vendor. GetPrio will identify the location and show the available queue.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                key: const Key('join-scan-button'),
                onPressed: () {},
                leading: const Icon(LucideIcons.scanQrCode),
                child: const Text('Scan QR code'),
              ),
            ),
          ],
        ),
      ),
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
  const AccountPage({super.key});

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
      ],
    );
  }
}
