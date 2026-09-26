import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/brand.dart';
import 'login_controller.dart';

class LoginScreen extends GetView<LoginController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.headerBlue,
        body: Stack(
          children: [
            const Positioned.fill(child: BrandBackdrop()),
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
                      child: Column(
                        children: [
                          const BrandLogo(),
                          const SizedBox(height: 22),
                          Text(
                            'Hari Saurabh',
                            style: AppTextStyles.displayLg.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your hostel, all in one place',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FormPanel(controller: controller),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final LoginController controller;

  const _FormPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        32,
        28,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome', style: AppTextStyles.displayMd),
            const SizedBox(height: 6),
            Text(
              'Enter your Student ID to sign in',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            AppTextField(
              controller: controller.studentIdController,
              label: 'Student ID / Bank Code',
              prefixIcon: Icons.badge_outlined,
              keyboardType: TextInputType.text,
              validator: controller.validateStudentId,
            ),
            const SizedBox(height: AppDimens.gapXl),
            Obx(
              () => AppButton(
                label: 'Sign In',
                icon: Icons.arrow_forward_rounded,
                isLoading: controller.isLoading.value,
                onPressed: controller.login,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.headerBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sim_card_outlined, color: AppColors.headerBlue, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Auto-login will automatically authenticate when your registered SIM card is detected.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
