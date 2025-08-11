import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/auth/presentation/pages/login_page.dart';
import 'package:gspappv2/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:gspappv2/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gspappv2/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:gspappv2/features/party/presentation/bloc/party_bloc.dart';
import 'package:gspappv2/features/home/presentation/pages/home_page.dart';
import 'package:gspappv2/features/invoice/presentation/bloc/invoice_bloc.dart';
import 'package:gspappv2/features/settings/bloc/settings_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gspappv2/features/party/data/repositories/party_repository.dart';
import 'package:gspappv2/features/invoice/data/repositories/invoice_repository.dart';
import 'package:gspappv2/features/item/data/repositories/item_repository.dart';
import 'package:gspappv2/features/item/presentation/bloc/item_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:gspappv2/core/widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Platform-specific initialization for file picker
  if (!kIsWeb) {
    await FilePicker.platform.clearTemporaryFiles();
  }

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Run the app
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final storeProvider = StoreProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<StoreProvider>(
          create: (_) => storeProvider,
        ),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(),
        ),
        BlocProvider<PartyBloc>(
          create: (context) => PartyBloc(
            PartyRepository(),
          ),
        ),
        BlocProvider<InvoiceBloc>(
          create: (context) => InvoiceBloc(
            invoiceRepository: InvoiceRepository(),
          ),
        ),
        BlocProvider<SettingsBloc>(
          create: (context) => SettingsBloc(),
        ),
        BlocProvider<ReportsBloc>(
          create: (context) => ReportsBloc(),
        ),
        BlocProvider<ItemBloc>(
          create: (context) => ItemBloc(
            itemRepository: ItemRepository(),
          ),
        ),
      ],
      child: Consumer<StoreProvider>(builder: (context, storeProvider, _) {
        return MaterialApp(
          title: 'GSP',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomePage(),
          },
        );
      }),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasInitialized = false;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If Firebase is still initializing, show loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // If user is logged in, show HomePage, otherwise show LoginPage
        if (snapshot.hasData && snapshot.data != null) {
          // Initialize the store provider if not already done
          if (!_hasInitialized) {
            _hasInitialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final storeProvider =
                  Provider.of<StoreProvider>(context, listen: false);
              storeProvider.initialize();
            });
          }
          return const HomePage();
        } else {
          _hasInitialized = false; // Reset when user logs out
          return const LoginPage();
        }
      },
    );
  }
}
