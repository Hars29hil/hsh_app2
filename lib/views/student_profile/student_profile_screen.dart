import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common_enums/admission_status.dart';
import '../../common_models/student_profile/student_profile_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_refresh_indicator.dart';
import '../shared/widgets/async_state_view.dart';
import '../shared/widgets/gradient_header.dart';
import '../shared/widgets/icon_badge.dart';
import '../shared/widgets/info_row.dart';
import '../shared/widgets/section_header.dart';
import 'student_profile_controller.dart';

class StudentProfileScreen extends GetView<StudentProfileController> {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.refreshProfile,
          builder: (context) {
            final profile = controller.profile.value;
            if (profile == null) return const SizedBox.shrink();
            return AppRefreshIndicator(
              onRefresh: controller.refreshProfile,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _ProfileHero(profile: profile),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.gapXl,
                        AppDimens.screenPadding,
                        AppDimens.gapXl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(title: 'Quick actions'),
                          const _QuickActions(),
                          const SizedBox(height: AppDimens.gapXl),
                          const SectionHeader(title: 'Personal details'),
                          _DetailsCard(
                            rows: [
                              InfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: profile.phone,
                              ),
                              InfoRow(
                                icon: Icons.chat_outlined,
                                label: 'WhatsApp',
                                value: profile.whatsappNumber,
                              ),
                              InfoRow(
                                icon: Icons.alternate_email_rounded,
                                label: 'Email',
                                value: profile.email,
                                locked: true,
                              ),
                              if (profile.dob.isNotEmpty)
                                InfoRow(
                                  icon: Icons.cake_outlined,
                                  label: 'Date of birth',
                                  value: profile.dob,
                                  locked: true,
                                ),
                              InfoRow(
                                icon: Icons.bloodtype_outlined,
                                label: 'Blood group',
                                value: profile.bloodGroup,
                              ),
                              InfoRow(
                                icon: Icons.two_wheeler_outlined,
                                label: 'Vehicle',
                                value: profile.vehicleNumber,
                              ),
                            ],
                          ),
                          if (profile.fatherPhone.isNotEmpty ||
                              profile.motherPhone.isNotEmpty) ...[
                            const SizedBox(height: AppDimens.gapXl),
                            const SectionHeader(
                              title: 'Parent & guardian contact',
                            ),
                            _DetailsCard(
                              rows: [
                                if (profile.fatherPhone.isNotEmpty)
                                  InfoRow(
                                    icon: Icons.family_restroom_outlined,
                                    label: "Father's phone",
                                    value: profile.fatherPhone,
                                  ),
                                if (profile.motherPhone.isNotEmpty)
                                  InfoRow(
                                    icon: Icons.family_restroom_outlined,
                                    label: "Mother's phone",
                                    value: profile.motherPhone,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppDimens.gapXl),
                          const SectionHeader(title: 'Sports & fitness'),
                          _LifestyleChips(profile: profile),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final StudentProfileModel profile;

  const _ProfileHero({required this.profile});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final initial = profile.firstName.isNotEmpty
        ? profile.firstName[0].toUpperCase()
        : '?';

    return SliverGradientHeader(
      overline: _greeting,
      title: profile.fullName,
      subtitle: profile.email,
      heroLeading: Container(
        width: 60,
        height: 60,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: Text(
            initial,
            style: AppTextStyles.headline.copyWith(color: AppColors.primary),
          ),
        ),
      ),
      actions: [
        HeaderIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onPressed: () => Get.toNamed(Routes.setting),
        ),
      ],
      child: Wrap(
        spacing: AppDimens.gapSm,
        runSpacing: AppDimens.gapSm,
        children: [
          if (profile.room.isNotEmpty)
            HeaderPill(
              icon: Icons.meeting_room_outlined,
              label: profile.room.toLowerCase().contains('room')
                  ? profile.room
                  : 'Room ${profile.room}',
            ),
          HeaderPill(
            icon: Icons.verified_outlined,
            label: profile.status.label,
          ),
          if (profile.groupName.isNotEmpty)
            HeaderPill(icon: Icons.groups_outlined, label: profile.groupName),
          if (profile.bankCode.isNotEmpty)
            HeaderPill(
              icon: Icons.badge_outlined,
              label: 'ID: ${profile.bankCode}',
            ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const _QuickAction(this.label, this.icon, this.color, this.route);
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = [
    _QuickAction(
      'Leave',
      Icons.beach_access_outlined,
      AppColors.secondary,
      Routes.leave,
    ),
    _QuickAction(
      'Payments',
      Icons.account_balance_wallet_outlined,
      AppColors.successGreen,
      Routes.fees,
    ),
    _QuickAction(
      'Notes',
      Icons.sticky_note_2_outlined,
      AppColors.warningOrange,
      Routes.notes,
    ),
    _QuickAction(
      'More',
      Icons.grid_view_rounded,
      AppColors.primary,
      Routes.services,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.gapLg),
              onTap: () => Get.toNamed(_actions[i].route),
              child: Column(
                children: [
                  IconBadge(
                    icon: _actions[i].icon,
                    color: _actions[i].color,
                    size: 42,
                  ),
                  const SizedBox(height: AppDimens.gapSm),
                  Text(
                    _actions[i].label,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final List<Widget> rows;

  const _DetailsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.cardPadding,
        vertical: AppDimens.gapSm,
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _LifestyleChips extends StatelessWidget {
  final StudentProfileModel profile;

  const _LifestyleChips({required this.profile});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Cricket', Icons.sports_cricket_outlined, profile.playsCricket),
      ('Badminton', Icons.sports_tennis_outlined, profile.playsBadminton),
      ('Gym', Icons.fitness_center_outlined, profile.goesToGym),
    ];
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.gapLg),
              color: items[i].$3 ? AppColors.primarySoft : AppColors.surface,
              elevated: !items[i].$3,
              child: Column(
                children: [
                  Icon(
                    items[i].$2,
                    color: items[i].$3
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    items[i].$1,
                    style: AppTextStyles.label.copyWith(
                      color: items[i].$3
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
