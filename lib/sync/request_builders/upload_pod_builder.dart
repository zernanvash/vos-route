class UploadPodBuilder {
  static Map<String, dynamic> build({
    required int invoiceId,
    required String directusFileUuid,
    required String docNo,
  }) {
    return {
      'path': '/items/post_dispatch_nte',
      'method': 'POST',
      'body': {
        'post_dispatch_invoice_id': invoiceId,
        'file': directusFileUuid,
        'doc_no': docNo,
      },
    };
  }
}
