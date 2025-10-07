import fitz  # PyMuPDF
import pytesseract
from PIL import Image
import io
import os
from openai import OpenAI
from dotenv import load_dotenv
import json
import re

load_dotenv()
client = OpenAI(api_key=os.getenv("GROQ_API_KEY"), base_url="https://api.groq.com/openai/v1")

# --- ADD THIS LINE IF TESSERACT IS NOT IN YOUR SYSTEM PATH ---
# On Windows, replace 'C:\\Program Files\\Tesseract-OCR\\tesseract.exe' with your actual installation path
# On Linux/macOS, it's usually just 'tesseract' if installed via package manager
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe' # <--- IMPORTANT: Adjust this path!
# -------------------------------------------------------------

def extract_text(file):
    doc = fitz.open(stream=file.read(), filetype="pdf")
    text = " ".join(page.get_text() for page in doc)
    print(f"PyMuPDF extracted text (first 500 chars):\n{text[:500]}...")

    if text.strip():
        return text
    else:
        print("PyMuPDF found no text. Attempting OCR with Tesseract...")
        ocr_text = ""
        for page_num, page in enumerate(doc):
            try:
                pix = page.get_pixmap(dpi=300)
                img_bytes = pix.tobytes("png")
                image = Image.open(io.BytesIO(img_bytes))
                page_ocr_text = pytesseract.image_to_string(image)
                ocr_text += page_ocr_text + "\n"
                print(f"OCR extracted for page {page_num + 1} (first 200 chars):\n{page_ocr_text[:200]}...")
            except Exception as e:
                print(f"Error during OCR for page {page_num + 1}: {e}")
                continue # Try to process next page
        if not ocr_text.strip():
            print("OCR also failed to extract any text.")
        return ocr_text

def extract_deed_info(cleaned_text):
    if not cleaned_text.strip():
        print("Error: Empty text provided to extract_deed_info.")
        return {"Error": "No text available for extraction."}

    prompt = f"""
You are a legal assistant. Extract the following information from this Indian land deed text and give the output as a JSON object:

Step 1: Carefully read the uploaded document.
Step 2: If the document is a **land deed** (e.g., Sale Deed, Gift Deed, Mortgage Deed, Partition Deed, or Release Deed), extract the following details
- Deed Type
- Party 1 (Seller/Vendor/Lessor/Donor)
- Party 2 (Buyer/Purchaser/Lessee/Donee)
- Survey Number
- Location
- Date of Execution
- Registration Number
the Registration Number will be like "TVR-1-1234-2024-25" in this format
and Return only the extracted data in **strict valid JSON** like this:
{{
  "Deed Type": "...",
  "Party 1": "...",
  "Party 2": "...",
  "Survey Number": "...",
  "Location": "...",
  "Date of Execution": "...",
  "Registration Number": "..."
}}

Instructions:
- Do NOT return markdown or explanation
- Do NOT wrap in triple backticks
- Make sure all keys and string values are enclosed in double quotes
- Format it as plain JSON (no comments, no extra text)
- replace party 1 and party 2 as seller or vendor or lessor or .... and buyer or purchaser or lessee or.. according to the deed

Step 3: If the document is not a land deed, do NOT return the above fields. Instead:

Identify what type of document it is (e.g., resume, invoice, Aadhaar card, medical report, etc.).
Provide a short and clear summary explaining what the document is about.
If possible, extract key information like the person's name (in case of resume or ID), company name (in case of invoice), subject (in case of question paper), etc. and make sure you return output in json format only
Text:
{cleaned_text}
"""
    print(f"Prompt sent to Groq (first 500 chars):\n{prompt[:500]}...")

    try:
        response = client.chat.completions.create(
            model="llama-3.1-70b-versatile",
            messages=[{"role": "user", "content": prompt}],
            temperature=0
        )

        raw_output = response.choices[0].message.content
        print("GROQ RAW OUTPUT:\n", raw_output)

        # ✅ Extract and validate JSON object using regex
        match = re.search(r"\{[\s\S]*\}", raw_output)
        if not match:
            print("Error: No JSON found in Groq response using regex.")
            # Fallback for non-JSON responses, e.g., if Groq gives an error message
            if "error" in raw_output.lower() or "fail" in raw_output.lower():
                return {"Error": "Groq API returned an error or unexpected response.", "Raw Groq Output": raw_output}
            raise Exception("No JSON found in Groq response")

        cleaned_json = match.group(0)
        print(f"Cleaned JSON string:\n{cleaned_json}")

        try:
            return json.loads(cleaned_json)
        except json.JSONDecodeError as e:
            print(f"JSON Decode Error: {e} - Raw JSON string was: {cleaned_json}")
            raise Exception(f"Failed to extract deed info: Invalid JSON format from Groq. Error: {e}")

    except Exception as e:
        print(f"Error during Groq API call or response processing: {e}")
        raise Exception(f"Groq API interaction failed: {e}")
