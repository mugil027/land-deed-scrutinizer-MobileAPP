import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // Added for managing storage permissions
import 'package:open_filex/open_filex.dart'; // Added to open the saved PDF

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _isLoading = false;
  String _statusMessage = "Opening camera..."; // Added status message

  @override
  void initState() {
    super.initState();
    // Ensure the context is fully built before calling async operations that use it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanProcess();
    });
  }

  Future<void> _startScanProcess() async {
    File? pdfFile; // Will hold the converted PDF file, initialized to null
    try {
      final pickedImage = await ImagePicker().pickImage(source: ImageSource.camera);

      if (pickedImage == null) {
        // User cancelled camera operation
        print("Camera operation cancelled by user.");
        _statusMessage = "Camera operation cancelled."; // Update message
        // No need to set isLoading, just pop with null
        if (mounted) Navigator.pop(context, null); // Explicitly pop with null
        return;
      }

      // Check if the widget is still in the widget tree before updating state
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _statusMessage = "Converting image to PDF..."; // Update message during conversion
      });

      final imageFile = File(pickedImage.path);
      pdfFile = await convertImageToPdf(imageFile); // This is the potentially heavy operation

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = "PDF conversion complete."; // Update message after conversion
      });

      // Show an option to save the PDF for inspection
      if (pdfFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("PDF created: ${pdfFile.path.split('/').last}"),
              action: SnackBarAction(
                label: 'SAVE & OPEN',
                onPressed: () async {
                  await saveAndOpenPdf(pdfFile!);
                },
              ),
              duration: const Duration(seconds: 5), // Keep snackbar visible longer
            ),
          );
        }
      }

    } catch (e) {
      // Catch any unhandled exceptions during the process
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Error during scan or conversion: ${e.toString()}"; // Show error message
        });
      }
      print("Error in _startScanProcess: $e"); // Log the error for debugging
    } finally {
      // Ensure Navigator.pop is called regardless of success or failure
      if (mounted) {
        // Optionally, add a small delay to let the user see the final status message
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, pdfFile); // Pop with the PDF file or null if an error occurred
      }
    }
  }

  // Converts an image file to a PDF file
  Future<File?> convertImageToPdf(File imageFile) async {
    try {
      final pdf = pw.Document();
      // Read bytes asynchronously to avoid blocking the UI thread for too long
      final imageBytes = await imageFile.readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(child: pw.Image(image)),
        ),
      );

      final dir = await getTemporaryDirectory();
      // Use a unique filename to avoid overwriting previous temporary PDFs
      final pdfPath = '${dir.path}/scanned_doc_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save()); // Save PDF asynchronously
      print("PDF saved temporarily to: ${pdfFile.path}");
      return pdfFile;
    } catch (e) {
      print("Error converting image to PDF: $e");
      return null; // Return null if PDF conversion fails
    }
  }

  // Saves the given PDF file to a public download directory and opens it
  Future<void> saveAndOpenPdf(File pdfFile) async {
    // Request storage permissions if not already granted
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request(); // For Android 11+
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Storage permission is required to save PDF.")),
          );
        }
        return;
      }
    }

    try {
      // Get the external public downloads directory
      final String? externalDir = (await getExternalStorageDirectory())?.path;
      String outputPath = '${externalDir}/Download/scanned_land_deed_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Ensure the directory exists
      final directory = Directory(File(outputPath).parent.path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Copy the file from temporary to public directory
      final File savedFile = await pdfFile.copy(outputPath);
      print("PDF saved to public directory: ${savedFile.path}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF saved to: ${savedFile.path}")),
        );
      }
      // Open the file
      OpenFilex.open(savedFile.path);
    } catch (e) {
      print("Error saving and opening PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save or open PDF: ${e.toString()}")),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Document"),
        backgroundColor: Theme.of(context).primaryColor, // Use app's primary color
        foregroundColor: Colors.white, // Ensures title text is visible
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? const CircularProgressIndicator() // Show spinner when loading
                : const Icon(Icons.camera_alt, size: 80, color: Colors.grey), // Camera icon
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                _statusMessage, // Display current status to the user
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
