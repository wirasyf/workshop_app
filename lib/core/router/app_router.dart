import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/notification_screen.dart';
import '../../features/dashboard/presentation/screens/cashier_dashboard_screen.dart';
import '../../features/pos/presentation/screens/pos_product_screen.dart';
import '../../features/pos/presentation/screens/cart_screen.dart';
import '../../features/pos/presentation/screens/payment_success_screen.dart';
import '../../features/pos/presentation/screens/transaction_history_screen.dart';
import '../../features/products/presentation/screens/product_list_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/products/presentation/screens/product_form_screen.dart';
import '../../features/products/presentation/screens/stock_adjustment_screen.dart';
import '../../features/reports/presentation/screens/report_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/store_profile_screen.dart';
import '../../features/settings/presentation/screens/change_password_screen.dart';
import '../../features/settings/presentation/screens/receipt_template_screen.dart';
import '../../shared/screens/shell_screen.dart';
import '../constants/app_constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      if (authState.isLoading) return null; // Tunggu loading selesai di Splash

      final isLoggedIn = authState.valueOrNull != null;
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        // Jika tidak login dan bukan di halaman login, lempar ke login
        return isLogin ? null : '/login';
      }

      if (isLoggedIn && (isLogin || isSplash)) {
        // Jika sudah login tapi masih di login/splash, lempar ke dashboard sesuai role
        final role = authState.valueOrNull?.role ?? AppConstants.roleKasir;
        return role == AppConstants.roleOwner ? '/dashboard' : '/cashier';
      }
      
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      // Shell route dengan bottom navigation
      ShellRoute(
        builder: (_, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const OwnerDashboardScreen()),
          GoRoute(path: '/cashier', builder: (_, __) => const CashierDashboardScreen()),
          GoRoute(
            path: '/pos',
            builder: (_, __) => const PosProductScreen(),
            routes: [
              GoRoute(path: 'cart', builder: (_, __) => const CartScreen()),
              GoRoute(path: 'success', builder: (_, state) => PaymentSuccessScreen(data: state.extra as Map<String, dynamic>?)),
            ],
          ),
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductListScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, __) => const ProductFormScreen()),
              GoRoute(path: ':id', builder: (_, state) =>
                  ProductDetailScreen(productId: int.parse(state.pathParameters['id']!))),
              GoRoute(path: ':id/edit', builder: (_, state) =>
                  ProductFormScreen(productId: int.parse(state.pathParameters['id']!))),
              GoRoute(path: ':id/adjust', builder: (_, state) =>
                  StockAdjustmentScreen(productId: int.parse(state.pathParameters['id']!))),
            ],
          ),
          GoRoute(path: '/history', builder: (_, __) => const TransactionHistoryScreen()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationScreen()),
          GoRoute(
            path: '/settings', 
            builder: (_, __) => const SettingsScreen(),
            routes: [
              GoRoute(path: 'store-profile', builder: (_, __) => const StoreProfileScreen()),
              GoRoute(path: 'change-password', builder: (_, __) => const ChangePasswordScreen()),
              GoRoute(path: 'receipt-template', builder: (_, __) => const ReceiptTemplateScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
