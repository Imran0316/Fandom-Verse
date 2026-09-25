import 'package:flutter/material.dart';

import 'core/animations/app_transitions.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'models/catalog_docs.dart';
import 'models/community_docs.dart';
import 'models/content_docs.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/admin/content_editor_screen.dart';
import 'screens/content/content_detail_screen.dart';
import 'screens/content/explore_screen.dart';
import 'screens/content/saved_screen.dart';
import 'screens/communities/communities_screen.dart';
import 'screens/communities/community_detail_screen.dart';
import 'screens/communities/edit_community_screen.dart';
import 'screens/communities/feed_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/get_started/get_started_screen.dart';
import 'screens/interests/interests_screen.dart';
import 'screens/profile/about_screen.dart';
import 'screens/profile/ai_helper_screen.dart';
import 'screens/profile/contact_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/follow_requests_screen.dart';
import 'screens/profile/notifications_screen.dart';
import 'screens/profile/user_profile_screen.dart';
import 'screens/seller/seller_dashboard.dart';
import 'screens/shop/cart_screen.dart';
import 'screens/shop/orders_screen.dart';
import 'screens/shop/product_detail_screen.dart';
import 'screens/splash/splash_screen.dart';

class FandomVerseApp extends StatelessWidget {
  const FandomVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FandomVerse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      onGenerateRoute: (settings) {
        final name = settings.name ?? AppRoutes.getStarted;

        Widget page;
        switch (name) {
          case AppRoutes.splash:
            page = const SplashScreen();
            break;
          case AppRoutes.getStarted:
            page = const GetStartedScreen();
            break;
          case AppRoutes.signIn:
            page = const GetStartedScreen(openAuthInitially: true);
            break;
          case AppRoutes.interests:
            page = const InterestsScreen();
            break;
          case AppRoutes.dashboard:
            page = const DashboardScreen();
            break;
          case AppRoutes.admin:
            page = const AdminGate();
            break;
          case AppRoutes.seller:
            page = const SellerDashboardScreen();
            break;
          case AppRoutes.editProfile:
            page = EditProfileScreen(profile: settings.arguments as dynamic);
            break;
          case AppRoutes.interestsEditor:
            page = InterestsEditorScreen(
              initial: settings.arguments as List<String>?,
            );
            break;
          case AppRoutes.notifications:
            page = const NotificationsScreen();
            break;
          case AppRoutes.aiHelper:
            page = const AiHelperScreen();
            break;
          case AppRoutes.contact:
            page = const ContactScreen();
            break;
          case AppRoutes.about:
            page = const AboutScreen();
            break;
          case AppRoutes.communities:
            page = const CommunitiesScreen();
            break;
          case AppRoutes.createCommunity:
            page = const CreateCommunityScreen();
            break;
          case AppRoutes.editCommunity:
            final community = settings.arguments;
            if (community is CommunityDoc) {
              page = EditCommunityScreen(community: community);
            } else {
              page = const Scaffold(body: SizedBox.shrink());
            }
            break;
          case AppRoutes.communityDetail:
            final id = settings.arguments as String?;
            if (id == null || id.isEmpty) {
              page = const Scaffold(body: SizedBox.shrink());
            } else {
              page = CommunityDetailScreen(communityId: id);
            }
            break;
          case AppRoutes.feed:
            page = const FeedScreen();
            break;
          case AppRoutes.cart:
            page = const CartScreen();
            break;
          case AppRoutes.orders:
            page = const OrdersScreen();
            break;
          case AppRoutes.product:
            final product = settings.arguments;
            if (product is MerchProductDoc) {
              page = ProductDetailScreen(product: product);
            } else {
              page = const Scaffold(body: SizedBox.shrink());
            }
            break;
          case AppRoutes.contentDetail:
            final detailArgs = settings.arguments;
            if (detailArgs is ContentDetailArgs) {
              page = ContentDetailScreen(args: detailArgs);
            } else {
              page = const Scaffold(body: SizedBox.shrink());
            }
            break;
          case AppRoutes.explore:
            final exploreArgs = settings.arguments;
            if (exploreArgs is ExploreArgs) {
              page = ExploreScreen(
                initialFandomId: exploreArgs.fandomId,
                initialType: exploreArgs.type,
              );
            } else {
              page = const ExploreScreen();
            }
            break;
          case AppRoutes.saved:
            page = const SavedScreen();
            break;
          case AppRoutes.contentEditor:
            final editorArgs = settings.arguments;
            page = ContentEditorScreen(
              existing: editorArgs is ContentDoc ? editorArgs : null,
            );
            break;
          case AppRoutes.userProfile:
            final uid = settings.arguments as String?;
            if (uid == null || uid.isEmpty) {
              page = const Scaffold(body: SizedBox.shrink());
            } else {
              page = UserProfileScreen(uid: uid);
            }
            break;
          case AppRoutes.followRequests:
            page = const FollowRequestsScreen();
            break;
          default:
            page = const GetStartedScreen();
        }

        // Dashboard / splash / get-started keep default fade; secondary screens animate.
        if (name == AppRoutes.dashboard ||
            name == AppRoutes.splash ||
            name == AppRoutes.getStarted) {
          return MaterialPageRoute(builder: (_) => page, settings: settings);
        }
        if (name == AppRoutes.admin ||
            name == AppRoutes.seller ||
            name == AppRoutes.communities ||
            name == AppRoutes.communityDetail ||
            name == AppRoutes.feed ||
            name == AppRoutes.product) {
          return AppTransitions.rightToLeft(page, settings: settings);
        }
        if (name == AppRoutes.editProfile ||
            name == AppRoutes.interestsEditor ||
            name == AppRoutes.createCommunity ||
            name == AppRoutes.editCommunity ||
            name == AppRoutes.followRequests ||
            name == AppRoutes.cart ||
            name == AppRoutes.orders ||
            name == AppRoutes.contentEditor) {
          return AppTransitions.bottomUp(page, settings: settings);
        }
        if (name == AppRoutes.contentDetail ||
            name == AppRoutes.explore ||
            name == AppRoutes.saved) {
          return AppTransitions.rightToLeft(page, settings: settings);
        }
        if (name == AppRoutes.aiHelper) {
          return AppTransitions.scaleFade(page, settings: settings);
        }
        return AppTransitions.fadeSlide(page, settings: settings);
      },
      initialRoute: AppRoutes.splash,
    );
  }
}
