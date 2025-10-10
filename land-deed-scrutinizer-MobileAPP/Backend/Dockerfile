# ---------- Base Python Image ----------
FROM python:3.11-slim

# ---------- Install System Dependencies (Tesseract OCR) ----------
RUN apt-get update && apt-get install -y tesseract-ocr && rm -rf /var/lib/apt/lists/*

# ---------- Set Working Directory ----------
WORKDIR /app

# ---------- Copy Project Files ----------
COPY . .

# ---------- Install Python Dependencies ----------
RUN pip install --no-cache-dir -r requirements.txt

# ---------- Expose Port for Render ----------
EXPOSE 10000

# ---------- Start the FastAPI App ----------
CMD gunicorn "app:create_app()" --workers 1 --timeout 120 -b 0.0.0.0:10000
