# VOSRoute Implementation Plan — Offline Photos, Signature Removal & GPS Fixes

This document outlines the detailed specifications and file changes required to implement offline-first photo uploads, remove customer signatures, aggregate driver performance metrics, and fix location tracking in the VOSRoute Flutter application.

---

## 1. Goal Overview
1. **Offline-First Photo Uploads:** Avoid uploading photos directly from screens. Instead, save photos locally in a persistent directory, enqueue the link/upload actions in the `action_queue` SQLite table, and let the background queue runner upload files sequentially and update relations when connection is restored.
2. **Remove Customer Signature:** Completely remove the signature pad sections, signature state properties, and signature validation checks from all stops and quest flows.
3. **Aggregated Performance Pie Chart:** Update the Home Screen performance card to display the status categories of all invoices/stops across **all** dispatch plans (Active, Pending, and Previous/Past plans) assigned to the driver.
4. **GPS Location Tracking Fix:** Fix background location tracking by properly communicating the active trip ID to the background service isolate, and request coarse/fine location permissions dynamically at runtime.
5. **Fix Directus `invoiceAt` Validation Error:** Correct the validation error (`Field "invoiceAt" contains null values`) by formatting datetime payloads as standard UTC ISO 8601 strings, and send both `invoiceAt` and `invoice_at` properties in the PATCH requests.

---

## 2. File-by-File Technical Specifications

### 2.1. GPS Tracking & Permissions Setup

#### File: `android/app/src/main/AndroidManifest.xml`
Add the following location permissions directly inside the `<manifest>` tag to allow geolocation access:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

#### File: `lib/providers/gps_provider.dart`
Modify the `startTracking` method to dynamically prompt the user for geolocator permissions if they haven't been granted yet:
```dart
  Future<void> startTracking(int tripId) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _gpsService.startTracking(tripId);
    _isTracking = true;
    notifyListeners();
  }
```

#### File: `lib/services/background_service.dart`
Fix the isolate memory space bug by passing the active trip ID to the background isolate using the background service's message channel:
```dart
  void startTracking(int tripId) {
    _activeTripId = tripId;
    _service.invoke('setActiveTrip', tripId); // Send to background isolate
    _updateNotification();
  }
```

---

### 2.2. Offline-First Photo Queue Processing

#### File: `lib/services/action_queue_service.dart`
Enhance the background worker `_execute(ActionEntry entry)` to detect local files in payloads, upload them first, swap the path with the server UUID, and perform a duplicate check before linking:
```dart
  Future<void> _execute(ActionEntry entry) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'action_queue',
      {'status': 'in_flight', 'last_attempt': now},
      where: 'id = ?',
      whereArgs: [entry.id],
    );

    try {
      var payload = Map<String, dynamic>.from(entry.payload);

      // Check if the payload contains a local file path that needs uploading first
      if (payload.containsKey('local_file_path')) {
        final localFilePath = payload['local_file_path'] as String;
        final uploadService = UploadService();
        
        // Use specific Directus folder UUIDs:
        // - linkPodPhoto (POD / Invoice photos) -> d3940009-05ec-4fbd-ae2b-72f581013805
        // - linkTripPhoto (Trip outbound/inbound photos) -> 13954431-1352-421b-8bcd-d41963b3d9bd
        String? folderUuid;
        if (entry.actionType == ActionType.linkPodPhoto) {
          folderUuid = 'd3940009-05ec-4fbd-ae2b-72f581013805';
        } else if (entry.actionType == ActionType.linkTripPhoto) {
          folderUuid = '13954431-1352-421b-8bcd-d41963b3d9bd';
        }

        final directusFileId = await uploadService.uploadFile(localFilePath, folderUuid: folderUuid);
        if (directusFileId == null) {
          throw Exception('Failed to upload local file: $localFilePath');
        }

        // Swap the local file path with the successfully uploaded Directus UUID
        payload.remove('local_file_path');
        payload['file'] = directusFileId;

        // Persist the updated payload in SQLite so we don't re-upload on next retries
        await db.update(
          'action_queue',
          {'action_payload': jsonEncode(payload)},
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }

      // Check for duplicate links to enforce schema-independent idempotency
      bool alreadyLinked = false;
      if (entry.actionType == ActionType.linkPodPhoto) {
        final invoiceId = payload['post_dispatch_invoice_id'];
        final fileId = payload['file'];
        final res = await _api.getDirectus(
          '/items/post_dispatch_nte',
          queryParams: {
            'filter[post_dispatch_invoice_id][_eq]': invoiceId,
            'filter[file][_eq]': fileId,
          },
        );
        if ((res.data['data'] as List).isNotEmpty) {
          alreadyLinked = true;
        }
      } else if (entry.actionType == ActionType.linkTripPhoto) {
        final planId = payload['post_dispatch_plan_id'];
        final fileId = payload['file'];
        final res = await _api.getDirectus(
          '/items/post_dispatch_trip_photos',
          queryParams: {
            'filter[post_dispatch_plan_id][_eq]': planId,
            'filter[file][_eq]': fileId,
          },
        );
        if ((res.data['data'] as List).isNotEmpty) {
          alreadyLinked = true;
        }
      }

      if (!alreadyLinked) {
        switch (entry.httpMethod.toUpperCase()) {
          case 'POST':
            await _api.postDirectus(entry.endpoint, data: payload);
            break;
          case 'PATCH':
            await _api.patchDirectus(entry.endpoint, data: payload);
            break;
          case 'PUT':
            await _api.put(entry.endpoint, data: payload);
            break;
        }
      }

      await db.update(
        'action_queue',
        {'status': 'completed', 'last_attempt': now},
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    } catch (e) {
      // Standard backoff retry or fail after max attempts
      ...
    }
  }
```

