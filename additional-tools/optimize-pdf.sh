#!/bin/bash

# PDF Optimization Tool
# Optimizes PDFs for web viewing and compatibility

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo "PDF Optimization Tool"
    echo
    echo "Optimizes PDFs for web viewing, compatibility, and faster loading."
    echo
    echo "USAGE:"
    echo "  $0 input.pdf"
    echo
    echo "OPTIMIZATIONS:"
    echo "  • Linearizes for faster web loading"
    echo "  • Preserves object streams for efficiency"
    echo "  • Fixes minor structural issues"
    echo "  • Improves compatibility with older viewers"
    echo
    echo "EXAMPLE:"
    echo "  $0 document.pdf"
    echo
    exit 0
}

optimize_pdf() {
    local input_pdf="$1"
    local output_pdf="${input_pdf%.pdf}-optimized.pdf"
    
    echo -e "${CYAN}Optimizing PDF for web and compatibility...${NC}"
    
    # Get original size
    local original_size=$(stat -f%z "$input_pdf" 2>/dev/null || stat -c%s "$input_pdf")
    
    # Optimize with qpdf
    if qpdf --linearize --object-streams=preserve "$input_pdf" "$output_pdf" 2>/dev/null; then
        local new_size=$(stat -f%z "$output_pdf" 2>/dev/null || stat -c%s "$output_pdf")
        
        echo -e "${GREEN}✓ Optimization complete!${NC}"
        printf "Original: %s MB\n" "$((original_size / 1024 / 1024))"
        printf "Optimized: %s MB\n" "$((new_size / 1024 / 1024))"
        
        if [ $new_size -lt $original_size ]; then
            local reduction=$(( (original_size - new_size) * 100 / original_size ))
            printf "Size reduction: %d%%\n" "$reduction"
        elif [ $new_size -gt $original_size ]; then
            local increase=$(( (new_size - original_size) * 100 / original_size ))
            printf "Size increase: %d%% (due to linearization)\n" "$increase"
        else
            echo "Size unchanged"
        fi
        
        echo
        echo "Optimizations applied:"
        echo "  ✓ Linearized for faster web loading"
        echo "  ✓ Object streams preserved for efficiency"
        echo "  ✓ Structure cleaned and validated"
        echo
        echo "Output: $output_pdf"
    else
        echo -e "${RED}✗ Optimization failed${NC}"
        echo "The PDF may be corrupted or have structural issues."
        exit 1
    fi
}

# Main
if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ $# -eq 0 ]; then
    show_help
fi

if [ ! -f "$1" ]; then
    echo -e "${RED}Error: File not found: $1${NC}"
    exit 1
fi

if ! command -v qpdf >/dev/null 2>&1; then
    echo -e "${RED}Error: qpdf not installed${NC}"
    echo "Install with: brew install qpdf"
    exit 1
fi

optimize_pdf "$1"