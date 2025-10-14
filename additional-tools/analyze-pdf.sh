#!/bin/bash

# PDF Analysis Tool
# Analyzes PDFs for common problems and provides recommendations

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo "PDF Analysis Tool"
    echo
    echo "Analyzes PDFs for common problems and suggests fixes."
    echo
    echo "USAGE:"
    echo "  $0 input.pdf"
    echo
    echo "ANALYZES:"
    echo "  • Font encoding issues (printing problems)"
    echo "  • File size problems"
    echo "  • Security restrictions"
    echo "  • Corruption issues"
    echo "  • Compatibility problems"
    echo "  • Optimization opportunities"
    echo
    echo "EXAMPLE:"
    echo "  $0 document.pdf"
    echo
    exit 0
}

analyze_pdf() {
    local pdf_file="$1"
    local issues=()
    local recommendations=()
    
    echo -e "${BLUE}📊 PDF Analysis Report${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Basic info
    local pdf_info=$(pdfinfo "$pdf_file" 2>/dev/null)
    local file_size=$(stat -f%z "$pdf_file" 2>/dev/null || stat -c%s "$pdf_file")
    local pages=$(echo "$pdf_info" | grep "Pages:" | awk '{print $2}')
    local pdf_version=$(echo "$pdf_info" | grep "PDF version:" | awk '{print $3}')
    
    echo -e "${CYAN}📄 Basic Information${NC}"
    echo "   File: $(basename "$pdf_file")"
    echo "   Size: $(( file_size / 1024 / 1024 )) MB ($file_size bytes)"
    echo "   Pages: $pages"
    echo "   Version: PDF $pdf_version"
    echo
    
    # Font analysis
    echo -e "${CYAN}🔤 Font Analysis${NC}"
    local font_info=$(pdffonts "$pdf_file" 2>/dev/null)
    local custom_fonts=$(echo "$font_info" | grep "Custom" | wc -l)
    local total_fonts=$(echo "$font_info" | tail -n +3 | wc -l)
    
    if [ "$custom_fonts" -gt 0 ]; then
        issues+=("font_encoding")
        recommendations+=("../fix-pdf-fonts-interactive.sh")
        echo -e "   ${RED}⚠ Found $custom_fonts fonts with custom encoding${NC}"
        echo "   This often causes symbols instead of text when printing"
    else
        echo -e "   ${GREEN}✓ All fonts use standard encoding${NC}"
    fi
    
    echo "   Total fonts: $total_fonts"
    echo
    
    # Size analysis
    echo -e "${CYAN}📏 File Size Analysis${NC}"
    local size_mb=$(( file_size / 1024 / 1024 ))
    if [ $size_mb -gt 100 ]; then
        issues+=("large_size")
        recommendations+=("additional-tools/compress-pdf.sh")
        echo -e "   ${RED}⚠ Very large file ($size_mb MB)${NC}"
    elif [ $size_mb -gt 20 ]; then
        issues+=("moderate_size")
        recommendations+=("additional-tools/compress-pdf.sh")
        echo -e "   ${YELLOW}! Large file ($size_mb MB) - compression recommended${NC}"
    else
        echo -e "   ${GREEN}✓ Reasonable file size ($size_mb MB)${NC}"
    fi
    echo
    
    # Security analysis
    echo -e "${CYAN}🔒 Security Analysis${NC}"
    if echo "$pdf_info" | grep -q "Encrypted:.*yes"; then
        issues+=("security")
        recommendations+=("additional-tools/unlock-pdf.sh")
        echo -e "   ${YELLOW}🔐 PDF has security restrictions${NC}"
        
        # Check specific restrictions
        if pdfinfo "$pdf_file" 2>/dev/null | grep -q "print:.*no"; then
            echo "     - Printing disabled"
        fi
        if pdfinfo "$pdf_file" 2>/dev/null | grep -q "copy:.*no"; then
            echo "     - Text copying disabled"
        fi
    else
        echo -e "   ${GREEN}✓ No security restrictions${NC}"
    fi
    echo
    
    # Optimization analysis  
    echo -e "${CYAN}⚡ Optimization Analysis${NC}"
    if echo "$pdf_info" | grep -q "Optimized:.*no"; then
        issues+=("not_optimized")
        recommendations+=("additional-tools/optimize-pdf.sh")
        echo -e "   ${YELLOW}! Not optimized for web viewing${NC}"
    else
        echo -e "   ${GREEN}✓ Optimized for web viewing${NC}"
    fi
    
    if [[ "$pdf_version" > "1.7" ]]; then
        issues+=("version_compatibility")
        recommendations+=("additional-tools/optimize-pdf.sh")
        echo -e "   ${YELLOW}! PDF version $pdf_version may have compatibility issues${NC}"
    else
        echo -e "   ${GREEN}✓ Good version compatibility (PDF $pdf_version)${NC}"
    fi
    echo
    
    # Summary
    echo -e "${BLUE}📋 Summary${NC}"
    if [ ${#issues[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ No significant issues detected!${NC}"
        echo "Your PDF should work well in most situations."
    else
        echo -e "${YELLOW}⚠ Found ${#issues[@]} potential issue(s):${NC}"
        for issue in "${issues[@]}"; do
            case $issue in
                font_encoding) echo "   • Font encoding problems (may cause printing issues)" ;;
                large_size|moderate_size) echo "   • File size could be optimized" ;;
                security) echo "   • Security restrictions present" ;;
                not_optimized) echo "   • Not optimized for web viewing" ;;
                version_compatibility) echo "   • Potential compatibility issues" ;;
            esac
        done
        
        echo
        echo -e "${CYAN}💡 Recommended fixes:${NC}"
        local unique_recommendations=($(printf "%s\n" "${recommendations[@]}" | sort -u))
        for rec in "${unique_recommendations[@]}"; do
            case $rec in
                *fix-pdf-fonts*) echo "   • Fix printing problems: $rec '$pdf_file'" ;;
                *compress*) echo "   • Reduce file size: $rec '$pdf_file'" ;;
                *unlock*) echo "   • Remove restrictions: $rec '$pdf_file'" ;;
                *optimize*) echo "   • Optimize for compatibility: $rec '$pdf_file'" ;;
            esac
        done
    fi
    echo
}

# Main
if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ $# -eq 0 ]; then
    show_help
fi

if [ ! -f "$1" ]; then
    echo -e "${RED}Error: File not found: $1${NC}"
    exit 1
fi

if ! command -v pdfinfo >/dev/null 2>&1; then
    echo -e "${RED}Error: poppler-utils not installed${NC}"
    echo "Install with: brew install poppler"
    exit 1
fi

analyze_pdf "$1"