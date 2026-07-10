import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../core/app_card.dart';
import '../core/app_status_badge.dart';
import '../core/app_section_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch Budgets')),
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
                style: TextStyle(color: cs.onSurfaceVariant),
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
                  borderColor: plan.isActive ? cs.primary : null,
                  borderWidth: plan.isActive ? 1.5 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Plan header ────────────────────────────────
                      Container(
                        padding: Insets.cardLg,
                        decoration: BoxDecoration(
                          color: plan.isActive
                              ? cs.primary.withValues(alpha: 0.08)
                              : cs.surfaceContainer,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(Insets.cardRadius - 1),
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
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                AppStatusBadge(status: plan.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_car_rounded,
                                  color: cs.onSurfaceVariant,
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  plan.vehicle?.vehiclePlate ?? 'N/A',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                if (plan.isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── Budget lines ───────────────────────────────
                      if (budget.isEmpty)
                        Padding(
                          padding: Insets.cardLg,
                          child: Text(
                            'No budget lines for this dispatch',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
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
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: item.remarks != null
                                  ? Text(
                                      item.remarks!,
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                              trailing: Text(
                                '₱${item.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        AppDivider(),
                        Padding(
                          padding: Insets.cardLg,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '₱${total.toStringAsFixed(2)}',
                                style: TextStyle(
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
