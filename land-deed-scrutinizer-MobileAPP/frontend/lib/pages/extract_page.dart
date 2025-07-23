import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/extract_service.dart';
import 'package:clipboard/clipboard.dart'; // at top
import 'package:share_plus/share_plus.dart';

class ExtractPage extends StatefulWidget {
  const ExtractPage({super.key});

  @override
  State<ExtractPage> createState() => _ExtractPageState();
}

class _ExtractPageState extends State<ExtractPage> {
  File? selectedFile;
  Map<String, dynamic>? result;
  bool isLoading = false;

  Future<void> pickFile() async {
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

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ExtractService.uploadPDF(selectedFile!);
      setState(() {
        result = response;
      });
    } catch (e) {
      print("Extraction failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to extract: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
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
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.green.shade700),
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

  return Card(
    margin: const EdgeInsets.all(20),
    elevation: 10,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Extracted Details",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: details.entries.map<TableRow>((entry) {
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "${entry.key}:",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      entry.value.toString(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            "📝 Deed Summary",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: "This "),
                TextSpan(
                  text: deedType,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: " deed dated "),
                TextSpan(
                  text: date,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: " executed by "),
                TextSpan(
                  text: party1,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: " in favor of "),
                TextSpan(
                  text: party2,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: " in respect of Sy. No. "),
                TextSpan(
                  text: survey,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: " ("),
                TextSpan(
                  text: location,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ") and the same is registered in the office of the Sub-Registrar, "),
                TextSpan(
                  text: location,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: " in Book-1 as Doc. No. "),
                TextSpan(
                  text: regNo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: "."),
              ],
            ),
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ).animate().fade(duration: 500.ms).slideY(begin: 0.2),

          const SizedBox(height: 16),

          // Action buttons row
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Land Deed Extractor',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: pickFile,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text("Pick PDF", style: GoogleFonts.poppins()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: extractData,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: Text("Extract Details", style: GoogleFonts.poppins()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              buildStatusMessage(),
              const SizedBox(height: 20),
              if (result != null && !isLoading) buildExtractedData(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
