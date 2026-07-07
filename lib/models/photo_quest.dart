class PhotoQuestItem {
  final int invoiceStopId;
  final int invoiceId;
  final String invoiceNo;
  final String customerName;
  final double? amount;
  final String? address;

  bool photoCaptured;
  String? localPhotoPath;
  String? directusFileUuid;
  bool signatureCaptured;
  String? stopStatus;

  PhotoQuestItem({
    required this.invoiceStopId,
    required this.invoiceId,
    required this.invoiceNo,
    required this.customerName,
    this.amount,
    this.address,
    this.photoCaptured = false,
    this.localPhotoPath,
    this.directusFileUuid,
    this.signatureCaptured = false,
    this.stopStatus,
  });

  bool get isComplete =>
      photoCaptured &&
      signatureCaptured &&
      stopStatus != null &&
      stopStatus != 'Pending' &&
      stopStatus != 'En Route';

  bool get needsPhoto => !photoCaptured;
  bool get needsSignature => photoCaptured && !signatureCaptured;
  bool get needsStatus =>
      photoCaptured &&
      signatureCaptured &&
      (stopStatus == null ||
          stopStatus == 'Pending' ||
          stopStatus == 'En Route');
}

class PhotoQuest {
  final int tripId;
  final List<PhotoQuestItem> items;

  PhotoQuest({required this.tripId, required this.items});

  int get totalCount => items.length;
  int get completedCount => items.where((i) => i.isComplete).length;
  int get photosCaptured => items.where((i) => i.photoCaptured).length;
  int get signaturesCaptured => items.where((i) => i.signatureCaptured).length;

  bool get allComplete => items.every((i) => i.isComplete);

  PhotoQuestItem? get nextPending {
    for (final item in items) {
      if (!item.isComplete) return item;
    }
    return null;
  }

  List<PhotoQuestItem> get pendingItems =>
      items.where((i) => !i.isComplete).toList();

  String get progressLabel => '$completedCount / $totalCount complete';
  double get progress => totalCount > 0 ? completedCount / totalCount : 0.0;
}
