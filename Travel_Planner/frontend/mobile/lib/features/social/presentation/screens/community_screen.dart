import 'package:flutter/material.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../community_feed_notifier.dart';
import '../../data/community_post_repository.dart';
import 'community_feed_screen.dart';

class CommunityScreen extends StatelessWidget {
  final AuthNotifier? authNotifier;
  final CommunityFeedNotifier? notifier;
  final CommunityPostRepository? repository;

  const CommunityScreen({
    super.key,
    this.authNotifier,
    this.notifier,
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return CommunityFeedScreen(
      authNotifier: authNotifier,
      notifier: notifier,
      repository: repository,
    );
  }
}
