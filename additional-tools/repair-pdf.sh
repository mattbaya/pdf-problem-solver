#!/bin/bash

# PDF Repair Tool
# Repairs corrupted or damaged PDF files

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo "PDF Repair Tool"
    echo
    echo "Attempts to repair corrupted or damaged PDF files using multiple methods."
    echo
    echo "USAGE:"
    echo "  $0 input.pdf"
    echo
    echo "REPAIR METHODS:"
    echo "  1. qpdf structure repair (preserves maximum data)"
    echo "  2. Ghostscript reconstruction (more aggressive)"
    echo "  3. Combined approach if needed"
    echo
    echo "EXAMPLE:"
    echo "  $0 corrupted.pdf"
    echo
    exit 0
}

repair_pdf() {
    local input_pdf="$1"
    local output_pdf="${input_pdf%.pdf}-repaired.pdf"
    
    echo -e "${CYAN}Analyzing PDF corruption...${NC}"
    
    # Test if file is readable at all
    if ! pdfinfo "$input_pdf" >/dev/null 2>&1; then
        echo -e "${RED}⚠ PDF appears to be severely corrupted${NC}"
        echo "Attempting aggressive repair methods..."
        repair_method="aggressive"
    else
        echo -e "${YELLOW}⚠ PDF has structural issues${NC}"  
        echo "Attempting gentle repair..."
        repair_method="gentle"
    fi
    
    echo
    
    # Method 1: qpdf repair (gentle)
    if [ "$repair_method" = "gentle" ]; then
        echo -e "${CYAN}Method 1: Structure repair with qpdf...${NC}"
        
        if qpdf --qdf --object-streams=preserve "$input_pdf" "$output_pdf" 2>/dev/null; then
            echo -e "${GREEN}✓ Successfully repaired with qpdf${NC}"
            verify_repair "$input_pdf" "$output_pdf"
            return 0
        else
            echo -e "${YELLOW}! qpdf repair failed, trying Ghostscript...${NC}"
        fi
    fi
    
    # Method 2: Ghostscript repair (aggressive)  
    echo -e "${CYAN}Method 2: Reconstruction with Ghostscript...${NC}"
    
    if gs -o "$output_pdf" \
          -sDEVICE=pdfwrite \
          -dPDFSETTINGS=/default \
          -dSAFER \
          -dBATCH \
          -dNOPAUSE \
          -dQUIET \
          "$input_pdf" 2>/dev/null; then
        
        echo -e "${GREEN}✓ Successfully repaired with Ghostscript${NC}"
        verify_repair "$input_pdf" "$output_pdf"
    else
        echo -e "${RED}✗ All repair methods failed${NC}"
        echo "The PDF may be too severely damaged to recover."
        echo
        echo "Suggestions:"
        echo "  • Try opening in different PDF viewers"
        echo "  • Check if you have a backup copy"
        echo "  • Contact the document creator for a new copy"
        return 1
    fi
}

verify_repair() {
    local original="$1"  
    local repaired="$2"
    
    echo
    echo -e "${CYAN}Verifying repair...${NC}"
    
    # Check if repaired PDF is readable
    if pdfinfo "$repaired" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Repaired PDF is readable${NC}"
        
        # Compare page counts
        local orig_pages=$(pdfinfo "$original" 2>/dev/null | grep "Pages:" | awk '{print $2}' || echo "unknown")
        local rep_pages=$(pdfinfo "$repaired" 2>/dev/null | grep "Pages:" | awk '{print $2}')
        
        echo "   Original pages: $orig_pages"
        echo "   Repaired pages: $rep_pages"
        
        if [ "$orig_pages" = "$rep_pages" ] 2>/dev/null; then
            echo -e "${GREEN}✓ Page count matches${NC}"
        elif [ "$orig_pages" = "unknown" ]; then
            echo -e "${YELLOW}! Cannot compare page counts (original too damaged)${NC}"
        else
            echo -e "${YELLOW}! Page count differs - some content may be lost${NC}"
        fi
        
        # Check file sizes
        local orig_size=$(stat -f%z "$original" 2>/dev/null || stat -c%s "$original")
        local rep_size=$(stat -f%z "$repaired" 2>/dev/null || stat -c%s "$repaired")
        
        printf "   Original size: %s MB\n" "$((orig_size / 1024 / 1024))"
        printf "   Repaired size: %s MB\n" "$((rep_size / 1024 / 1024))"
        
        echo
        echo -e "${GREEN}✅ Repair successful!${NC}"
        echo "Output: $repaired"
        echo
        echo "Please verify the repaired PDF contains all expected content."
        
    else
        echo -e "${RED}✗ Repaired PDF is still not readable${NC}"
        rm -f "$repaired"
        return 1
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

if ! command -v gs >/dev/null 2>&1; then
    echo -e "${RED}Error: Ghostscript not installed${NC}" 
    echo "Install with: brew install ghostscript"
    exit 1
fi

repair_pdf "$1"