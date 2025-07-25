import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startScanProcess(); // Kick off async function
  }

  Future<void> _startScanProcess() async {
    final pickedImage = await ImagePicker().pickImage(source: ImageSource.camera);

    if (pickedImage == null) {
      Navigator.pop(context); // Close if cancelled
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final imageFile = File(pickedImage.path);
    final pdfFile = await convertImageToPdf(imageFile);

    setState(() {
      _isLoading = false;
    });

    Navigator.pop(context, pdfFile); // Return PDF to previous screen
  }

  Future<File> convertImageToPdf(File imageFile) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageFile.readAsBytesSync());

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(child: pw.Image(image)),
      ),
    );

    final dir = await getTemporaryDirectory();
    final pdfFile = File('${dir.path}/scanned_doc.pdf');
    await pdfFile.writeAsBytes(await pdf.save());
    return pdfFile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Document"),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : const Text("Opening camera..."),
      ),
    );
  }
}
