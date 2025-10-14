# PDF Problem Solver Toolkit

Comprehensive PDF processing toolkit focused on fixing printing problems and enhancing academic document workflows.

## Primary Goal

**Fix PDF printing problems** where documents show symbols (✦, ⌘, ☃) instead of text due to font encoding issues.

## Complete Toolkit Features

### Core Functionality
- Interactive font problem diagnosis and repair
- Automatic dependency management (installs Homebrew, PDF tools, etc.)
- High-resolution page conversion (300 DPI) for print quality
- Smart problem detection and user-friendly interfaces

### Web Applications
- **Flask Web App** - Python-based web interface requiring dedicated server
- **PHP Web App** - Lightweight web interface for shared hosting environments
- Both support drag-and-drop upload and automatic PDF processing

### Additional Tools
- OCR processing with intelligent title extraction
- Professional cover sheet generation
- File compression and optimization
- Security removal (passwords, restrictions)
- PDF repair and corruption fixing
- Interactive HTML indexes for academic packets

## Dependencies Automatically Managed

### Core PDF Tools
- `pdftk-java` - PDF manipulation and assembly
- `poppler` - PDF analysis (pdfinfo, pdffonts, pdftoppm, pdftotext)
- `qpdf` - PDF optimization and repair
- `ghostscript` - PDF compression and processing
- `imagemagick` - High-quality image processing

### OCR and Advanced Features
- `tesseract` - OCR processing with language support
- `tesseract-lang` - Additional language packs
- `wkhtmltopdf` - HTML to PDF conversion for cover sheets
- `mactex` - LaTeX distribution for professional document generation ✅ **INSTALLED**
- `pandoc` - Universal document converter for PDF documentation

### System Requirements
- **macOS** (primary platform with automatic setup)
- **Homebrew** (automatically installed if missing)
- **Python 3** (for advanced text processing)
- **Linux** (supported with manual dependency installation)

## Project Structure

```
pdf-problem-solver/
├── fix-pdf-fonts-interactive.sh        # 🎯 PRIMARY TOOL
├── additional-tools/                    # 🔧 Extended functionality
│   ├── ocr-and-index.sh                # OCR processing & indexing
│   ├── create-cover-sheet.sh           # Professional cover generation
│   ├── analyze-pdf.sh                  # Problem diagnosis
│   ├── compress-pdf.sh                 # File size optimization
│   ├── unlock-pdf.sh                   # Security removal
│   ├── repair-pdf.sh                   # Corruption fixing
│   ├── optimize-pdf.sh                 # Web optimization
│   ├── pdf-repair-toolkit.sh           # Comprehensive repair toolkit
│   └── add-page-numbers.sh             # Page numbering utility
├── web-app/                             # 🌐 Flask web application
│   ├── app.py                          # Flask backend server
│   ├── requirements.txt                # Python dependencies
│   ├── templates/                      # HTML templates
│   │   └── index.html                  # Web interface
│   └── README.md                       # Web app documentation
├── php-app/                             # 🐘 PHP web application
│   ├── index.php                       # All-in-one PHP application
│   ├── .htaccess                       # Apache configuration
│   └── README.md                       # PHP app documentation
├── LaTeX Tools/                         # 📄 Professional document generation
│   ├── create-final-pdf.sh             # Professional PDF course packets
│   ├── generate-professional-pdfs.sh   # Batch PDF generation with covers
│   ├── cover-sheet-template.tex        # LaTeX cover sheet template
│   ├── cover-sheet-template-v2.tex     # Enhanced cover template
│   └── toc-template.tex                # Table of contents template
├── Williams College Assets/             # 🎓 Institutional branding
│   ├── WILLIAMS COLLEGE LOGO FOR PRINT USE/
│   ├── WILLIAMS COLLEGE LOGO FOR WEB USE/
│   └── williams-logo.png               # Quick reference logo
└── Documentation/                       # 📚 Comprehensive guides
    ├── README.md                        # Main project overview
    ├── COMPLETE-TOOLKIT-README.md       # Full feature documentation
    ├── SOLUTION-SUMMARY.md             # Quick solutions guide
    ├── TOOLKIT-SUMMARY.md              # Tool reference
    └── additional-tools/README.md       # Extended tools guide
```

## Development Guidelines

### Tool Development
- Focus on user experience and automatic setup
- Include comprehensive error handling
- Provide clear progress indicators
- Support both interactive and command-line modes
- Maintain backward compatibility

### Testing Requirements
- Test on fresh macOS systems (no existing tools)
- Verify automatic dependency installation
- Test with various PDF types and sizes
- Ensure cross-platform compatibility guidance

### Code Standards
- Use color-coded output for clarity
- Implement proper cleanup (temp files, etc.)
- Include help systems and examples
- Follow security best practices (no secrets in code)

## Lint and Typecheck Commands

When working on this project, run these validation commands:

```bash
# Shell script validation
shellcheck *.sh additional-tools/*.sh

# Test PDF processing
./fix-pdf-fonts-interactive.sh --help
./additional-tools/analyze-pdf.sh test-document.pdf

# Web application validation
cd web-app && python -m py_compile app.py
cd php-app && php -l index.php

# Dependency verification
brew doctor
```

## Production Deployment Notes

This toolkit is designed for:
- Academic institutions processing course packets
- Individual users with PDF printing problems  
- IT departments supporting PDF workflows
- Students and faculty working with complex documents

The primary tool handles 90% of use cases, with additional tools providing comprehensive PDF problem-solving capabilities.