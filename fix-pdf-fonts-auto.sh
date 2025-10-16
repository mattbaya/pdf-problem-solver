#!/bin/bash

# Automated PDF Font Fix Script for Web App
# Converts all PDF pages to images and rebuilds to fix printing issues
# Non-interactive version for Flask integration

# Set PATH to include standard system directories
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Do not exit on error - we want to capture errors and return them
set +e

INPUT_PDF="$1"
OUTPUT_PDF="$2"

# Validate arguments
if [ -z "$INPUT_PDF" ] || [ -z "$OUTPUT_PDF" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 input.pdf output.pdf"
    exit 1
fi

# Validate input file exists
if [ ! -f "$INPUT_PDF" ]; then
    echo "Error: Input file '$INPUT_PDF' not found"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Convert all pages to images (300 DPI for print quality)
pdftoppm -png -r 300 "$INPUT_PDF" "$TEMP_DIR/page" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Failed to convert PDF to images"
    exit 1
fi

# Check if any images were created
if ! ls "$TEMP_DIR"/page-*.png >/dev/null 2>&1; then
    echo "Error: No pages were converted"
    exit 1
fi

# Convert images back to PDF using ImageMagick with memory limits
# Use -limit to prevent memory exhaustion on large PDFs
magick convert -limit memory 512MB -limit map 1GB "$TEMP_DIR"/page-*.png "$OUTPUT_PDF" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Failed to convert images back to PDF"
    exit 1
fi

# Verify output file was created
if [ ! -f "$OUTPUT_PDF" ]; then
    echo "Error: Output file was not created"
    exit 1
fi

# Success
exit 0
