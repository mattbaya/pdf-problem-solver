#!/bin/bash

# PDF Compression Tool
# Reduces PDF file size using various compression levels

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo "PDF Compression Tool"
    echo
    echo "Reduces PDF file size while maintaining acceptable quality."
    echo
    echo "USAGE:"
    echo "  $0 input.pdf [quality]"
    echo
    echo "QUALITY LEVELS:"
    echo "  screen    - Smallest size, lowest quality (web/email)"
    echo "  ebook     - Small size, good for reading (default)"
    echo "  printer   - Larger size, good print quality"
    echo "  prepress  - Largest size, highest quality"
    echo
    echo "EXAMPLES:"
    echo "  $0 document.pdf              # Use default (ebook) quality"
    echo "  $0 document.pdf screen       # Maximum compression"
    echo "  $0 document.pdf printer      # Print quality"
    echo
    exit 0
}

compress_pdf() {
    local input_pdf="$1"
    local quality="${2:-ebook}"
    local output_pdf="${input_pdf%.pdf}-compressed.pdf"
    
    echo -e "${CYAN}Compressing PDF with '$quality' quality...${NC}"
    
    local original_size=$(stat -f%z "$input_pdf" 2>/dev/null || stat -c%s "$input_pdf")
    
    gs -sDEVICE=pdfwrite \
       -dCompatibilityLevel=1.4 \
       -dPDFSETTINGS=/$quality \
       -dNOPAUSE \
       -dQUIET \
       -dBATCH \
       -sOutputFile="$output_pdf" \
       "$input_pdf"
    
    local new_size=$(stat -f%z "$output_pdf" 2>/dev/null || stat -c%s "$output_pdf")
    local reduction=$(( (original_size - new_size) * 100 / original_size ))
    
    echo -e "${GREEN}✓ Compression complete!${NC}"
    printf "Original: %s MB\n" "$((original_size / 1024 / 1024))"
    printf "Compressed: %s MB\n" "$((new_size / 1024 / 1024))"
    printf "Reduction: %d%%\n" "$reduction"
    echo "Output: $output_pdf"
}

# Main
if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ $# -eq 0 ]; then
    show_help
fi

if [ ! -f "$1" ]; then
    echo -e "${RED}Error: File not found: $1${NC}"
    exit 1
fi

if ! command -v gs >/dev/null 2>&1; then
    echo -e "${RED}Error: Ghostscript not installed${NC}"
    echo "Install with: brew install ghostscript"
    exit 1
fi

compress_pdf "$1" "$2"