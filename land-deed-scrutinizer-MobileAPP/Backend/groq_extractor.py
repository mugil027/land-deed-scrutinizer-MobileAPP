import fitz  # PyMuPDF
import pytesseract
from PIL import Image
import io
import os
from openai import OpenAI
from dotenv import load_dotenv
import json

load_dotenv()
client = OpenAI(api_key=os.getenv("GROQ_API_KEY"), base_url="https://api.groq.com/openai/v1")

def extract_text(file):
    doc = fitz.open(stream=file.read(), filetype="pdf")
    text = " ".join(page.get_text() for page in doc)

    if text.strip():
        return text
    else:
        ocr_text = ""
        for page in doc:
            pix = page.get_pixmap(dpi=300)
            img_bytes = pix.tobytes("png")
            image = Image.open(io.BytesIO(img_bytes))
            ocr_text += pytesseract.image_to_string(image) + "\n"
        return ocr_text

def extract_deed_info(cleaned_text):
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

    response = client.chat.completions.create(
        model="llama3-70b-8192",
        messages=[{"role": "user", "content": prompt}],
        temperature=0
    )

    raw_output = response.choices[0].message.content
    print("GROQ RAW OUTPUT:\n", raw_output)

    # ✅ Extract and validate JSON object using regex
    import re
    match = re.search(r"\{[\s\S]*\}", raw_output)
    if not match:
        raise Exception("No JSON found in Groq response")

    cleaned_json = match.group(0)

    try:
        return json.loads(cleaned_json)
    except json.JSONDecodeError as e:
        print("JSON Decode Error:", e)
        raise Exception("Failed to extract deed info: Invalid JSON format.")
