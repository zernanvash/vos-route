import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/photo_quest.dart';
import '../models/action_entry.dart';
import '../providers/trip_provider.dart';
import '../services/action_queue_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';
import '../core/app_card.dart';
import '../core/app_action_button.dart';

enum _QuestMode { list, capturing, preview, status, complete }

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  _QuestMode _mode = _QuestMode.list;
  final ActionQueueService _queue = ActionQueueService();
  final ImagePicker _picker = ImagePicker();

  XFile? _capturedImage;
  bool _isUploading = false;

  PhotoQuest? get _quest => context.read<TripProvider>().currentQuest;
  PhotoQuestItem? _currentItem;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Consumer<TripProvider>(
        builder: (context, trip, _) {
          final quest = trip.currentQuest;
          if (quest == null || quest.items.isEmpty) {
            return Center(
              child: Text(
                'No photo quest available',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            );
          }

          switch (_mode) {
            case _QuestMode.list:
              return _buildQuestList(quest);
            case _QuestMode.preview:
              return _buildPreview();
            case _QuestMode.status:
              return _buildStatusSection();
            case _QuestMode.complete:
              return _buildComplete();
            case _QuestMode.capturing:
              return _buildCapturing();
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final quest = _quest;
    return AppBar(
      title: Text(
        _mode == _QuestMode.complete ? 'Quest Complete!' : 'Photo Quest',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: AppColors.surface,
      iconTheme: const IconThemeData(color: Colors.white),
      bottom: quest != null && _mode != _QuestMode.complete
          ? PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: quest.progress,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.success,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildQuestList(PhotoQuest quest) {
    return Column(
      children: [
        Padding(
          padding: Insets.cardLg,
          child: AppCard(
            color: AppColors.primaryDark.withValues(alpha: 0.3),
            child: Row(
              children: [
                Icon(Icons.camera_alt, color: AppColors.info, size: 28),
                Insets.gapWMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quest.progressLabel, style: AppTextStyle.subheading),
                      Insets.gapXs,
                      Text(
                        '${quest.photosCaptured} photos captured',
                        style: AppTextStyle.caption,
                      ),
                    ],
                  ),
                ),
                if (!quest.allComplete)
                  AppActionButton(
                    onPressed: () => _startNextItem(quest),
                    label: quest.photosCaptured > 0 ? 'Continue' : 'Start',
                    backgroundColor: AppColors.successDark,
                    icon: Icons.play_arrow,
                    expanded: false,
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            itemCount: quest.items.length,
            itemBuilder: (_, i) => _buildQuestItemCard(quest.items[i], i),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestItemCard(PhotoQuestItem item, int index) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    if (item.isComplete) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
      statusLabel = 'Complete';
    } else if (item.photoCaptured) {
      statusColor = Colors.orange;
      statusIcon = Icons.edit;
      statusLabel = 'Needs status';
    } else {
      statusColor = AppColors.textTertiary;
      statusIcon = Icons.pending;
      statusLabel = 'Pending';
    }

    return AppCard(
      padding: Insets.cardInner,
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.isComplete
                  ? AppColors.successDark
                  : AppColors.primaryDark,
              borderRadius: BorderRadius.circular(Insets.smallRadius),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Insets.gapWMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.invoiceNo, style: AppTextStyle.subheading),
                Text(item.customerName, style: AppTextStyle.caption),
                Insets.gapXs,
                Row(
                  children: [
                    _questChip('📷', item.photoCaptured),
                    Insets.gapWSm,
                    _questChip(
                      '✅',
                      item.stopStatus != null &&
                          item.stopStatus != 'Pending' &&
                          item.stopStatus != 'En Route',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: Insets.xs,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(Insets.badgeRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: Insets.xs),
                Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questChip(String emoji, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xs + 2,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: done ? AppColors.successDark : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$emoji ${done ? 'Done' : '...'}',
        style: TextStyle(
          color: done ? AppColors.success : AppColors.textTertiary,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildCapturing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue),
          SizedBox(height: Insets.lg),
          Text('Opening camera...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_capturedImage == null) {
      return Center(
        child: Text(
          'No image',
          style: TextStyle(color: AppColors.textTertiary),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: Insets.cardLg,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Insets.cardRadius),
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
        ),
        Padding(
          padding: Insets.cardLg,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: Insets.buttonHeight,
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _retakePhoto,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              Insets.gapWLg,
              Expanded(
                child: SizedBox(
                  height: Insets.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _acceptPhoto,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successDark,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    if (_currentItem == null) {
      return Center(
        child: Text('No item', style: TextStyle(color: AppColors.textTertiary)),
      );
    }

    const statuses = [
      'Fulfilled',
      'Not Fulfilled',
      'Fulfilled with Returns',
      'Fulfilled with Concerns',
    ];

    return Padding(
      padding: Insets.cardLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status for ${_currentItem!.invoiceNo}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Insets.gapXs,
          Text(_currentItem!.customerName, style: AppTextStyle.caption),
          Insets.gapLg,
          ...statuses.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: SizedBox(
                width: double.infinity,
                height: Insets.buttonHeight,
                child: OutlinedButton(
                  onPressed: () => _acceptStatus(s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Text(s),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplete() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration, size: 80, color: AppColors.success),
          const SizedBox(height: Insets.xxl),
          const Text(
            'All invoices complete!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'You can now mark arrived at base.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: Insets.xxxl),
          AppActionButton(
            onPressed: () => Navigator.pop(context),
            label: 'Done',
            icon: Icons.check,
            backgroundColor: AppColors.successDark,
            expanded: false,
          ),
        ],
      ),
    );
  }

  void _startNextItem(PhotoQuest quest) {
    final next = quest.nextPending;
    if (next == null) {
      setState(() => _mode = _QuestMode.complete);
      return;
    }

    _currentItem = next;
    _capturedImage = null;
    setState(() => _mode = _QuestMode.capturing);
    _capturePhoto();
  }

  Future<void> _capturePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file != null) {
        setState(() {
          _capturedImage = file;
          _mode = _QuestMode.preview;
        });
      } else {
        setState(() => _mode = _QuestMode.list);
      }
    } catch (_) {
      setState(() => _mode = _QuestMode.list);
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _mode = _QuestMode.capturing;
    });
    _capturePhoto();
  }

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

  Future<void> _acceptPhoto() async {
    if (_capturedImage == null || _currentItem == null) return;

    setState(() => _isUploading = true);

    try {
      final persistentPath =
          await _saveToPersistentDirectory(_capturedImage!.path);

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

      if (mounted) {
        context.read<TripProvider>().markQuestPhotoCaptured(
          _currentItem!.invoiceStopId,
          persistentPath,
        );
        setState(() {
          _isUploading = false;
          _mode = _QuestMode.status;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _acceptStatus(String status) {
    if (_currentItem == null) return;

    context.read<TripProvider>().markQuestStatusComplete(
      _currentItem!.invoiceStopId,
      status,
    );

    context.read<TripProvider>().updateStopStatus(
      _currentItem!.invoiceStopId,
      status,
    );

    final quest = context.read<TripProvider>().currentQuest;
    if (quest != null) {
      _startNextItem(quest);
    }
  }
}
