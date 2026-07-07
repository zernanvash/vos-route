import '../models/emergency_report.dart';
import '../models/action_entry.dart';
import 'action_queue_service.dart';

class EmergencyService {
  final ActionQueueService _queue = ActionQueueService();

  Future<void> submitReport(EmergencyReport report) async {
    await _queue.enqueue(
      ActionEntry(
        actionType: ActionType.submitSos,
        payload: report.toApiPayload(),
        endpoint: '/items/fleet_emergency_reports',
        httpMethod: 'POST',
        priority: ActionPriority.urgent,
      ),
    );
  }
}
