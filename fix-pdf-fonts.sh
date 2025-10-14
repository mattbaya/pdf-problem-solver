#!/bin/bash

# PDF Font Fix Script
# Converts specified PDF pages to images and rebuilds them to fix printing issues
# caused by problematic font encodings

set -e

usage() {
    echo "Usage: $0 input.pdf start_page end_page [output.pdf]"
    echo "Example: $0 'document.pdf' 231 246 'document-fixed.pdf'"
    exit 1
}

if [ $# -lt 3 ]; then
    usage
fi

INPUT_PDF="$1"
START_PAGE="$2"
END_PAGE="$3"
OUTPUT_PDF="${4:-${INPUT_PDF%.pdf}-FIXED.pdf}"

# Validate input file exists
if [ ! -f "$INPUT_PDF" ]; then
    echo "Error: Input file '$INPUT_PDF' not found"
    exit 1
fi

echo "Fixing PDF font issues in pages $START_PAGE-$END_PAGE of '$INPUT_PDF'"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Extract problematic pages
echo "Extracting pages $START_PAGE-$END_PAGE..."
pdftk "$INPUT_PDF" cat ${START_PAGE}-${END_PAGE} output "$TEMP_DIR/problem_pages.pdf"

# Convert pages to images (high resolution for print quality)
echo "Converting pages to images..."
mkdir -p "$TEMP_DIR/page_images"
pdftoppm -f $START_PAGE -l $END_PAGE -png -r 300 "$INPUT_PDF" "$TEMP_DIR/page_images/page"

# Convert images back to PDF
echo "Converting images back to PDF..."
magick "$TEMP_DIR/page_images/page-*.png" "$TEMP_DIR/fixed_pages.pdf"

# Extract pages before and after problem area
echo "Extracting surrounding pages..."
if [ $START_PAGE -gt 1 ]; then
    BEFORE_END=$((START_PAGE - 1))
    pdftk "$INPUT_PDF" cat 1-${BEFORE_END} output "$TEMP_DIR/before_problem.pdf"
fi

# Get total pages
TOTAL_PAGES=$(pdfinfo "$INPUT_PDF" | grep "Pages:" | awk '{print $2}')
if [ $END_PAGE -lt $TOTAL_PAGES ]; then
    AFTER_START=$((END_PAGE + 1))
    pdftk "$INPUT_PDF" cat ${AFTER_START}-end output "$TEMP_DIR/after_problem.pdf"
fi

# Combine all parts
echo "Combining into final PDF..."
PARTS=""
[ -f "$TEMP_DIR/before_problem.pdf" ] && PARTS="$PARTS $TEMP_DIR/before_problem.pdf"
PARTS="$PARTS $TEMP_DIR/fixed_pages.pdf"
[ -f "$TEMP_DIR/after_problem.pdf" ] && PARTS="$PARTS $TEMP_DIR/after_problem.pdf"

pdftk $PARTS cat output "$OUTPUT_PDF"

echo "Fixed PDF created: $OUTPUT_PDF"
echo "Original size: $(stat -f%z "$INPUT_PDF" 2>/dev/null || stat -c%s "$INPUT_PDF" 2>/dev/null || echo "unknown") bytes"
echo "Fixed size: $(stat -f%z "$OUTPUT_PDF" 2>/dev/null || stat -c%s "$OUTPUT_PDF" 2>/dev/null || echo "unknown") bytes"

# Clean up temporary files
echo "Cleaning up temporary files..."