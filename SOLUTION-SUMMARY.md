# PDF Print Problem Solution Summary

## Problem Identified
Pages 231-246 of "ARTH 309 Volume III - Trenton Barnes.pdf" were causing printing issues, specifically page 233 showing symbols instead of text on some printers.

## Root Cause Analysis
The issue was caused by **custom font encodings** in embedded fonts. Analysis revealed several fonts with "Custom" encoding:
- `AAOXUL+LyonText-Regular` (Custom encoding)
- `AAAAAD+LyonText-RegularItalic` (Custom encoding) 
- `AAAATR+HarrietText-Light` (Custom encoding)
- `AAAABF+Calibre-Light` (Custom encoding)

These custom encodings contain non-standard character mappings that some printers cannot interpret correctly, resulting in garbled text or symbols.

## Solution Implemented
1. **Extracted problematic pages** (231-246) using pdftk
2. **Converted pages to high-resolution PNG images** (300 DPI) using pdftoppm
3. **Reconstructed pages as image-based PDF** using ImageMagick
4. **Reassembled complete document** by combining:
   - Pages 1-230 (original)
   - Pages 231-246 (image-based, fixed)
   - Pages 247-506 (original)

## Files Created
- `ARTH 309 Volume III - Trenton Barnes - FIXED.pdf` - The repaired PDF ready for printing
- `fix-pdf-fonts.sh` - Reusable script for fixing similar font encoding issues in other PDFs

## Verification
- Fixed PDF maintains original 506 pages
- Pages 231-246 now contain no problematic fonts (purely image-based)
- File size increased from 61MB to 115MB (expected due to high-resolution images)

## Future Use
Use the `fix-pdf-fonts.sh` script for similar issues:
```bash
./fix-pdf-fonts.sh "input.pdf" start_page end_page "output.pdf"
```

The original OCR'd PDF should be kept as the digital version, while the fixed PDF should be used for printing purposes.