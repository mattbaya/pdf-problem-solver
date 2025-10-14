# PDF Font Fixer Web Application

A web-based version of the PDF Font Fixer tool that allows users to upload PDFs with font problems and download the fixed versions.

## Features

- 🌐 Browser-based interface - no command line needed
- 📤 Drag-and-drop file upload
- ⚡ Automatic PDF processing
- 📥 Instant download of fixed PDFs
- 🎨 Clean, responsive UI
- 🔒 Files are automatically cleaned up after processing

## Prerequisites

Before running the web app, ensure you have:

1. **Python 3.7+** installed
2. **All PDF processing tools** installed (the web app uses the existing shell script)
   - Run `./fix-pdf-fonts-interactive.sh --help` to verify tools are installed

## Installation

1. Navigate to the web-app directory:
   ```bash
   cd web-app
   ```

2. Create a virtual environment (recommended):
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On macOS/Linux
   ```

3. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Running the Application

1. Start the Flask server:
   ```bash
   python app.py
   ```

2. Open your browser and go to:
   ```
   http://localhost:5000
   ```

3. Upload a PDF file by:
   - Dragging and dropping onto the upload area, or
   - Clicking "Choose File" and selecting your PDF

4. Wait for processing to complete

5. Download your fixed PDF

## How It Works

The web application:
1. Accepts PDF uploads (up to 100MB)
2. Saves the file temporarily
3. Calls the `fix-pdf-fonts-interactive.sh` script with automatic settings
4. Converts all pages to high-resolution (300 DPI) images
5. Returns the fixed PDF for download
6. Cleans up temporary files automatically

## Troubleshooting

### "PDF processing failed" error
- Ensure all PDF tools are installed: `brew install pdftk-java poppler qpdf ghostscript imagemagick`
- Check that `fix-pdf-fonts-interactive.sh` is in the parent directory
- Verify the script has execute permissions: `chmod +x ../fix-pdf-fonts-interactive.sh`

### Large files timing out
- The default timeout is set for files up to 100MB
- For larger files, use the command-line tool directly

### Port already in use
- Change the port in `app.py` (last line): `app.run(debug=True, port=5001)`

## Security Notes

- Files are stored temporarily and deleted after download
- Maximum file size is limited to 100MB
- Only PDF files are accepted
- Files are processed in isolated temporary directories

## Development

To run in development mode with auto-reload:
```bash
export FLASK_ENV=development
python app.py
```

To run in production, use a proper WSGI server:
```bash
pip install gunicorn
gunicorn -w 4 app:app
```