---

### 2.3. Removing Signature Requirements & Caching Photo Paths

To save the files securely for offline-first uploads, we should copy images from the `image_picker` temporary directory to a persistent documents folder.

#### Helper Method: Save Persistent Photo File
Add this logic when capturing photos in screens:
```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> _saveToPersistentDirectory(String tempPath) async {
  final appDir = await getApplicationDocumentsDirectory();
  final photosDir = Directory(p.join(appDir.path, 'photos'));
  if (!await photosDir.exists()) {
    await photosDir.create(recursive: true);
  }
  final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final newPath = p.join(photosDir.path, fileName);
  await File(tempPath).copy(newPath);
  return newPath;
}
```

#### File: `lib/screens/quest_screen.dart`
* Remove the signature drawer screen state (`_QuestMode.signing`) and related methods (`_buildSignatureSection`, `_acceptSignature`).
* Update `_acceptPhoto` to copy the captured image to the persistent documents directory and immediately enqueue the link action with the local path:
  ```dart
  Future<void> _acceptPhoto() async {
    if (_capturedImage == null || _currentItem == null) return;
    
    // Save photo persistently on-device
    final persistentPath = await _saveToPersistentDirectory(_capturedImage!.path);
    
    // Immediately enqueue without blocking on network upload
    await _queue.enqueue(
      ActionEntry(
        actionType: ActionType.linkPodPhoto,
        payload: {
          'post_dispatch_invoice_id': _currentItem!.invoiceStopId,
          'local_file_path': persistentPath,
          'doc_no': _currentItem!.invoiceNo,
        },
        endpoint: '/items/post_dispatch_nte',
        httpMethod: 'POST',
        priority: ActionPriority.normal,
      ),
    );

    context.read<TripProvider>().markQuestPhotoCaptured(
      _currentItem!.invoiceStopId,
      persistentPath,
      'pending_sync',
    );

    // Directly progress to status selection state
    setState(() {
      _mode = _QuestMode.status;
    });
  }
  ```

#### File: `lib/screens/stop_detail_screen.dart`
* Remove `_signatureSection()`, signature variables (`_signatureBytes`, `_signatureConfirmed`), and the validation checking that signatures are captured before status updates.
* Change `_capturePhoto` to persist the path:
  ```dart
  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file != null) {
      final persistentPath = await _saveToPersistentDirectory(file.path);
      setState(() => _localPhotoPath = persistentPath);
    }
  }
  ```
