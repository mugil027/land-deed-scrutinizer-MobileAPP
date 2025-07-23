from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from groq_extractor import extract_deed_info, extract_text
import os

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

    with open(file_path, "wb") as f:
        f.write(await file.read())

    with open(file_path, "rb") as f:
        raw_text = extract_text(f)

    extracted = extract_deed_info(raw_text)
    return {"Details": extracted}
