import 'package:btl_ltdd/features/home/view/app_shell.dart';
import 'package:btl_ltdd/view/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart'; // 1. MỚI THÊM: Import thư viện

import 'app_theme.dart';
import 'features/admin/data/admin_repository.dart';
import 'features/community/data/community_repository.dart';
import 'features/community/providers/community_provider.dart';
import 'features/planner/data/planner_repository.dart';
import 'features/planner/providers/meal_plan_provider.dart';
import 'features/planner/providers/shopping_provider.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';
import 'features/recipes/data/account_actions.dart';
import 'features/recipes/data/cooking_session_store.dart';
import 'features/recipes/data/legacy_migration_service.dart';
import 'features/recipes/data/screen_awake.dart';
import 'features/recipes/data/timer_notification_service.dart';
import 'features/recipes/data/timer_notifier.dart';
import 'features/recipes/data/recipe_repository.dart';
import 'features/recipes/providers/recipe_list_provider.dart';
import 'providers/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. MỚI THÊM: Khởi tạo dữ liệu đa ngôn ngữ trước khi chạy App
  await EasyLocalization.ensureInitialized();

  // Khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Bật bộ nhớ đệm bền: xem công thức, chế độ nấu... dùng được khi mất mạng,
  // và các thay đổi khi offline được đồng bộ khi có mạng lại.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Firebase Auth tự giữ phiên đăng nhập trên máy (an toàn hơn việc tự lưu mật khẩu).
  // Chờ lần phát đầu tiên để biết phiên cũ đã được khôi phục hay chưa.
  var signedIn = await FirebaseAuth.instance.authStateChanges().first != null;
  // Tài khoản đã bị quản trị viên khoá thì đăng xuất ngay (spec 002, FR-005).
  if (signedIn && await AuthService().isCurrentUserLocked()) {
    await FirebaseAuth.instance.signOut();
    signedIn = false;
  }

  // 3. MỚI THÊM: Bọc MyApp bằng EasyLocalization
  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('vi'),
        Locale('en')
      ], // Các ngôn ngữ bạn muốn hỗ trợ
      path: 'assets/langs', // Đường dẫn thư mục chứa 2 file vi.json và en.json
      fallbackLocale: const Locale(
          'vi'), // Ngôn ngữ mặc định nếu máy người dùng dùng tiếng khác
      child: MyApp(signedIn: signedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.signedIn});

  /// Đã có phiên đăng nhập từ lần trước thì vào thẳng danh sách công thức.
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    // Bọc cả ứng dụng trong MultiProvider
    return MultiProvider(
      providers: [
        // --- KitchenLoop: công thức riêng tư theo tài khoản ---
        // RecipeEditorProvider được tạo riêng cho mỗi lần mở màn hình soạn thảo
        // (xem RecipeEditorScreen.route), không đăng ký toàn cục.
        Provider<RecipeRepository>(
          create: (_) => FirestoreRecipeRepository(
            firestore: FirebaseFirestore.instance,
            auth: FirebaseAuth.instance,
            storage: FirebaseStorage.instance,
          ),
        ),
        // Chuyển công thức dạng cũ (foods) sang dạng có cấu trúc, một lần cho mỗi tài khoản.
        Provider<LegacyMigrationService>(
          create: (_) => LegacyMigrationService(
            firestore: FirebaseFirestore.instance,
            auth: FirebaseAuth.instance,
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => RecipeListProvider(
            repository: ctx.read<RecipeRepository>(),
            migrationRunner: ctx.read<LegacyMigrationService>().migrateIfNeeded,
          ),
        ),
        // Thực đơn tuần và danh sách đi chợ (spec 003). Đi chợ theo tuần đang xem trong thực đơn.
        Provider<PlannerRepository>(
          create: (_) => FirestorePlannerRepository(firestore: FirebaseFirestore.instance, auth: FirebaseAuth.instance),
        ),
        ChangeNotifierProvider(create: (ctx) => MealPlanProvider(repository: ctx.read<PlannerRepository>())),
        ChangeNotifierProxyProvider<MealPlanProvider, ShoppingProvider>(
          create: (ctx) => ShoppingProvider(repository: ctx.read<PlannerRepository>()),
          update: (_, plan, shopping) => shopping!..attachWeek(plan.weekStart),
        ),
        // Cộng đồng (spec 004): chia sẻ công thức, kiểm duyệt tự động ở firestore.rules.
        Provider<CommunityRepository>(
          create: (_) => FirestoreCommunityRepository(firestore: FirebaseFirestore.instance, auth: FirebaseAuth.instance),
        ),
        ChangeNotifierProvider(
          create: (ctx) => CommunityProvider(repository: ctx.read<CommunityRepository>(), recipes: ctx.read<RecipeRepository>()),
        ),
        // Chế độ nấu: phiên nấu dở (cục bộ), báo hết giờ ở nền, giữ màn hình sáng.
        Provider<CookingSessionStore>(
          create: (_) => CookingSessionStore(uidGetter: () => FirebaseAuth.instance.currentUser?.uid),
        ),
        Provider<TimerNotifier>(create: (_) => TimerNotificationService()),
        Provider<ScreenAwake>(create: (_) => const WakelockScreenAwake()),
        // Quản trị tối thiểu (spec 002): chỉ tài khoản có custom claim `admin` dùng được.
        Provider<AdminRepository>(
          create: (_) => FirestoreAdminRepository(firestore: FirebaseFirestore.instance, auth: FirebaseAuth.instance),
        ),
        // Đăng xuất phải huỷ mọi hẹn giờ của tài khoản đang đăng nhập.
        Provider<AccountActions>(
          create: (ctx) => AccountActions.firebase(
            beforeSignOut: ctx.read<TimerNotifier>().cancelAll,
            adminChecker: ctx.read<AdminRepository>().isCurrentUserAdmin,
          ),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        // 4. MỚI THÊM: Cấu hình để MaterialApp nhận diện ngôn ngữ
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,

        debugShowCheckedModeBanner: false,
        title: 'KitchenLoop',
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: signedIn
            ? AppShell(loginBuilder: (_) => const LoginScreen())
            : const LoginScreen(),
      ),
    );
  }
}
