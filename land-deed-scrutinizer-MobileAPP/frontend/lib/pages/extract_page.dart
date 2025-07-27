import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:clipboard/clipboard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'dart:convert'; 
import '../services/extract_service.dart';
import 'scan_page.dart';

class ExtractPage extends StatefulWidget {
  const ExtractPage({super.key});

  @override
  State<ExtractPage> createState() => _ExtractPageState();
}

class _ExtractPageState extends State<ExtractPage> {
  File? selectedFile;
  Map<String, dynamic>? result;
  bool isLoading = false;
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.asset('assets/videos/background.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        _videoController.play();
        setState(() {});
      });

    // Call the permission request
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    // Request storage and camera permissions upfront
    await [
      Permission.storage,
      Permission.camera, // Added camera permission
      Permission.manageExternalStorage, // For saving PDFs to Downloads on Android
    ].request();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  // Allows user to pick a PDF file
  Future<void> pickPDF() async {
    FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (picked != null && picked.files.single.path != null) {
      setState(() {
        selectedFile = File(picked.files.single.path!);
        result = null; // Clear previous results
      });
      // Optionally, automatically extract after picking
      // extractData();
    }
  }

  // Sends the selected PDF to the backend for extraction
  Future<void> extractData() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick a PDF file first.")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await ExtractService.uploadPDF(selectedFile!);
      setState(() => result = response);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to extract: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Scans a document using the camera and converts it to PDF, then extracts
  Future<void> scanAndExtract() async {
    // Check camera permission
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission is required to scan documents.")),
        );
        return;
      }
    }

    // Navigate to ScanPage and wait for a result (the PDF file)
    final File? scannedPdf = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );

    if (scannedPdf != null) {
      setState(() {
        selectedFile = scannedPdf; // Set the scanned PDF as the selected file
        result = null; // Clear previous results
      });
      // Automatically proceed to extraction after a successful scan
      extractData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Scan cancelled or failed.")),
      );
    }
  }

  // UI for showing loading indicator or file selection message
  Widget buildStatusMessage() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      );
    } else if (selectedFile != null && result == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          "📄 PDF uploaded: ${selectedFile!.path.split('/').last}, click 'Extract Details' to proceed.",
          style: GoogleFonts.poppins(fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    } else if (selectedFile == null && result == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          "Pick a PDF or scan a document to get started!",
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // Renders the extracted data, differentiating between deed and non-deed documents
  Widget buildExtractedData() {
    final details = result?['Details'];
    if (details == null || details.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(20),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white.withOpacity(0.9),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text("No details extracted or invalid response format.",
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.red.shade700)),
        ),
      );
    }

    // Check if it's a land deed by looking for typical deed fields
    bool isLandDeed = details.containsKey("Deed Type") &&
        details.containsKey("Party 1") &&
        details.containsKey("Survey Number");

    if (isLandDeed) {
      // Logic for displaying Land Deed details
      String party1 = details["Party 1"] ?? "Party 1";
      String party2 = details["Party 2"] ?? "Party 2";
      String deedType = details["Deed Type"] ?? "...";
      String date = details["Date of Execution"] ?? "...";
      String survey = details["Survey Number"] ?? "...";
      String location = details["Location"] ?? "...";
      String regNo = details["Registration Number"] ?? "...";

      String summaryText =
          "This $deedType deed dated $date executed by $party1 in favor of $party2 in respect of Sy. No. $survey ($location) and the same is registered in the office of the Sub-Registrar, $location in Book-1 as Doc. No. $regNo.";

      Widget summaryWidget = Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: "This "),
            TextSpan(text: deedType, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: " deed dated "),
            TextSpan(text: date, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: " executed by "),
            TextSpan(text: party1, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: " in favor of "),
            TextSpan(text: party2, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: " in respect of Sy. No. "),
            TextSpan(text: survey, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: " ("),
            TextSpan(text: location, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: ") and the same is registered in the office of the Sub-Registrar, "),
            TextSpan(text: location, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: " in Book-1 as Doc. No. "),
            TextSpan(text: regNo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: "."),
          ],
        ),
        style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: Colors.black87),
      );

      return Card(
        margin: const EdgeInsets.all(20),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white.withOpacity(0.9),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Extracted Land Deed Details",
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: FlexColumnWidth(),
                },
                children: details.entries.map<TableRow>((entry) {
                  return TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text("${entry.key}:",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          )),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(entry.value.toString(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade900,
                          )),
                    ),
                  ]);
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text("📝 Deed Summary",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple,
                  )),
              const SizedBox(height: 10),
              summaryWidget.animate().fade(duration: 500.ms).slideY(begin: 0.2),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: "Copy Summary",
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      FlutterClipboard.copy(summaryText).then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Summary copied to clipboard")),
                        );
                      });
                    },
                  ),
                  IconButton(
                    tooltip: "Share Summary",
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      Share.share(summaryText);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // Logic for displaying Non-Deed Document details
      String documentType = details["Document Type"] ?? "Unknown Document";
      String summary = details["Summary"] ?? "No summary available.";
      Map<String, dynamic> keyInfo = {};
      if (details.containsKey("Key Information") && details["Key Information"] is Map) {
        keyInfo = details["Key Information"];
      }

      return Card(
        margin: const EdgeInsets.all(20),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white.withOpacity(0.9),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Document Type: $documentType",
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Text("Summary:",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(summary,
                  style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: Colors.black87)),
              if (keyInfo.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text("Key Information:",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  children: keyInfo.entries.map<TableRow>((entry) {
                    return TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text("${entry.key}:",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            )),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(entry.value.toString(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade900,
                            )),
                      ),
                    ]);
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: "Copy Details",
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      // Simple way to copy all details as JSON string
                      FlutterClipboard.copy(jsonEncode(details)).then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Details copied to clipboard")),
                        );
                      });
                    },
                  ),
                  IconButton(
                    tooltip: "Share Details",
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      Share.share(jsonEncode(details));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  // Common button style
  ButtonStyle getButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color.fromARGB(255, 210, 174, 109),
      foregroundColor: const Color.fromARGB(255, 0, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 240, 227, 188).withOpacity(0.9),
        elevation: 1,
        title: Text("Land Deed Extractor",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (_videoController.value.isInitialized)
            Positioned.fill(
              child: Opacity(
                opacity: 0.24,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
            ),
          SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: pickPDF,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text("Pick PDF", style: GoogleFonts.poppins()),
                    style: getButtonStyle(),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: extractData,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: Text("Extract Details", style: GoogleFonts.poppins()),
                    style: getButtonStyle(),
                  ),
                  const SizedBox(height: 12),
                  // Changed button to call scanAndExtract
                  ElevatedButton.icon(
                    onPressed: scanAndExtract,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text("Scan & Extract", style: GoogleFonts.poppins()), // Changed label
                    style: getButtonStyle(),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Scan. Extract. Understand.",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .fadeIn(duration: 1000.ms)
                      .then()
                      .scaleXY(end: 1.05, duration: 700.ms)
                      .then()
                      .scaleXY(end: 1.0, duration: 700.ms)
                      .then()
                      .fadeOut(duration: 700.ms),
                  buildStatusMessage(),
                  const SizedBox(height: 20),
                  if (result != null && !isLoading) buildExtractedData(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
    );
  }
}