# PDF Problem Solver Toolkit

**Comprehensive toolkit for fixing PDF printing problems and managing academic documents.**

The primary solution for fixing PDF files that display garbled text, symbols, or missing content when printing, now available in multiple formats:

- **🖥️ Command Line** - Interactive and batch processing tools
- **🌐 Web Applications** - Browser-based interfaces for easy use
- **📄 Professional Tools** - Academic document generation and management

## Quick Start

### 🖥️ Command Line (Traditional)
```bash
# Make executable (first time only)
chmod +x fix-pdf-fonts-interactive.sh

# Run in interactive mode (recommended)
./fix-pdf-fonts-interactive.sh

# Or process a specific file directly
./fix-pdf-fonts-interactive.sh "My Document.pdf"
```

### 🌐 Web Applications

#### PHP Web App (Recommended - Production Ready)
**Best for:** Shared hosting, VPS, dedicated servers. No background process needed!

```bash
# Copy php-app folder to web server
# Access via browser: http://yourserver/php-app/

# See php-app/DEPLOYMENT.md for detailed setup instructions
```

**Features:**
- ✅ Professional cover sheet generation with logo upload
- ✅ Auto-generated table of contents with headline detection
- ✅ Configurable DPI (300/600/1200)
- ✅ OCR processing
- ✅ Page numbering
- ✅ PDF compression
- ✅ Security removal
- ✅ All processing on-demand (no daemon required)

#### Flask Web App (Python - Alternative)
**Best for:** Development, custom deployments requiring async processing.

```bash
cd web-app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
# Open http://localhost:5000
```

**Note:** Flask version requires a continuously running process. See web-app/DEPLOYMENT.md for details.

## What It Fixes

This script solves common PDF printing problems:
- **Text shows as symbols** (✦, ⌘, ☃, etc.) instead of letters
- **Missing text** on printed pages
- **Font substitution errors**
- **Custom encoding issues** that confuse printers

## How It Works

1. **Scans** your PDF for fonts with custom encodings that cause print problems
2. **Identifies** problematic pages automatically 
3. **Converts** those pages to high-resolution images (300 DPI for print quality)
4. **Rebuilds** the PDF with the fixed pages
5. **Preserves** the original for digital use with searchable text

## Features

### 🚀 **Fully Automated Setup**
- Automatically installs Homebrew if missing
- Installs all required tools (pdftk, poppler-utils, ImageMagick)
- Cross-platform support (macOS primary, Linux instructions)

### 🎯 **Smart Problem Detection**
- Scans entire PDF for font encoding issues
- Shows exactly which pages have problems
- Groups consecutive problem pages for efficiency

### 💻 **User-Friendly Interface**
- Interactive file selection from current/custom directories
- Color-coded output with progress indicators
- Clear error messages and helpful suggestions

### ⚡ **Flexible Usage**
- Interactive mode for beginners
- Command-line mode for power users
- Batch processing support

## Project Structure

```
pdf-problem-solver/
├── fix-pdf-fonts-interactive.sh        # 🎯 MAIN TOOL - Interactive font problem fixer
├── additional-tools/                    # 🔧 Other PDF tools
│   ├── analyze-pdf.sh                  #   📊 Analyze PDFs for problems
│   ├── compress-pdf.sh                 #   📦 Reduce file size
│   ├── unlock-pdf.sh                   #   🔓 Remove passwords/restrictions
│   ├── repair-pdf.sh                   #   🛠️  Fix corrupted PDFs
│   ├── optimize-pdf.sh                 #   ⚡ Web/compatibility optimization
│   ├── pdf-repair-toolkit.sh           #   🎛️  Interactive toolkit for all tools
│   ├── ocr-and-index.sh                #   🔍 OCR processing & HTML indexing
│   ├── add-page-numbers.sh             #   📄 Add page numbers to PDFs
│   ├── generate-toc.sh                 #   📋 Generate table of contents (NEW!)
│   ├── generate-cover-sheet.sh         #   📄 Create professional cover sheets (NEW!)
│   └── README.md                       #   📚 Additional tools documentation
├── web-app/                             # 🌐 Flask web application
│   ├── app.py                          #   Python backend server
│   ├── requirements.txt                #   Python dependencies
│   ├── templates/                      #   HTML templates
│   │   └── index.html                  #   Web interface
│   └── README.md                       #   Web app setup guide
├── php-app/                             # 🐘 PHP web application
│   ├── index.php                       #   All-in-one PHP application
│   ├── .htaccess                       #   Apache configuration
│   └── README.md                       #   PHP app setup guide
├── LaTeX Tools/                         # 📄 Course packet generation
│   ├── create-final-pdf.sh             #   Professional PDF course packets
│   ├── generate-professional-pdfs.sh   #   Batch generation with covers  
│   ├── create-template-cover-sheet.sh  #   Interactive cover sheet creator
│   ├── cover-sheet-template.tex        #   LaTeX cover template
│   └── toc-template.tex                #   Table of contents template
├── Williams College Assets/             # 🎓 Institutional branding
│   ├── WILLIAMS COLLEGE LOGO FOR PRINT USE/
│   ├── WILLIAMS COLLEGE LOGO FOR WEB USE/
│   └── williams-logo.png               # Quick reference logo
├── Documentation/                       # 📚 Comprehensive guides
│   ├── README.md                        # This file (main project overview)
│   ├── COMPLETE-TOOLKIT-README.md       # Full feature documentation
│   ├── SOLUTION-SUMMARY.md             # Technical solutions guide
│   ├── TOOLKIT-SUMMARY.md              # Quick tool reference
│   └── additional-tools/README.md       # Extended tools guide
└── generated-covers/                    # 📑 Generated cover sheets
    └── Cover_Sheet_*.pdf                # Course-specific covers
```