* Rework status updates (`_updateStatus`) to immediately enqueue actions with `local_file_path` without requiring or uploading signature bytes:
  ```dart
  Future<void> _updateStatus(String status) async {
    if (_invoiceStop == null) return;

    final tripProvider = context.read<TripProvider>();
    
    if (_localPhotoPath != null) {
      await _queue.enqueue(
        ActionEntry(
          actionType: ActionType.linkPodPhoto,
          payload: {
            'post_dispatch_invoice_id': _invoiceStop!.id,
            'local_file_path': _localPhotoPath!,
            'doc_no': _invoiceStop!.invoiceNo,
          },
          endpoint: '/items/post_dispatch_nte',
          httpMethod: 'POST',
          priority: ActionPriority.normal,
        ),
      );
    }

    await tripProvider.updateStopStatus(_invoiceStop!.id, status);
    if (mounted) Navigator.pop(context);
  }
  ```

#### File: `lib/screens/trip_photos_screen.dart`
* Persist captured image paths locally and immediately enqueue `ActionType.linkTripPhoto` containing `local_file_path`:
  ```dart
  Future<void> _capturePhoto() async {
    final trip = context.read<TripProvider>().activeTrip;
    if (trip == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return;

    final persistentPath = await _saveToPersistentDirectory(file.path);
    final isOutbound = trip.timeOfDispatch == null;

    setState(() {
      if (isOutbound) {
        _outboundPhotos.add(persistentPath);
      } else {
        _inboundPhotos.add(persistentPath);
      }
    });

    await _queue.enqueue(
      ActionEntry(
        actionType: ActionType.linkTripPhoto,
        payload: {
          'post_dispatch_plan_id': trip.id,
          'local_file_path': persistentPath,
          'type': isOutbound ? 'outbound' : 'inbound',
        },
        endpoint: '/items/post_dispatch_trip_photos',
        httpMethod: 'POST',
        priority: ActionPriority.normal,
      ),
    );
  }
  ```

---

### 2.4. Fixing `invoiceAt` & Aggregating Stop Status Counts

#### File: `lib/providers/trip_provider.dart`
* Fix `invoiceAt` by using a UTC timestamp format and posting both keys:
  ```dart
    // In updateStopStatus method
    await _queue.enqueue(
      ActionEntry(
        actionType: ActionType.updateStopStatus,
        payload: {
          'status': status,
          'invoiceAt': DateTime.now().toUtc().toIso8601String(),
          'invoice_at': DateTime.now().toUtc().toIso8601String(),
          'remarks': remarks,
        },
        endpoint: '/items/post_dispatch_invoices/$invoiceId',
        httpMethod: 'PATCH',
        priority: ActionPriority.urgent,
      ),
    );
  ```

* To support aggregating performance statistics across all plans, fetch stops data when fetching pending/past dispatch plans.
* Define a getter `allInvoiceStops` that aggregates the active trip stops, pending trip stops, and previous trip stops:
  ```dart
  List<InvoiceStop> get allInvoiceStops {
    final stops = <InvoiceStop>[];
    stops.addAll(_invoiceStops);
    // Add other plan stops if cached, or parse from Directus-loaded plans
    return stops;
  }

  Map<String, int> get aggregatedInvoiceStatusCounts {
    final counts = <String, int>{
      'Fulfilled': 0,
      'Not Fulfilled': 0,
      'Fulfilled with Returns': 0,
      'Fulfilled with Concerns': 0,
      'Pending': 0,
    };
    for (final s in allInvoiceStops) {
      if (counts.containsKey(s.status)) {
        counts[s.status] = counts[s.status]! + 1;
      } else {
        counts['Pending'] = counts['Pending']! + 1;
      }
    }
    return counts;
  }
  ```

#### File: `lib/screens/home_screen.dart`
* Update the performance pie chart data calculations to use the new aggregated status counts instead of the active-trip-only status counts:
  ```dart
  // In _HomeScreenState build or performance rendering section
  final counts = trip.aggregatedInvoiceStatusCounts;
  ```

#### File: `lib/services/upload_service.dart`
* Update the `uploadFile` method to support passing an optional `folderUuid` parameter:
  ```dart
  Future<String?> uploadFile(String filePath, {String? folderUuid}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        if (folderUuid != null) 'folder': folderUuid,
      });

      final response = await _dio.post(
        '/files',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer ${AppConfig.directusStaticToken}'},
        ),
      );

      return response.data['data']['id'] as String?;
    } catch (_) {
      return null;
    }
  }
  ```

