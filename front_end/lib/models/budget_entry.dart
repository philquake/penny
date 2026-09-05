import 'budget.dart';
import 'category.dart';

/// A Budget paired with its server-computed BudgetStatus and resolved
/// Category — the shared view model both BudgetsScreen and
/// DashboardScreen render from. The backend computes status server-side
/// (GET /budgets/{id}/status); nothing here derives spend itself.
class BudgetEntry {
  final Budget budget;
  final BudgetStatus status;
  final Category category;
  const BudgetEntry(this.budget, this.status, this.category);
}