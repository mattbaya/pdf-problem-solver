# PDF Problem Solver - Processing Pipeline

## Overview

The web application now supports a comprehensive multi-stage PDF processing pipeline that applies user-selected operations in the optimal order.

## Processing Order

The backend processes PDFs in this specific order to ensure best results:

### Stage 1: Remove Security (if selected)
**Script:** `additional-tools/unlock-pdf.sh`
- Removes password protection
- Removes printing/copying restrictions
- **Must run first** because other tools need access to the PDF

### Stage 2: Fix PDF Fonts (always runs)
**Script:** `fix-pdf-fonts-interactive.sh`
- Main processing step
- Converts pages to high-resolution images (300/600/1200 DPI)
- Options:
  - Convert all pages (safest)
  - Auto-detect problem pages only
  - Specific pages (custom)

### Stage 3: OCR Processing (if selected)
**Script:** `additional-tools/ocr-and-index.sh`
- Extracts text using Tesseract OCR
- Makes scanned documents searchable
- Adds text layer to images
- Useful for documents that were scanned or converted to images

### Stage 4: Add Page Numbers (if selected)
**Script:** `additional-tools/add-page-numbers.sh`
- Adds page numbers to each page
- Default position: bottom-right
- Uses professional formatting

### Stage 5: Compress Output (if selected)
**Script:** `additional-tools/compress-pdf.sh`
- Reduces file size
- Uses 'ebook' quality setting (good balance)
- **Runs last** to compress the final processed PDF

## File Naming Convention

Each stage adds a suffix to track processing:
- `-unlocked.pdf` - Security removed
- `-FIXED.pdf` - Fonts fixed
- `-OCR.pdf` - OCR processed
- `-numbered.pdf` - Page numbers added
- `-compressed.pdf` - Compressed

Final output is renamed to: `fixed_[original-filename].pdf`

## Web Form Options

### Required Fields:
- **PDF File** - The document to process

### Optional Fields:
- **Email** - For future notification feature
- **Pages to Convert** - Dropdown:
  - Convert all pages (safest, recommended)
  - Auto-detect problem pages only
  - Specific pages (custom entry)
- **Image Quality (DPI)** - Dropdown:
  - 300 DPI (Good, faster)
  - 600 DPI (Excellent, recommended) ← DEFAULT
  - 1200 DPI (Maximum quality, slower)

### Additional Processing Options (Checkboxes):
- **Re-OCR Document** - Extract text using OCR (useful for scanned documents)
- **Add Page Numbers** - Add page numbers to each page
- **Compress Output** - Reduce file size while maintaining quality
- **Remove Security** - Remove password protection or restrictions

## Backend Implementation

### Flask (app.py)
```python
# Processing pipeline:
1. Check if remove_security → unlock-pdf.sh
2. Always run → fix-pdf-fonts-interactive.sh with DPI and pages options
3. Check if do_ocr → ocr-and-index.sh --full-ocr
4. Check if add_page_numbers → add-page-numbers.sh
5. Check if compress → compress-pdf.sh ebook
6. Move final file to output path
```

### PHP (index.php)
```php
// Same pipeline as Flask
// Each step checks for output file with expected suffix
// Cleans up intermediate files to save disk space
```

## Error Handling

- Each stage checks for successful output
- Intermediate files are cleaned up on error
- User receives clear error messages
- Original file is never modified (always preserved)

## Dependencies

All processing scripts require:
- `pdftk-java` - PDF manipulation
- `poppler-utils` - PDF analysis and conversion
- `imagemagick` - Image processing
- `ghostscript` - PDF compression
- `qpdf` - PDF optimization

OCR requires:
- `tesseract` - OCR engine
- `tesseract-lang` - Language packs

Page numbering requires:
- `pdftk-java` - PDF manipulation

## Performance Considerations

### Processing Time Factors:
1. **DPI Setting** - Higher DPI = longer processing
   - 300 DPI: Fast
   - 600 DPI: Moderate (recommended)
   - 1200 DPI: Slow but highest quality

2. **Page Selection** - Fewer pages = faster
   - All pages: Slowest but safest
   - Auto-detect: Moderate
   - Specific pages: Fastest

3. **OCR Processing** - Adds significant time
   - Can double processing time for large documents
   - Uses Tesseract OCR engine

4. **Compression** - Usually quick
   - 'ebook' quality is fast
   - Large documents take longer

### Recommended Settings:
- **For quick test:** 300 DPI, specific pages only
- **For production:** 600 DPI, all pages, + desired options
- **For maximum quality:** 1200 DPI, all pages, OCR

## Future Enhancements

Potential additions:
- Email notification when processing completes
- Progress bar showing current stage
- Batch processing (multiple files)
- Custom page number positioning
- Watermark addition
- Cover sheet generation
- Table of contents creation
