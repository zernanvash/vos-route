import '../models/driver_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class TripRepository {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();

  Future<DriverProfile?> getDriverProfile() => _auth.getProfile();

  Future<List<dynamic>> fetchPlanList({
    required int driverId,
    required String statusIn,
    String sort = '-id',
    int limit = 1,
    String fields = '*,vehicle_id.*',
  }) async {
    final res = await _api.getDirectus(
      '/items/post_dispatch_plan',
      queryParams: {
        'filter[driver_id][_eq]': driverId,
        'filter[status][_in]': statusIn,
        'sort': sort,
        'limit': limit,
        'fields': fields,
      },
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchPlanStaff(int planId) async {
    final res = await _api.getDirectus(
      '/items/post_dispatch_plan_staff',
      queryParams: {
        'filter[post_dispatch_plan_id][_eq]': planId,
        'fields': '*,user_id.*',
      },
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchPlanBudget(int planId) async {
    final res = await _api.getDirectus(
      '/items/post_dispatch_budgeting',
      queryParams: {'filter[post_dispatch_plan_id][_eq]': planId},
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchPlanInvoices(int planId) async {
    final res = await _api.getDirectus(
      '/items/post_dispatch_invoices',
      queryParams: {
        'filter[post_dispatch_plan_id][_eq]': planId,
        'fields': '*,invoice_id.*',
      },
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchPlanPurchases(int planId) async {
    final res = await _api.getDirectus(
      '/items/post_dispatch_purchases',
      queryParams: {'filter[post_dispatch_plan_id][_eq]': planId},
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchPlanOtherStops(int planId) async {
    final res = await _api.getDirectus(
      '/items/post_dispatch_plan_others',
      queryParams: {'filter[post_dispatch_plan_id][_eq]': planId},
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchCustomers(List<String> customerCodes) async {
    final res = await _api.getDirectus(
      '/items/customer',
      queryParams: {
        'filter[customer_code][_in]': customerCodes.join(','),
        'fields': 'customer_code,customer_name,latitude,longitude,location',
      },
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchInvoiceStatuses(List<int> planIds) async {
    final res = await _api.getDirectus(
      '/items/post_dispatch_invoices',
      queryParams: {
        'filter[post_dispatch_plan_id][_in]': planIds.join(','),
        'fields': 'id,status,post_dispatch_plan_id',
      },
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchBudgetForPlans(List<int> planIds) async {
    final res = await _api.getDirectus(
      '/items/post_dispatch_budgeting',
      queryParams: {'filter[post_dispatch_plan_id][_in]': planIds.join(',')},
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchInvoiceStatusesForPlans(List<int> planIds) async {
    final res = await _api.getDirectus(
      '/items/post_dispatch_invoices',
      queryParams: {
        'filter[post_dispatch_plan_id][_in]': planIds.join(','),
        'fields': 'id,status,post_dispatch_plan_id',
      },
    );
    return res.data['data'] as List<dynamic>;
  }
}