## 🎯 **Start Here for Print Problems**

### Command Line
If your PDF shows **symbols instead of text** when printing:
```bash
./fix-pdf-fonts-interactive.sh
```

### Web Interface
For a user-friendly browser interface:
- **Flask App**: `cd web-app && python app.py` → http://localhost:5000
- **PHP App**: Upload to web server → http://yourserver/php-app/

## 🔧 **Other PDF Issues**
For file size, security, corruption, or other problems:
```bash
cd additional-tools
./analyze-pdf.sh your-document.pdf  # Get recommendations
```

## 📄 **Professional Course Packets**
For creating professional academic course packets with covers:
```bash
cd "LaTeX Tools"
./create-final-pdf.sh input.pdf       # Single PDF with professional cover
./generate-professional-pdfs.sh       # Batch process from CSV data
```

## Example Session

```bash
$ ./fix-pdf-fonts-interactive.sh

================================
  PDF Print Problem Fixer v2.0
================================

ℹ Checking system dependencies...
✓ Homebrew is installed
✓ pdftk found
✓ poppler-utils found  
✓ ImageMagick found
✓ All required tools are available!

ℹ Step 1: Select PDF file
How would you like to select your PDF?
1) Enter filename directly
2) Choose from current directory
3) Choose from a specific directory

Enter choice (1-3): 2

ℹ PDF files in current directory:
1) ARTH 309 Volume III - Trenton Barnes.pdf
2) Another Document.pdf

Select file number: 1
✓ Selected: ARTH 309 Volume III - Trenton Barnes.pdf

ℹ Step 2: Identify problematic pages
How would you like to identify problem pages?
1) Let me scan the entire PDF for font problems (recommended)
2) I know the specific page numbers with problems

Enter choice (1-2): 1

ℹ Scanning 'ARTH 309 Volume III - Trenton Barnes.pdf' for font problems...
ℹ Document has 506 pages
  Checking pages 1-50... OK
  Checking pages 51-100... OK
  ...
  Checking pages 231-246... PROBLEMS FOUND

⚠ Found font problems on 16 pages:
  Problematic page ranges: 231-246

Output filename [ARTH 309 Volume III - Trenton Barnes-FIXED.pdf]: 

ℹ Summary:
  Input PDF: ARTH 309 Volume III - Trenton Barnes.pdf
  Problem pages: 231 232 233 234 235 236 237 238 239 240 241 242 243 244 245 246
  Output PDF: ARTH 309 Volume III - Trenton Barnes-FIXED.pdf

Proceed with fixing? (y/N): y

ℹ Step 3: Processing PDF...
ℹ Converting 16 problematic pages to images...
  Processing page ranges: 231-246
  Converting page 231... done
  Converting page 232... done
  ...
✓ Fixed PDF created: ARTH 309 Volume III - Trenton Barnes-FIXED.pdf

✓ PDF processing completed!

ℹ File comparison:
  Original: ARTH 309 Volume III - Trenton Barnes.pdf (61319875 bytes)
  Fixed:    ARTH 309 Volume III - Trenton Barnes-FIXED.pdf (114679337 bytes)

⚠ File size increased by ~87% due to high-resolution image conversion
ℹ This is normal and ensures excellent print quality

✓ The fixed PDF should now print correctly on all printers!
ℹ Keep the original PDF for digital use (OCR text intact)
ℹ Use the fixed PDF for printing purposes
```

## Dependencies

**Automatically installed on macOS:**
- Homebrew (if not present)
- pdftk-java
- poppler (pdfinfo, pdffonts, pdftoppm)
- imagemagick

**Manual installation on Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install pdftk poppler-utils imagemagick

# CentOS/RHEL
sudo yum install pdftk poppler-utils ImageMagick
```

## Technical Details

The script identifies PDFs with fonts using "Custom" encoding, which many printers cannot interpret correctly. It converts these problematic pages to high-resolution PNG images (300 DPI) and rebuilds them as a printer-friendly PDF.

**Root Cause:** Fonts with custom character mappings that don't follow standard encoding schemes

**Solution:** Image-based pages that bypass font rendering entirely

**Trade-off:** Larger file size for universal print compatibility

## Troubleshooting

### "Command not found" errors
Run the script again - it will automatically install missing tools.

### "Permission denied"
```bash
chmod +x fix-pdf-fonts-interactive.sh
```

### Large file sizes
This is normal - high-resolution images ensure print quality. Use the original PDF for digital viewing.

### Linux compatibility
The script detects Linux and provides appropriate package installation commands.

---

## Credits

Created to solve real-world PDF printing problems encountered with academic documents containing complex font encodings.