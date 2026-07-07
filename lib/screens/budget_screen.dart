import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../core/app_card.dart';
import '../core/app_status_badge.dart';
import '../core/app_section_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().fetchPreviousDispatchPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dispatch Budgets',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Consumer<TripProvider>(
        builder: (context, trip, _) {
          final plans = trip.allPlans;

          if (plans.isEmpty) {
            if (trip.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: Text(
                'No dispatch plans loaded',
                style: AppTextStyle.caption,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await trip.fetchActiveTrip();
              await trip.fetchPreviousDispatchPlans();
            },
            child: ListView.builder(
              padding: Insets.cardLg,
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final budget = plan.budget;
                final total = budget.fold<double>(
                  0.0,
                  (sum, b) => sum + b.amount,
                );

                return AppCard(
                  margin: const EdgeInsets.only(bottom: 16),
                  borderColor: plan.isActive
                      ? AppColors.primary
                      : AppColors.border,
                  borderWidth: plan.isActive ? 1.5 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: Insets.cardLg,
                        decoration: BoxDecoration(
                          color: plan.isActive
                              ? AppColors.primaryDark.withValues(alpha: 0.3)
                              : Colors.black26,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(Insets.cardRadius),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    plan.docNo,
                                    style: AppTextStyle.subheading.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                AppStatusBadge(status: plan.status),
                              ],
                            ),
                            Insets.gapSm,
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  color: AppColors.textSecondary,
                                  size: 16,
                                ),
                                Insets.gapWSm,
                                Text(
                                  plan.vehicle?.vehiclePlate ?? 'N/A',
                                  style: AppTextStyle.body.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                if (plan.isActive)
                                  Container(
                                    padding: Insets.badgeSm,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: AppTextStyle.badge.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (budget.isEmpty)
                        Padding(
                          padding: Insets.cardLg,
                          child: Text(
                            'No budget lines for this dispatch',
                            style: AppTextStyle.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: budget.length,
                          separatorBuilder: (context, idx) =>
                              const AppDivider(),
                          itemBuilder: (context, idx) {
                            final item = budget[idx];
                            return ListTile(
                              dense: true,
                              title: Text(
                                item.coaName ?? 'Expense Line',
                                style: AppTextStyle.amount,
                              ),
                              subtitle: item.remarks != null
                                  ? Text(
                                      item.remarks!,
                                      style: AppTextStyle.caption.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    )
                                  : null,
                              trailing: Text(
                                '₱${item.amount.toStringAsFixed(2)}',
                                style: AppTextStyle.amount,
                              ),
                            );
                          },
                        ),
                        const AppDivider(),
                        Padding(
                          padding: Insets.cardLg,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: AppTextStyle.amount.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '₱${total.toStringAsFixed(2)}',
                                style: AppTextStyle.amount.copyWith(
                                  color: AppColors.success,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
