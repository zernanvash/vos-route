import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/action_queue_service.dart';
import '../models/action_entry.dart';

class ActionQueueProvider extends ChangeNotifier {
  final ActionQueueService _queueService = ActionQueueService();
  Timer? _statusTimer;
  int _pendingCount = 0;
  int _failedCount = 0;

  int get pendingCount => _pendingCount;
  int get failedCount => _failedCount;
  ActionQueueService get service => _queueService;

  void init() {
    _queueService.start();
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshStatus();
    });
    _refreshStatus();
  }

  @override
  void dispose() {
    _queueService.stop();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    _pendingCount = await _queueService.getPendingCount();
    _failedCount = await _queueService.getFailedCount();
    notifyListeners();
  }

  Future<void> processNow() async {
    await _queueService.processQueue();
    await _refreshStatus();
  }

  Future<List<ActionEntry>> getActions() async {
    return await _queueService.getPendingActions();
  }

  Future<void> retryFailed() async {
    await _queueService.retryFailed();
    await _refreshStatus();
  }

  Future<void> retryAction(int id) async {
    await _queueService.retryAction(id);
    await _refreshStatus();
  }

  Future<void> clearCompleted() async {
    await _queueService.clearCompleted();
    await _refreshStatus();
  }

  Future<void> clearFailed() async {
    await _queueService.clearFailed();
    await _refreshStatus();
  }
}
