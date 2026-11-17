import 'package:flutter/material.dart';

import 'pages/air_page.dart';
import 'pages/carbon_page.dart';
import 'pages/community_page.dart';
import 'pages/energy_page.dart';
import 'pages/home_page.dart';
import 'settings.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  // Jaring pengaman: bila ada widget yang error, tampilkan kartu ramah (bukan layar merah).
  // Detail error tetap tercetak di Debug Console agar mudah dilacak.
  ErrorWidget.builder = (FlutterErrorDetails d) {
    debugPrint('EcoPulse error: ${d.exceptionAsString()}');
    return const Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco_outlined, color: C.slate, size: 36),
              SizedBox(height: 8),
              Text(
                'Bagian ini gagal ditampilkan.\nTekan muat ulang atau pindah tab.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  };
  runApp(const EcoPulseApp());
}

class EcoPulseApp extends StatefulWidget {
  const EcoPulseApp({super.key});
  @override
  State<EcoPulseApp> createState() => _EcoPulseAppState();
}

class _EcoPulseAppState extends State<EcoPulseApp> {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    state.init();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EcoPulse BMKG',
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.system, // Dark/Light otomatis
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    home: Shell(state),
  );
}

class Shell extends StatefulWidget {
  final AppState s;
  const Shell(this.s, {super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  static const labels = ['Beranda', 'Udara', 'Energi', 'Karbon', 'Komunitas'];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.cloud_outlined,
    Icons.bolt_outlined,
    Icons.co2_outlined,
    Icons.groups_outlined,
  ];
  static const selIcons = [
    Icons.dashboard,
    Icons.cloud,
    Icons.bolt,
    Icons.co2,
    Icons.groups,
  ];

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.s,
      builder: (context, _) {
        final s = widget.s;
        final wide = MediaQuery.of(context).size.width >= 800;
        final pages = [
          HomePage(s, onGo: go),
          AirPage(s, onGo: go),
          EnergyPage(s, onGo: go),
          CarbonPage(s, onGo: go),
          CommunityPage(s, onGo: go),
        ];
        final body = (s.loading && s.hours.isEmpty)
            ? const Center(child: CircularProgressIndicator(color: C.emerald))
            : Column(
                children: [
                  if (s.loading)
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: C.emerald,
                    ),
                  Expanded(child: pages[tab]),
                ],
              );
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: const Row(
              children: [
                Icon(Icons.eco_rounded, color: C.emerald),
                SizedBox(width: 8),
                Text(
                  'EcoPulse ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'BMKG',
                  style: TextStyle(fontWeight: FontWeight.w700, color: C.sky),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Lokasi & sumber data',
                onPressed: () => showSettings(context, s),
                icon: const Icon(Icons.my_location_rounded),
              ),
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: s.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: tab,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: go,
                      destinations: [
                        for (var i = 0; i < labels.length; i++)
                          NavigationRailDestination(
                            icon: Icon(icons[i]),
                            selectedIcon: Icon(selIcons[i]),
                            label: Text(labels[i]),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: go,
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationDestination(
                        icon: Icon(icons[i]),
                        selectedIcon: Icon(selIcons[i]),
                        label: labels[i],
                      ),
                  ],
                ),
        );
      },
    );
  }
}
