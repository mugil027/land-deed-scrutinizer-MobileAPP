from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from groq_extractor import extract_deed_info, extract_text
import os
import json # Import json for cleaner error messages

app = FastAPI()

# Allow access from any frontend (Flutter)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.post("/extract")
async def extract(file: UploadFile = File(...)):
    print(f"Received file: {file.filename}")
    file_path = os.path.join(UPLOAD_DIR, file.filename)

    try:
        # Save the uploaded file
        with open(file_path, "wb") as f:
            f.write(await file.read())
        print(f"File saved to: {file_path}")

        # Extract raw text from the PDF (which could be OCR'd)
        with open(file_path, "rb") as f:
            raw_text = extract_text(f)
        print(f"Raw text extracted (first 500 chars):\n{raw_text[:500]}...")

        if not raw_text.strip():
            print("Warning: Extracted text is empty or just whitespace.")
            raise HTTPException(status_code=400, detail="Could not extract any meaningful text from the document.")

        # Extract deed info using Groq
        extracted = extract_deed_info(raw_text)
        print(f"Extraction successful: {json.dumps(extracted, indent=2)}")
        return {"Details": extracted}

    except Exception as e:
        print(f"An error occurred during extraction: {e}")
        # Return a 500 error with details if something goes wrong
        raise HTTPException(status_code=500, detail=f"Failed to extract deed info: {e}")
    finally:
        # Clean up the uploaded file
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"Cleaned up file: {file_path}")

