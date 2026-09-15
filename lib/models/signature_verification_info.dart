class DigitalSignatureInfo {
  final String fieldName;
  final String? signerName;
  final DateTime? signingDate;
  final String? reason;
  final String? location;
  final String? contactInfo;
  final String digestAlgorithm;
  final String cryptoStandard;
  final bool isValid;
  final String statusDescription;
  final int pageIndex;
  final double normalizedX;
  final double normalizedY;
  final double? rectX;
  final double? rectY;
  final double? rectWidth;
  final double? rectHeight;

  final String? sha256Digest;
  final String? byteRangeInfo;

  DigitalSignatureInfo({
    required this.fieldName,
    this.signerName,
    this.signingDate,
    this.reason,
    this.location,
    this.contactInfo,
    this.digestAlgorithm = 'SHA-256',
    this.cryptoStandard = 'CMS / PKCS#7 (Adobe PAdES)',
    this.isValid = true,
    required this.statusDescription,
    this.pageIndex = 0,
    this.normalizedX = 0.55,
    this.normalizedY = 0.78,
    this.rectX,
    this.rectY,
    this.rectWidth,
    this.rectHeight,
    this.sha256Digest,
    this.byteRangeInfo,
  });
}

class PdfSignatureReport {
  final String fileName;
  final bool hasDigitalSignatures;
  final List<DigitalSignatureInfo> signatures;
  final String summary;

  PdfSignatureReport({
    required this.fileName,
    required this.hasDigitalSignatures,
    required this.signatures,
    required this.summary,
  });
}
