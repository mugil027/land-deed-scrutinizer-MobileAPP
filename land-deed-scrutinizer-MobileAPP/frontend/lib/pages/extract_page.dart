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
    await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
        this.result = null;
      });
    }
  }

  Future<void> extractData() async {
    if (selectedFile == null) return;

    setState(() => isLoading = true);
    try {
      final response = await ExtractService.uploadPDF(selectedFile!);
      setState(() => result = response);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to extract: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> scanAndSaveAsPdf() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Storage permission is required.")),
      );
      return;
    }

    final pickedImage = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedImage == null) return;

    final imageFile = File(pickedImage.path);
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageFile.readAsBytesSync());

    pdf.addPage(pw.Page(
      build: (pw.Context context) => pw.Center(child: pw.Image(image)),
    ));

    final directory = Directory('/storage/emulated/0/Download');
    final outputPath = '${directory.path}/scanned_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final pdfFile = File(outputPath);
    await pdfFile.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("📄 PDF saved to: $outputPath")),
    );
  }

  Future<void> uploadPdfAndExtract(File pdfFile) async {
    setState(() {
      isLoading = true;
      result = null;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.214.71.163:8000/extract'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', pdfFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      setState(() {
        result = ExtractService.parseExtractedDetails(responseBody);
      });
    } catch (e) {
      print("Upload failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Extraction failed: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

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
          "📄 PDF uploaded: ${selectedFile!.path.split('/').last}, click on Extract Details to proceed",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget buildExtractedData() {
    final details = result?['Details'];
    if (details == null) return const Text("No details extracted.");

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
            Text("Extracted Details",
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
  }

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
                  ElevatedButton.icon(
                    onPressed: scanAndSaveAsPdf,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text("Scan & Save as PDF", style: GoogleFonts.poppins()),
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
