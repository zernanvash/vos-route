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

enum _QuestMode { list, capturing, preview, complete }

class QuestScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const QuestScreen({super.key, this.onComplete});

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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _buildAppBar(cs),
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
            case _QuestMode.complete:
              return _buildComplete();
            case _QuestMode.capturing:
              return _buildCapturing();
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    final quest = _quest;
    return AppBar(
      title: Text(
        'Invoice Photos',
        style: TextStyle(color: cs.onSurface),
      ),
      backgroundColor: cs.surface,
      iconTheme: IconThemeData(color: cs.onSurface),
      bottom: quest != null && _mode != _QuestMode.complete
          ? PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: quest.progress,
                backgroundColor: cs.surfaceContainerHighest,
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

    if (item.isComplete || item.photoCaptured) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
      statusLabel = 'Complete';
    } else {
      statusColor = AppColors.textTertiary;
      statusIcon = Icons.pending;
      statusLabel = 'Pending';
    }

    return GestureDetector(
      onTap: () => _onItemTap(item),
      child: AppCard(
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
                    _questChip('📷', item.photoCaptured),
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

  Widget _buildComplete() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration, size: 80, color: AppColors.success),
          const SizedBox(height: Insets.xxl),
          const Text(
            'All invoice photos captured!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'You can now update statuses from the invoice list.',
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
      // All items complete — fire onComplete if provided, else show complete screen
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        setState(() => _mode = _QuestMode.complete);
      }
      return;
    }

    _currentItem = next;
    _capturedImage = null;

    // If the item already has a photo, skip to next item
    if (next.photoCaptured) {
      _startNextItem(quest);
      return;
    }

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

  void _onItemTap(PhotoQuestItem item) {
    if (item.isComplete) return;
    _currentItem = item;
    _capturedImage = null;
    if (!item.photoCaptured) {
      setState(() => _mode = _QuestMode.capturing);
      _capturePhoto();
    }
  }

  Future<void> _acceptPhoto() async {
    if (_capturedImage == null || _currentItem == null) return;

    setState(() => _isUploading = true);

    try {
      final persistentPath =
          await _saveToPersistentDirectory(_capturedImage!.path);

      await _queue.enqueue(
        ActionEntry(
          actionType: ActionType.linkTripPhoto,
          payload: {
            'trip_id': context.read<TripProvider>().activeTrip?.id,
            'local_file_path': persistentPath,
            'type': 'invoice',
          },
          endpoint: '/items/post_dispatch_trip_photos',
          httpMethod: 'POST',
          priority: ActionPriority.normal,
        ),
      );

      if (mounted) {
        context.read<TripProvider>().markQuestPhotoCaptured(
          _currentItem!.invoiceStopId,
          persistentPath,
        );
        setState(() => _isUploading = false);
        final quest = context.read<TripProvider>().currentQuest;
        if (quest != null) {
          _startNextItem(quest);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

}
