import 'package:flutter/foundation.dart';
import '../models/trip.dart';
import '../models/stop.dart';
import '../models/action_entry.dart';
import '../models/photo_quest.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/action_queue_service.dart';
import '../services/notification_service.dart';
import '../services/timezone_service.dart';

class TripProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final ActionQueueService _queue = ActionQueueService();

  final Map<int, Map<String, dynamic>> _tripCache = {};

  /// Safely parses a coordinate value that Directus may return as either a
  /// [String] (e.g. "16.0083000000") or a [num]. Returns null on failure.
  static double? _parseCoordinate(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static double? _coordinateFromCustomer(
    Map<String, dynamic>? customerData,
    String field, {
    bool isLatitude = true,
  }) {
    final coord = _parseCoordinate(customerData?[field]);
    if (coord != null) return coord;
    final location = customerData?['location'];
    if (location is Map<String, dynamic>) {
      final coords = location['coordinates'];
      if (coords is List && coords.length >= 2) {
        return (coords[isLatitude ? 1 : 0] as num?)?.toDouble();
      }
    }
    return null;
  }

  PostDispatchPlan? _activeTrip;
  List<InvoiceStop> _invoiceStops = [];
  List<PurchaseStop> _purchaseStops = [];
  List<OtherStop> _otherStops = [];
  List<PostDispatchPlan> _previousDispatchPlans = [];
  List<PostDispatchPlan> _pendingPlans = [];
  List<PostDispatchPlan> _cachedHistory = [];
  bool _isLoading = false;
  String? _error;
  PhotoQuest? _currentQuest;
  bool _invoicesConfirmed = false;

  bool get invoicesConfirmed => _invoicesConfirmed;

  void confirmInvoices() {
    _invoicesConfirmed = true;
    notifyListeners();
  }

  void resetInvoicesConfirmed() {
    _invoicesConfirmed = false;
    notifyListeners();
  }

  /// Captured POD photo paths, keyed by invoice stop id. Kept in memory so the
  /// POD panel can show *all* photos for a stop across rebuilds/navigation.
  final Map<int, List<String>> _podPhotosByStop = {};

  List<String> getPodPhotos(int stopId) =>
      List.unmodifiable(_podPhotosByStop[stopId] ?? const []);

  void addPodPhoto(int stopId, String path) {
    _podPhotosByStop.putIfAbsent(stopId, () => []).add(path);
    notifyListeners();
  }

  PostDispatchPlan? _selectedPlan;
  List<InvoiceStop> _selectedInvoiceStops = [];
  List<PurchaseStop> _selectedPurchaseStops = [];
  List<OtherStop> _selectedOtherStops = [];
  int _currentTabIndex = 0;

  int? _lastNotifiedTripId;

  PostDispatchPlan? get activeTrip => _activeTrip;
  PostDispatchPlan? get selectedPlan => _selectedPlan ?? _activeTrip;

  List<InvoiceStop> get invoiceStops =>
      _selectedPlan != null ? _selectedInvoiceStops : _invoiceStops;
  List<PurchaseStop> get purchaseStops =>
      _selectedPlan != null ? _selectedPurchaseStops : _purchaseStops;
  List<OtherStop> get otherStops =>
      _selectedPlan != null ? _selectedOtherStops : _otherStops;

  List<PostDispatchPlan> get previousDispatchPlans => _previousDispatchPlans;
  List<PostDispatchPlan> get pendingPlans => _pendingPlans;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PhotoQuest? get currentQuest => _currentQuest;
  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  Future<void> selectPlan(
    PostDispatchPlan plan, {
    bool forceRefresh = false,
  }) async {
    if (plan.id == _activeTrip?.id) {
      _selectedPlan = null;
      _selectedInvoiceStops = [];
      _selectedPurchaseStops = [];
      _selectedOtherStops = [];
      _currentTabIndex = 1;
      notifyListeners();
      return;
    }

    _selectedPlan = plan;
    _currentTabIndex = 1;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final cached = _tripCache[plan.id];
    if (cached != null) {
      _parseCachedPayloadIntoSelected(cached);
      _isLoading = false;
      notifyListeners();
    }

    try {
      final planId = plan.id;
      final staffRes = await _api.getDirectus(
        '/items/post_dispatch_plan_staff',
        queryParams: {
          'filter[post_dispatch_plan_id][_eq]': planId,
          'fields': '*,user_id.*',
        },
      );
      final budgetRes = await _api.getDirectus(
        '/items/post_dispatch_budgeting',
        queryParams: {'filter[post_dispatch_plan_id][_eq]': planId},
      );
      final invoicesRes = await _api.getDirectus(
        '/items/post_dispatch_invoices',
        queryParams: {
          'filter[post_dispatch_plan_id][_eq]': planId,
          'fields': '*,invoice_id.*',
        },
      );
      final purchasesRes = await _api.getDirectus(
        '/items/post_dispatch_purchases',
        queryParams: {'filter[post_dispatch_plan_id][_eq]': planId},
      );
      final othersRes = await _api.getDirectus(
        '/items/post_dispatch_plan_others',
        queryParams: {'filter[post_dispatch_plan_id][_eq]': planId},
      );

      final staffList = staffRes.data['data'] as List<dynamic>;
      final parsedCrew = staffList.map((s) {
        final user = s['user_id'];
        String name = 'Crew Helper';
        int uId = 0;
        if (user is Map<String, dynamic>) {
          final fname =
              user['first_name'] ??
              user['firstName'] ??
              user['user_fname'] ??
              '';
          final lname =
              user['last_name'] ?? user['lastName'] ?? user['user_lname'] ?? '';
          name = '$fname $lname'.trim();
          if (name.isEmpty) {
            name = user['email'] ?? user['user_email'] ?? 'Crew Helper';
          }
          uId = (user['id'] as num?)?.toInt() ?? 0;
        } else if (user is num) {
          uId = user.toInt();
        } else if (user is String) {
          uId = int.tryParse(user) ?? 0;
        }
        return CrewMember(userId: uId, name: name, role: s['role'] ?? 'helper');
      }).toList();

      final budgetList = budgetRes.data['data'] as List<dynamic>;
      final parsedBudget = budgetList
          .map(
            (b) => BudgetLine(
              id: b['id'] as int,
              coaName: b['remarks'] ?? 'Expenses',
              amount: (b['amount'] as num?)?.toDouble() ?? 0.0,
              remarks: b['remarks'],
            ),
          )
          .toList();

      _selectedPlan = PostDispatchPlan(
        id: plan.id,
        docNo: plan.docNo,
        driverId: plan.driverId,
        vehicleId: plan.vehicleId,
        status: plan.status,
        startingPoint: plan.startingPoint,
        totalDistance: plan.totalDistance,
        amount: plan.amount,
        estimatedTimeOfDispatch: plan.estimatedTimeOfDispatch,
        estimatedTimeOfArrival: plan.estimatedTimeOfArrival,
        timeOfDispatch: plan.timeOfDispatch,
        timeOfArrival: plan.timeOfArrival,
        dateEncoded: plan.dateEncoded,
        remarks: plan.remarks,
        vehicle: plan.vehicle,
        crew: parsedCrew,
        budget: parsedBudget,
      );

      final invoicesList = invoicesRes.data['data'] as List<dynamic>;

      final customerCodes = invoicesList
          .map(
            (inv) => inv['invoice_id'] is Map<String, dynamic>
                ? inv['invoice_id']['customer_code']?.toString()
                : null,
          )
          .whereType<String>()
          .where((code) => code.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> customerMap = {};
      if (customerCodes.isNotEmpty) {
        try {
          final customersRes = await _api.getDirectus(
            '/items/customer',
            queryParams: {
              'filter[customer_code][_in]': customerCodes.join(','),
              'fields':
                  'customer_code,customer_name,latitude,longitude,location',
            },
          );
          final customersDataList = customersRes.data['data'] as List<dynamic>;
          for (var cust in customersDataList) {
            if (cust is Map<String, dynamic>) {
              final code = cust['customer_code']?.toString();
              if (code != null) {
                customerMap[code] = cust;
              }
            }
          }
        } catch (e) {
          debugPrint('[TripProvider] Error fetching customer coordinates: $e');
        }
      }

      _selectedInvoiceStops = invoicesList.map((inv) {
        final isInvoiceMap = inv['invoice_id'] is Map<String, dynamic>;
        final invoiceNo = isInvoiceMap ? inv['invoice_id']['invoice_no'] : null;
        final customerCode = isInvoiceMap
            ? inv['invoice_id']['customer_code']?.toString()
            : null;
        final totalAmount = isInvoiceMap
            ? (inv['invoice_id']['total_amount'] as num?)?.toDouble()
            : null;
        final netAmount = isInvoiceMap
            ? (inv['invoice_id']['net_amount'] as num?)?.toDouble()
            : null;

        final customerData = customerCode != null
            ? customerMap[customerCode]
            : null;
        final customerName =
            customerData?['customer_name']?.toString() ?? customerCode;

        return InvoiceStop(
          id: inv['id'] as int,
          postDispatchPlanId: inv['post_dispatch_plan_id'] as int? ?? 0,
          invoiceId: isInvoiceMap
              ? (inv['invoice_id']['invoice_id'] as int? ?? 0)
              : (inv['invoice_id'] as int? ?? 0),
          invoiceNo: invoiceNo ?? 'INV-#${inv['invoice_id']}',
          customerCode: customerCode,
          customerName: customerName,
          amount: netAmount ?? totalAmount ?? 0.0,
          address: isInvoiceMap
              ? (inv['invoice_id']['shipping_address'] as String? ??
                    'No Address')
              : 'No Address',
          latitude: _coordinateFromCustomer(customerData, 'latitude'),
          longitude: _coordinateFromCustomer(
            customerData,
            'longitude',
            isLatitude: false,
          ),
          distance: (inv['distance'] as num?)?.toDouble() ?? 0.0,
          status: inv['status'] as String? ?? 'Pending',
          sequence: inv['sequence'] as int? ?? 0,
          remarks: inv['remarks'] as String?,
        );
      }).toList();

      final purchasesList = purchasesRes.data['data'] as List<dynamic>;
      _selectedPurchaseStops = purchasesList
          .map(
            (p) => PurchaseStop(
              id: p['id'] as int,
              postDispatchPlanId: p['post_dispatch_plan_id'] as int? ?? 0,
              poId: p['po_id'] as int? ?? 0,
              poNo: 'PO-#${p['po_id']}',
              supplierName: 'Supplier',
              distance: (p['distance'] as num?)?.toDouble() ?? 0.0,
              sequence: p['sequence'] as int? ?? 0,
              status: p['status'] as String? ?? 'Pending',
            ),
          )
          .toList();

      final othersList = othersRes.data['data'] as List<dynamic>;
      _selectedOtherStops = othersList
          .map(
            (o) => OtherStop(
              id: o['id'] as int,
              postDispatchPlanId: o['post_dispatch_plan_id'] as int? ?? 0,
              remarks: o['remarks'] as String? ?? 'Other Stop',
              distance: (o['distance'] as num?)?.toDouble() ?? 0.0,
              latitude: _parseCoordinate(o['latitude']),
              longitude: _parseCoordinate(o['longitude']),
              sequence: o['sequence'] as int? ?? 0,
              status: o['status'] as String? ?? 'Pending',
            ),
          )
          .toList();

      _tripCache[_selectedPlan!.id] = {
        'trip': _selectedPlan!.toJson(),
        'invoice_stops': _selectedInvoiceStops.map((s) => s.toJson()).toList(),
        'purchase_stops': _selectedPurchaseStops
            .map((s) => s.toJson())
            .toList(),
        'other_stops': _selectedOtherStops.map((s) => s.toJson()).toList(),
      };
    } catch (e) {
      _error = 'Failed to load details: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _parseCachedPayloadIntoSelected(Map<String, dynamic> cached) {
    try {
      if (cached['trip'] != null) {
        _selectedPlan = PostDispatchPlan.fromJson(
          cached['trip'] as Map<String, dynamic>,
        );
      }
      if (cached['invoice_stops'] != null) {
        _selectedInvoiceStops =
            (cached['invoice_stops'] as List<dynamic>?)
                ?.map((e) => InvoiceStop.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
      }
      if (cached['purchase_stops'] != null) {
        _selectedPurchaseStops =
            (cached['purchase_stops'] as List<dynamic>?)
                ?.map((e) => PurchaseStop.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
      }
      if (cached['other_stops'] != null) {
        _selectedOtherStops =
            (cached['other_stops'] as List<dynamic>?)
                ?.map((e) => OtherStop.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
      }
    } catch (e) {
      debugPrint('[TripProvider] Error parsing cached selectPlan: $e');
    }
  }

  Map<String, int> get invoiceStatusCounts {
    final counts = <String, int>{
      'Fulfilled': 0,
      'Not Fulfilled': 0,
      'Fulfilled with Returns': 0,
      'Fulfilled with Concerns': 0,
      'Pending': 0,
    };
    for (final s in invoiceStops) {
      if (counts.containsKey(s.status)) {
        counts[s.status] = counts[s.status]! + 1;
      } else {
        counts['Pending'] = counts['Pending']! + 1;
      }
    }
    return counts;
  }

  Map<String, int> get aggregatedInvoiceStatusCounts {
    final counts = <String, int>{
      'Fulfilled': 0,
      'Not Fulfilled': 0,
      'Fulfilled with Returns': 0,
      'Fulfilled with Concerns': 0,
      'Pending': 0,
    };
    for (final s in invoiceStops) {
      if (counts.containsKey(s.status)) {
        counts[s.status] = counts[s.status]! + 1;
      } else {
        counts['Pending'] = counts['Pending']! + 1;
      }
    }
    for (final plan in allPlans) {
      if (plan.id == _activeTrip?.id) continue;
      final cached = _tripCache[plan.id];
      if (cached == null) continue;
      final stops = cached['invoice_stops'] as List<dynamic>? ?? [];
      for (final s in stops) {
        final status = s['status'] as String? ?? 'Pending';
        if (counts.containsKey(status)) {
          counts[status] = counts[status]! + 1;
        } else {
          counts['Pending'] = counts['Pending']! + 1;
        }
      }
    }
    return counts;
  }

  List<Object> get allStops {
    final stops = <Object>[];
    stops.addAll(invoiceStops);
    stops.addAll(purchaseStops);
    stops.addAll(otherStops);
    return stops;
  }

  int get completedStops => invoiceStops.where((s) => s.isCompleted).length;
  int get totalStops =>
      invoiceStops.length + purchaseStops.length + otherStops.length;

  bool get areAllInvoiceStopsTerminal =>
      invoiceStops.isNotEmpty && invoiceStops.every((s) => s.isTerminal);

  List<StopGroup> get groupedStops {
    final map = <String, List<InvoiceStop>>{};
    final customerInfo = <String, Map<String, dynamic>>{};
    for (final s in invoiceStops) {
      final key = s.customerCode ?? 'unknown';
      map.putIfAbsent(key, () => []);
      map[key]!.add(s);
      if (s.customerCode != null) {
        customerInfo[key] = {
          'name': s.customerName,
          'lat': s.latitude,
          'lng': s.longitude,
        };
      }
    }
    return map.entries.map((e) {
      final info = customerInfo[e.key];
      return StopGroup(
        customerCode: e.key,
        customerName: info?['name'] as String?,
        latitude: info?['lat'] as double?,
        longitude: info?['lng'] as double?,
        stops: e.value,
      );
    }).toList();
  }

  Future<void> fetchActiveTrip({bool forceRefresh = false}) async {
    _invoicesConfirmed = false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _auth.getProfile();
      if (profile == null) throw Exception('Not authenticated');
      debugPrint(
        '[TripProvider] fetching trips for driver_id=${profile.userId}',
      );

      final response = await _api.getDirectus(
        '/items/post_dispatch_plan',
        queryParams: {
          'filter[driver_id][_eq]': profile.userId,
          'filter[status][_in]': 'For Dispatch,For Inbound',
          'sort': '-id',
          'limit': '1',
          'fields': '*,vehicle_id.*',
        },
      );

      final dataList = response.data['data'] as List<dynamic>;
      if (dataList.isEmpty) {
        _activeTrip = null;
        _invoiceStops = [];
        _purchaseStops = [];
        _otherStops = [];
        _pendingPlans = [];
      } else {
        final planJson = dataList.first as Map<String, dynamic>;
        final planId = planJson['id'] as int;

        final staffRes = await _api.getDirectus(
          '/items/post_dispatch_plan_staff',
          queryParams: {
            'filter[post_dispatch_plan_id][_eq]': planId,
            'fields': '*,user_id.*',
          },
        );
        final budgetRes = await _api.getDirectus(
          '/items/post_dispatch_budgeting',
          queryParams: {'filter[post_dispatch_plan_id][_eq]': planId},
        );
        final invoicesRes = await _api.getDirectus(
          '/items/post_dispatch_invoices',
          queryParams: {
            'filter[post_dispatch_plan_id][_eq]': planId,
            'fields': '*,invoice_id.*',
          },
        );
        final purchasesRes = await _api.getDirectus(
          '/items/post_dispatch_purchases',
          queryParams: {'filter[post_dispatch_plan_id][_eq]': planId},
        );
        final othersRes = await _api.getDirectus(
          '/items/post_dispatch_plan_others',
          queryParams: {'filter[post_dispatch_plan_id][_eq]': planId},
        );

        final staffList = staffRes.data['data'] as List<dynamic>;
        planJson['crew'] = staffList.map((s) {
          final user = s['user_id'];
          String name = 'Crew Helper';
          if (user is Map<String, dynamic>) {
            final fname =
                user['first_name'] ??
                user['firstName'] ??
                user['user_fname'] ??
                '';
            final lname =
                user['last_name'] ??
                user['lastName'] ??
                user['user_lname'] ??
                '';
            name = '$fname $lname'.trim();
            if (name.isEmpty) {
              name = user['email'] ?? user['user_email'] ?? 'Crew Helper';
            }
          }
          return {
            'user_id': user is Map ? user['id'] : user,
            'role': s['role'] ?? 'helper',
            'name': name,
          };
        }).toList();

        final budgetList = budgetRes.data['data'] as List<dynamic>;
        planJson['budget'] = budgetList
            .map(
              (b) => {
                'id': b['id'],
                'coa_name': b['remarks'] ?? 'Expenses',
                'amount': b['amount'] ?? 0.0,
                'remarks': b['remarks'],
              },
            )
            .toList();

        _activeTrip = PostDispatchPlan.fromJson(planJson);

        final invoicesList = invoicesRes.data['data'] as List<dynamic>;

        final customerCodes = invoicesList
            .map(
              (inv) => inv['invoice_id'] is Map<String, dynamic>
                  ? inv['invoice_id']['customer_code']?.toString()
                  : null,
            )
            .whereType<String>()
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList();

        final Map<String, Map<String, dynamic>> customerMap = {};
        if (customerCodes.isNotEmpty) {
          try {
            final customersRes = await _api.getDirectus(
              '/items/customer',
              queryParams: {
                'filter[customer_code][_in]': customerCodes.join(','),
                'fields':
                    'customer_code,customer_name,latitude,longitude,location',
              },
            );
            final customersDataList =
                customersRes.data['data'] as List<dynamic>;
            for (var cust in customersDataList) {
              if (cust is Map<String, dynamic>) {
                final code = cust['customer_code']?.toString();
                if (code != null) {
                  customerMap[code] = cust;
                }
              }
            }
          } catch (e) {
            debugPrint(
              '[TripProvider] Error fetching active customer coordinates: $e',
            );
          }
        }

        _invoiceStops = invoicesList.map((inv) {
          final isInvoiceMap = inv['invoice_id'] is Map<String, dynamic>;
          final invoiceNo = isInvoiceMap
              ? inv['invoice_id']['invoice_no']
              : null;
          final customerCode = isInvoiceMap
              ? inv['invoice_id']['customer_code']?.toString()
              : null;
          final totalAmount = isInvoiceMap
              ? (inv['invoice_id']['total_amount'] as num?)?.toDouble()
              : null;
          final netAmount = isInvoiceMap
              ? (inv['invoice_id']['net_amount'] as num?)?.toDouble()
              : null;

          final customerData = customerCode != null
              ? customerMap[customerCode]
              : null;
          final customerName =
              customerData?['customer_name']?.toString() ?? customerCode;

          return InvoiceStop(
            id: inv['id'] as int,
            postDispatchPlanId: inv['post_dispatch_plan_id'] as int? ?? 0,
            invoiceId: isInvoiceMap
                ? (inv['invoice_id']['invoice_id'] as int? ?? 0)
                : (inv['invoice_id'] as int? ?? 0),
            invoiceNo: invoiceNo ?? 'INV-#${inv['invoice_id']}',
            customerCode: customerCode,
            customerName: customerName,
            amount: netAmount ?? totalAmount ?? 0.0,
            address: isInvoiceMap
                ? (inv['invoice_id']['shipping_address'] as String? ??
                      'No Address')
                : 'No Address',
            latitude: _coordinateFromCustomer(customerData, 'latitude'),
            longitude: _coordinateFromCustomer(
              customerData,
              'longitude',
              isLatitude: false,
            ),
            distance: (inv['distance'] as num?)?.toDouble() ?? 0.0,
            status: inv['status'] as String? ?? 'Pending',
            sequence: inv['sequence'] as int? ?? 0,
            remarks: inv['remarks'] as String?,
          );
        }).toList();

        final purchasesList = purchasesRes.data['data'] as List<dynamic>;
        _purchaseStops = purchasesList
            .map(
              (p) => PurchaseStop(
                id: p['id'] as int,
                postDispatchPlanId: p['post_dispatch_plan_id'] as int? ?? 0,
                poId: p['po_id'] as int? ?? 0,
                poNo: 'PO-#${p['po_id']}',
                supplierName: 'Supplier',
                distance: (p['distance'] as num?)?.toDouble() ?? 0.0,
                sequence: p['sequence'] as int? ?? 0,
                status: p['status'] as String? ?? 'Pending',
              ),
            )
            .toList();

        final othersList = othersRes.data['data'] as List<dynamic>;
        _otherStops = othersList
            .map(
              (o) => OtherStop(
                id: o['id'] as int,
                postDispatchPlanId: o['post_dispatch_plan_id'] as int? ?? 0,
                remarks: o['remarks'] as String? ?? 'Other Stop',
                distance: (o['distance'] as num?)?.toDouble() ?? 0.0,
                latitude: _parseCoordinate(o['latitude']),
                longitude: _parseCoordinate(o['longitude']),
                sequence: o['sequence'] as int? ?? 0,
                status: o['status'] as String? ?? 'Pending',
              ),
            )
            .toList();

        _tripCache[_activeTrip!.id] = {
          'trip': planJson,
          'invoice_stops': _invoiceStops.map((s) => s.toJson()).toList(),
          'purchase_stops': _purchaseStops.map((s) => s.toJson()).toList(),
          'other_stops': _otherStops.map((s) => s.toJson()).toList(),
        };

        if (_lastNotifiedTripId != _activeTrip!.id) {
          _lastNotifiedTripId = _activeTrip!.id;
          NotificationService().showLocalNotification(
            title: 'Trip Assigned',
            body: '${_activeTrip!.docNo} — ${_activeTrip!.status}',
          );
        }
      }
    } catch (e) {
      debugPrint('[TripProvider] fetchActiveTrip failed: $e');
      _error = 'Failed to load trip data';
      _loadFromCache();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _loadFromCache() {
    if (_activeTrip == null) return;
    final cached = _tripCache[_activeTrip!.id];
    if (cached != null) {
      _activeTrip = PostDispatchPlan.fromJson(
        cached['trip'] as Map<String, dynamic>,
      );
      _invoiceStops =
          (cached['invoice_stops'] as List<dynamic>?)
              ?.map((e) => InvoiceStop.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      _purchaseStops =
          (cached['purchase_stops'] as List<dynamic>?)
              ?.map((e) => PurchaseStop.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      _otherStops =
          (cached['other_stops'] as List<dynamic>?)
              ?.map((e) => OtherStop.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    }
    notifyListeners();
  }

  List<PostDispatchPlan> get allPlans {
    final list = <PostDispatchPlan>[];
    if (_activeTrip != null) {
      list.add(_activeTrip!);
    }
    list.addAll(_pendingPlans);
    list.addAll(_previousDispatchPlans);
    return list;
  }

  List<PostDispatchPlan> get cachedHistory => List.unmodifiable(_cachedHistory);

  Future<void> fetchPendingPlans() async {
    try {
      final profile = await _auth.getProfile();
      if (profile == null) return;

      final response = await _api.getDirectus(
        '/items/post_dispatch_plan',
        queryParams: {
          'filter[driver_id][_eq]': profile.userId,
          'filter[status][_in]': 'For Dispatch,For Inbound',
          'sort': '-id',
          'limit': '20',
          'fields': '*,vehicle_id.*',
        },
      );
      final dataList = response.data['data'] as List<dynamic>;
      final activeId = _activeTrip?.id;
      _pendingPlans = dataList
          .where((e) => e['id'] as int != activeId)
          .map((e) => PostDispatchPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();

      // Proactively cache invoice statuses so the home performance chart
      // includes these plans even if the driver never opens them.
      await _cacheInvoiceStatusesForPlans(
        _pendingPlans.map((p) => p.id).toList(),
      );
    } catch (e) {
      debugPrint('[TripProvider] fetchPendingPlans failed: $e');
    }
  }

  Future<void> fetchPreviousDispatchPlans() async {
    try {
      final profile = await _auth.getProfile();
      if (profile == null) return;

      final response = await _api.getDirectus(
        '/items/post_dispatch_plan',
        queryParams: {
          'filter[driver_id][_eq]': profile.userId,
          'filter[status][_in]': 'For Clearance,Posted',
          'sort': '-date_encoded',
          'limit': '20',
          'fields': '*,vehicle_id.*',
        },
      );
      final dataList = response.data['data'] as List<dynamic>;
      final planIds = dataList.map((e) => e['id'] as int).toList();

      Map<int, List<Map<String, dynamic>>> budgetMap = {};
      if (planIds.isNotEmpty) {
        try {
          final budgetRes = await _api.getDirectus(
            '/items/post_dispatch_budgeting',
            queryParams: {
              'filter[post_dispatch_plan_id][_in]': planIds.join(','),
            },
          );
          final budgetList = budgetRes.data['data'] as List<dynamic>;
          for (final b in budgetList) {
            final pid = b['post_dispatch_plan_id'] as int;
            budgetMap.putIfAbsent(pid, () => []);
            budgetMap[pid]!.add({
              'id': b['id'],
              'coa_name': b['remarks'] ?? 'Expenses',
              'amount': b['amount'] ?? 0.0,
              'remarks': b['remarks'],
            });
          }
        } catch (e) {
          debugPrint(
            '[TripProvider] fetchPreviousDispatchPlans budget fetch failed: $e',
          );
        }
      }

      for (final planJson in dataList) {
        final pid = planJson['id'] as int;
        planJson['budget'] = budgetMap[pid] ?? [];
      }

      _previousDispatchPlans = dataList
          .map((e) => PostDispatchPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();

      // Proactively cache invoice statuses so the home performance chart
      // includes previous dispatch plans even if never opened.
      await _cacheInvoiceStatusesForPlans(planIds);
      notifyListeners();
    } catch (e) {
      debugPrint('[TripProvider] fetchPreviousDispatchPlans failed: $e');
    }
  }

  Future<void> fetchCachedHistory() async {
    try {
      final profile = await _auth.getProfile();
      if (profile == null) return;

      final response = await _api.getDirectus(
        '/items/post_dispatch_plan',
        queryParams: {
          'filter[driver_id][_eq]': profile.userId,
          'filter[status][_in]': 'For Inbound,For Clearance,Posted',
          'sort': '-date_encoded',
          'limit': 20,
        },
      );
      final data = response.data['data'] as List<dynamic>;
      _cachedHistory = data
          .map((e) => PostDispatchPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {
      _cachedHistory = [];
      notifyListeners();
    }
  }

  Future<void> fetchAllCachedData() async {
    await Future.wait([
      fetchActiveTrip(),
      fetchPendingPlans(),
      fetchPreviousDispatchPlans(),
      fetchCachedHistory(),
    ]);
  }

  /// One batched Directus query that populates `_tripCache[planId]
  /// ['invoice_stops']` with lightweight `{id, status}` entries for every
  /// given plan. This lets `aggregatedInvoiceStatusCounts` include plans that
  /// were fetched but never opened via `selectPlan()`.
  Future<void> _cacheInvoiceStatusesForPlans(List<int> planIds) async {
    if (planIds.isEmpty) return;
    try {
      final res = await _api.getDirectus(
        '/items/post_dispatch_invoices',
        queryParams: {
          'filter[post_dispatch_plan_id][_in]': planIds.join(','),
          'fields': 'id,status,post_dispatch_plan_id',
        },
      );
      final list = res.data['data'] as List<dynamic>;
      final byPlan = <int, List<Map<String, dynamic>>>{};
      for (final inv in list) {
        final pid = inv['post_dispatch_plan_id'] as int?;
        if (pid == null) continue;
        byPlan.putIfAbsent(pid, () => []).add({
          'id': inv['id'],
          'status': inv['status'] as String? ?? 'Pending',
        });
      }
      for (final entry in byPlan.entries) {
        final cached = _tripCache[entry.key] ?? <String, dynamic>{};
        cached['invoice_stops'] = entry.value;
        _tripCache[entry.key] = cached;
      }
    } catch (e) {
      debugPrint('[TripProvider] _cacheInvoiceStatusesForPlans failed: $e');
    }
  }

  Future<void> confirmDeparture({
    PostDispatchPlan? plan,
    String? remarks,
  }) async {
    final targetPlan = plan ?? _activeTrip;
    if (targetPlan == null) return;
    _error = null;

    final nowStr = TimezoneService().formatNow();
    final parsedNow = DateTime.parse(nowStr);

    // 1. Optimistic local state update (in-memory only)
    final targetInvoices = targetPlan.id == _activeTrip?.id
        ? _invoiceStops
        : _selectedInvoiceStops;

    final updatedInvoices = targetInvoices.map((s) {
      return InvoiceStop(
        id: s.id,
        postDispatchPlanId: s.postDispatchPlanId,
        invoiceId: s.invoiceId,
        invoiceNo: s.invoiceNo,
        customerCode: s.customerCode,
        customerName: s.customerName,
        amount: s.amount,
        address: s.address,
        latitude: s.latitude,
        longitude: s.longitude,
        distance: s.distance,
        status: 'En Route',
        sequence: s.sequence,
        remarks: s.remarks,
      );
    }).toList();

    final updatedPlan = PostDispatchPlan(
      id: targetPlan.id,
      docNo: targetPlan.docNo,
      driverId: targetPlan.driverId,
      vehicleId: targetPlan.vehicleId,
      status: 'For Inbound',
      startingPoint: targetPlan.startingPoint,
      totalDistance: targetPlan.totalDistance,
      amount: targetPlan.amount,
      estimatedTimeOfDispatch: targetPlan.estimatedTimeOfDispatch,
      estimatedTimeOfArrival: targetPlan.estimatedTimeOfArrival,
      timeOfDispatch: parsedNow,
      timeOfArrival: targetPlan.timeOfArrival,
      dateEncoded: targetPlan.dateEncoded,
      remarks: remarks ?? targetPlan.remarks,
      vehicle: targetPlan.vehicle,
      crew: targetPlan.crew,
      budget: targetPlan.budget,
    );

    if (targetPlan.id == _activeTrip?.id) {
      _activeTrip = updatedPlan;
      _invoiceStops = updatedInvoices;
    } else {
      _selectedPlan = updatedPlan;
      _selectedInvoiceStops = updatedInvoices;
    }

    _tripCache[updatedPlan.id] = {
      'trip': updatedPlan.toJson(),
      'invoice_stops': updatedInvoices.map((s) => s.toJson()).toList(),
      'purchase_stops':
          (targetPlan.id == _activeTrip?.id
                  ? _purchaseStops
                  : _selectedPurchaseStops)
              .map((s) => s.toJson())
              .toList(),
      'other_stops':
          (targetPlan.id == _activeTrip?.id ? _otherStops : _selectedOtherStops)
              .map((s) => s.toJson())
              .toList(),
    };

    // 1.5 Build PhotoQuest from invoice stops
    _currentQuest = PhotoQuest(
      tripId: targetPlan.id,
      items: updatedInvoices
          .map(
            (s) => PhotoQuestItem(
              invoiceStopId: s.id,
              invoiceId: s.invoiceId,
              invoiceNo: s.invoiceNo ?? 'INV-#${s.id}',
              customerName: s.customerName ?? 'Customer',
              amount: s.amount,
              address: s.address,
            ),
          )
          .toList(),
    );

    notifyListeners();

    // 2. Enqueue actions
    final actions = <ActionEntry>[
      ActionEntry(
        actionType: ActionType.confirmDeparture,
        payload: {
          'time_of_dispatch': nowStr,
          'status': 'For Inbound',
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        },
        endpoint: '/items/post_dispatch_plan/${targetPlan.id}',
        httpMethod: 'PATCH',
        priority: ActionPriority.urgent,
      ),
    ];

    final invoiceIds = updatedInvoices.map((s) => s.invoiceId).toList();
    if (invoiceIds.isNotEmpty) {
      actions.add(
        ActionEntry(
          actionType: ActionType.updateInvoicesDeparture,
          payload: {
            'query': {
              'filter': {
                'invoice_id': {'_in': invoiceIds},
              },
            },
            'data': {
              'dispatch_date': nowStr,
              'transaction_status': 'En Route',
              'isDispatched': 1,
            },
          },
          endpoint: '/items/sales_invoice',
          httpMethod: 'PATCH',
          priority: ActionPriority.urgent,
        ),
      );

      final orderNos = updatedInvoices
          .map((s) => s.invoiceNo)
          .whereType<String>()
          .toList();
      if (orderNos.isNotEmpty) {
        actions.add(
          ActionEntry(
            actionType: ActionType.updateOrdersDeparture,
            payload: {
              'query': {
                'filter': {
                  'order_no': {'_in': orderNos},
                },
              },
              'data': {'order_status': 'En Route'},
            },
            endpoint: '/items/sales_order',
            httpMethod: 'PATCH',
            priority: ActionPriority.urgent,
          ),
        );
      }
    }

    await _queue.enqueueBatch(actions);
  }

  Future<void> markArrivedAtBase({
    PostDispatchPlan? plan,
    String? remarks,
  }) async {
    final targetPlan = plan ?? _activeTrip;
    if (targetPlan == null) return;
    _error = null;

    final targetInvoices = targetPlan.id == _activeTrip?.id
        ? _invoiceStops
        : _selectedInvoiceStops;
    final areTerminal =
        targetInvoices.isNotEmpty && targetInvoices.every((s) => s.isTerminal);
    if (!areTerminal) {
      final pending = targetInvoices
          .where((s) => !s.isTerminal)
          .map((s) => s.invoiceNo ?? '#${s.id}')
          .join(', ');
      _error = 'Cannot mark arrived: pending stops: $pending';
      notifyListeners();
      return;
    }

    // Confirm gate: driver must explicitly confirm invoices
    if (!_invoicesConfirmed) {
      _error = 'Please confirm invoices first before marking arrived.';
      notifyListeners();
      return;
    }

    // Quest gate: all invoice photos must be captured
    if (_currentQuest != null &&
        _currentQuest!.photosCaptured < _currentQuest!.totalCount) {
      final pending = _currentQuest!.pendingItems
          .where((i) => !i.photoCaptured)
          .map((i) => i.invoiceNo)
          .join(', ');
      _error = 'Complete photo quest first. Pending: $pending';
      notifyListeners();
      return;
    }

    final nowStr = TimezoneService().formatNow();
    final parsedNow = DateTime.parse(nowStr);

    // 1. Optimistic local state update
    final updatedTrip = PostDispatchPlan(
      id: targetPlan.id,
      docNo: targetPlan.docNo,
      driverId: targetPlan.driverId,
      vehicleId: targetPlan.vehicleId,
      status: 'For Clearance',
      startingPoint: targetPlan.startingPoint,
      totalDistance: targetPlan.totalDistance,
      amount: targetPlan.amount,
      estimatedTimeOfDispatch: targetPlan.estimatedTimeOfDispatch,
      estimatedTimeOfArrival: targetPlan.estimatedTimeOfArrival,
      timeOfDispatch: targetPlan.timeOfDispatch,
      timeOfArrival: parsedNow,
      dateEncoded: targetPlan.dateEncoded,
      remarks: targetPlan.remarks,
      vehicle: targetPlan.vehicle,
      crew: targetPlan.crew,
      budget: targetPlan.budget,
    );

    if (targetPlan.id == _activeTrip?.id) {
      _activeTrip = updatedTrip;
    } else {
      _selectedPlan = updatedTrip;
    }

    _tripCache[updatedTrip.id] = {
      'trip': updatedTrip.toJson(),
      'invoice_stops': targetInvoices.map((s) => s.toJson()).toList(),
      'purchase_stops':
          (targetPlan.id == _activeTrip?.id
                  ? _purchaseStops
                  : _selectedPurchaseStops)
              .map((s) => s.toJson())
              .toList(),
      'other_stops':
          (targetPlan.id == _activeTrip?.id ? _otherStops : _selectedOtherStops)
              .map((s) => s.toJson())
              .toList(),
    };

    notifyListeners();

    // 2. Enqueue action
    await _queue.enqueue(
      ActionEntry(
        actionType: ActionType.markArrived,
        payload: {
          'status': 'For Clearance',
          'time_of_arrival': nowStr,
          'remarks_arrival': remarks ?? '',
        },
        endpoint: '/items/post_dispatch_plan/${targetPlan.id}',
        httpMethod: 'PATCH',
        priority: ActionPriority.urgent,
      ),
    );
  }

  void markQuestPhotoCaptured(int invoiceStopId, String localPath) {
    if (_currentQuest == null) return;
    for (final item in _currentQuest!.items) {
      if (item.invoiceStopId == invoiceStopId) {
        item.photoCaptured = true;
        item.localPhotoPath = localPath;
        notifyListeners();
        return;
      }
    }
  }

  void markQuestStatusComplete(int invoiceStopId, String status) {
    if (_currentQuest == null) return;
    for (final item in _currentQuest!.items) {
      if (item.invoiceStopId == invoiceStopId) {
        item.stopStatus = status;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> updateStopStatus(
    int invoiceId,
    String status, {
    String? remarks,
  }) async {
    const allowedStatuses = {
      'Fulfilled',
      'Not Fulfilled',
      'Fulfilled with Returns',
      'Fulfilled with Concerns',
    };
    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('Invalid stop status mapping: $status');
    }
    _error = null;

    // 1. Optimistic local state update
    int idx = _invoiceStops.indexWhere((s) => s.id == invoiceId);
    bool isSelected = false;
    if (idx == -1) {
      idx = _selectedInvoiceStops.indexWhere((s) => s.id == invoiceId);
      isSelected = true;
    }

    if (idx != -1) {
      final list = isSelected ? _selectedInvoiceStops : _invoiceStops;
      final targetStop = list[idx];
      final updatedStop = InvoiceStop(
        id: targetStop.id,
        postDispatchPlanId: targetStop.postDispatchPlanId,
        invoiceId: targetStop.invoiceId,
        invoiceNo: targetStop.invoiceNo,
        customerCode: targetStop.customerCode,
        customerName: targetStop.customerName,
        amount: targetStop.amount,
        address: targetStop.address,
        latitude: targetStop.latitude,
        longitude: targetStop.longitude,
        distance: targetStop.distance,
        status: status,
        sequence: targetStop.sequence,
        remarks: remarks ?? targetStop.remarks,
      );

      if (isSelected) {
        _selectedInvoiceStops[idx] = updatedStop;
      } else {
        _invoiceStops[idx] = updatedStop;
      }

      final planId = targetStop.postDispatchPlanId;
      final cached = _tripCache[planId];
      if (cached != null) {
        final invStopsList = cached['invoice_stops'] as List<dynamic>? ?? [];
        final cIdx = invStopsList.indexWhere((s) => s['id'] == invoiceId);
        if (cIdx != -1) {
          invStopsList[cIdx]['status'] = status;
          if (remarks != null) {
            invStopsList[cIdx]['remarks'] = remarks;
          }
        }
      }

      notifyListeners();
    }

    // Keep the Photo Quest in sync with the actual invoice status, regardless
    // of whether the status was set from the stop detail or the quest screen.
    markQuestStatusComplete(invoiceId, status);

    // 2. Enqueue action
    final profile = await _auth.getProfile();
    final driverUserId = profile?.userId;
    if (driverUserId == null) {
      throw ArgumentError('Driver user ID is null. Please log in again.');
    }

    await _queue.enqueue(
      ActionEntry(
        actionType: ActionType.updateStopStatus,
        payload: {'status': status, 'remarks': remarks},
        endpoint: '/items/post_dispatch_invoices/$invoiceId',
        httpMethod: 'PATCH',
        priority: ActionPriority.urgent,
      ),
    );
  }

  Future<void> updateOtherStopStatus(
    int stopId,
    String status, {
    String? remarks,
  }) async {
    const allowedStatuses = {'Fulfilled', 'Not Fulfilled', 'Pending'};
    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('Invalid stop status mapping: $status');
    }
    _error = null;

    // 1. Optimistic local state update
    int idx = _otherStops.indexWhere((s) => s.id == stopId);
    bool isSelected = false;
    if (idx == -1) {
      idx = _selectedOtherStops.indexWhere((s) => s.id == stopId);
      isSelected = true;
    }

    if (idx != -1) {
      final list = isSelected ? _selectedOtherStops : _otherStops;
      final targetStop = list[idx];
      final updatedStop = OtherStop(
        id: targetStop.id,
        postDispatchPlanId: targetStop.postDispatchPlanId,
        remarks: remarks ?? targetStop.remarks,
        distance: targetStop.distance,
        latitude: targetStop.latitude,
        longitude: targetStop.longitude,
        sequence: targetStop.sequence,
        status: status,
      );

      if (isSelected) {
        _selectedOtherStops[idx] = updatedStop;
      } else {
        _otherStops[idx] = updatedStop;
      }

      final planId = targetStop.postDispatchPlanId;
      final cached = _tripCache[planId];
      if (cached != null) {
        final otherStopsList = cached['other_stops'] as List<dynamic>? ?? [];
        final cIdx = otherStopsList.indexWhere((s) => s['id'] == stopId);
        if (cIdx != -1) {
          otherStopsList[cIdx]['status'] = status;
          if (remarks != null) {
            otherStopsList[cIdx]['remarks'] = remarks;
          }
        }
      }

      notifyListeners();
    }

    // 2. Enqueue action
    await _queue.enqueue(
      ActionEntry(
        actionType: ActionType.updateStopStatus,
        payload: {'status': status, 'remarks': remarks},
        endpoint: '/items/post_dispatch_plan_others/$stopId',
        httpMethod: 'PATCH',
        priority: ActionPriority.urgent,
      ),
    );
  }
}
