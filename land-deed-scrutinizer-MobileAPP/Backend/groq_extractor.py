import fitz  # PyMuPDF
import pytesseract
from PIL import Image
import io
import os
from openai import OpenAI
from dotenv import load_dotenv
import json
import re
import platform  # already imported, just once is enough

# ---------- ENVIRONMENT SETUP ----------
load_dotenv()

client = OpenAI(
    api_key=os.getenv("GROQ_API_KEY"),
    base_url="https://api.groq.com/openai/v1"
)

# ---------- TESSERACT PATH SETUP ----------
if platform.system() == "Windows":
    pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
else:
    # Path for Linux (Render, Ubuntu, Docker)
    pytesseract.pytesseract.tesseract_cmd = "/usr/bin/tesseract"


# ---------- PDF TEXT EXTRACTION ----------
def extract_text(file):
    """Extract text from a PDF using PyMuPDF, fallback to OCR if needed."""
    try:
        doc = fitz.open(stream=file.read(), filetype="pdf")
    except Exception as e:
        print(f"Error opening PDF: {e}")
        return ""

    text = " ".join(page.get_text("text") for page in doc)
    print(f"PyMuPDF extracted text (first 500 chars):\n{text[:500]}...")

    # If PyMuPDF found readable text, use it
    if text.strip():
        return text

    # Otherwise, use OCR (for scanned documents)
    print("PyMuPDF found no text. Attempting OCR with Tesseract...")
    ocr_text = ""
    for page_num, page in enumerate(doc):
        try:
            pix = page.get_pixmap(dpi=300)
            img_bytes = pix.tobytes("png")
            image = Image.open(io.BytesIO(img_bytes))
            page_ocr_text = pytesseract.image_to_string(image)
            ocr_text += page_ocr_text + "\n"
            print(f"OCR extracted page {page_num + 1} (first 200 chars): {page_ocr_text[:200]}...")
        except Exception as e:
            print(f"Error during OCR for page {page_num + 1}: {e}")
            continue  # move to next page

    if not ocr_text.strip():
        print("OCR also failed to extract any text.")
    return ocr_text


# ---------- GROQ DEED INFO EXTRACTION ----------
def extract_deed_info(cleaned_text):
    """Send cleaned text to Groq for structured legal deed extraction."""
    if not cleaned_text.strip():
        print("Error: Empty text provided to extract_deed_info.")
        return {"Error": "No text available for extraction."}

    prompt = f"""
You are a legal assistant. Extract the following information from this Indian land deed text and give the output as a JSON object:

Step 1: Carefully read the uploaded document.
Step 2: If the document is a **land deed** (e.g., Sale Deed, Gift Deed, Mortgage Deed, Partition Deed, or Lease/Release Deed), extract the following details:
- Deed Type
- Party 1 (Seller/Vendor/Lessor/Donor)
- Party 2 (Buyer/Purchaser/Lessee/Donee)
- Survey Number
- Location
- Date of Execution
- Registration Number (format like 'TVR-1-1234-2024-25')

Return **only valid JSON** exactly like this:
{{
  "Deed Type": "...",
  "Party 1": "...",
  "Party 2": "...",
  "Survey Number": "...",
  "Location": "...",
  "Date of Execution": "...",
  "Registration Number": "..."
}}

If the document is not a land deed:
- Identify its type (e.g., resume, invoice, ID, etc.)
- Provide a one-line summary in JSON like:
{{"Document Type": "...", "Summary": "..."}}

Text:
{cleaned_text}
"""

    print(f"Prompt sent to Groq (first 500 chars):\n{prompt[:500]}...")

    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": prompt}],
            temperature=0
        )

        raw_output = response.choices[0].message.content.strip()
        print("GROQ RAW OUTPUT:\n", raw_output)

        # Extract JSON using regex
        match = re.search(r"\{[\s\S]*\}", raw_output)
        if not match:
            print("Error: No JSON found in Groq response.")
            return {"Error": "Groq did not return valid JSON.", "Raw Output": raw_output}

        cleaned_json = match.group(0)
        return json.loads(cleaned_json)

    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}")
        return {"Error": "Invalid JSON format from Groq.", "Raw Output": raw_output}

    except Exception as e:
        print(f"Error during Groq API call: {e}")
        return {"Error": str(e)}
