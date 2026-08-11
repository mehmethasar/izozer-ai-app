import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';

final class DocumentScannerService {
  Future<File?> scanPdf({int maxPages = 20}) async {
    final paths = await CunningDocumentScanner.getPictures(
      noOfPages: maxPages,
      asPdf: true,
      scannerSource: ScannerSource.cameraAndGallery,
    );
    if (paths == null || paths.isEmpty) return null;
    final file = File(paths.first);
    return await file.exists() ? file : null;
  }

  Future<void> clearTemporaryFiles() => CunningDocumentScanner.cleanCache();
}
