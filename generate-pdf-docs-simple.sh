#!/bin/bash

# Simple PDF Documentation Generator
# Converts Markdown files to PDF using pandoc

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m' 
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

echo "PDF Documentation Generator"
echo "==========================="
echo

# Check if pandoc and pdflatex are available
if ! command -v pandoc >/dev/null 2>&1; then
    print_error "pandoc not found. Install with: brew install pandoc"
    exit 1
fi

if ! command -v pdflatex >/dev/null 2>&1; then
    print_error "pdflatex not found. Install MacTeX or run: eval \"\$(/usr/libexec/path_helper)\""
    exit 1
fi

print_success "Tools available: pandoc and pdflatex"
echo

# Process each markdown file
convert_file() {
    local md_file="$1"
    local pdf_file="${md_file%.md}.pdf"
    local title="$2"
    
    print_info "Converting: $md_file → $pdf_file"
    
    if pandoc "$md_file" -o "$pdf_file" \
        --pdf-engine=pdflatex \
        --variable geometry:margin=1in \
        --variable fontsize=11pt \
        --variable colorlinks=true \
        --variable linkcolor=blue \
        --toc \
        --metadata title="$title" \
        --metadata author="PDF Problem Solver Toolkit" \
        --metadata date="$(date '+%B %d, %Y')" 2>/dev/null; then
        
        print_success "Created: $pdf_file"
        return 0
    else
        print_error "Failed: $pdf_file"
        return 1
    fi
}

# Convert main documentation files
converted=0
failed=0

# Main README
if [ -f "README.md" ]; then
    if convert_file "README.md" "PDF Problem Solver - User Guide"; then
        converted=$((converted + 1))
    else
        failed=$((failed + 1))
    fi
fi

# Complete toolkit README
if [ -f "COMPLETE-TOOLKIT-README.md" ]; then
    if convert_file "COMPLETE-TOOLKIT-README.md" "Complete Toolkit Documentation"; then
        converted=$((converted + 1))
    else
        failed=$((failed + 1))
    fi
fi

# Development guide
if [ -f "CLAUDE.md" ]; then
    if convert_file "CLAUDE.md" "Development Guide"; then
        converted=$((converted + 1))
    else
        failed=$((failed + 1))
    fi
fi

# Solution summary
if [ -f "SOLUTION-SUMMARY.md" ]; then
    if convert_file "SOLUTION-SUMMARY.md" "Technical Solution Summary"; then
        converted=$((converted + 1))
    else
        failed=$((failed + 1))
    fi
fi

# Toolkit summary
if [ -f "TOOLKIT-SUMMARY.md" ]; then
    if convert_file "TOOLKIT-SUMMARY.md" "Toolkit Overview"; then
        converted=$((converted + 1))
    else
        failed=$((failed + 1))
    fi
fi

# Additional tools documentation
if [ -f "additional-tools/README.md" ]; then
    if convert_file "additional-tools/README.md" "Additional Tools Guide"; then
        converted=$((converted + 1))
    else
        failed=$((failed + 1))
    fi
fi

if [ -f "additional-tools/OCR-TOOLS-SUMMARY.md" ]; then
    if convert_file "additional-tools/OCR-TOOLS-SUMMARY.md" "OCR Tools Summary"; then
        converted=$((converted + 1))
    else
        failed=$((failed + 1))
    fi
fi

echo
print_success "Conversion completed!"
print_info "Successfully converted: $converted files"
if [ $failed -gt 0 ]; then
    print_warning "Failed conversions: $failed files"
fi

echo
print_info "Generated PDF files:"
for pdf in *.pdf; do
    if [ -f "$pdf" ]; then
        echo "  📄 $pdf"
    fi
done
if [ -d "additional-tools" ]; then
    for pdf in additional-tools/*.pdf; do
        if [ -f "$pdf" ]; then
            echo "  📄 $pdf"
        fi
    done
fi

echo
print_info "Academic users can now access all documentation in PDF format!"