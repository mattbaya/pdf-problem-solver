#!/bin/bash

# Simple PDF Documentation Creator
# Converts Markdown to PDF for academic users

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

echo -e "${BLUE}Creating PDF Documentation for Academic Users${NC}"
echo "=============================================="
echo

# Check tools
if ! command -v pandoc >/dev/null 2>&1; then
    print_error "Installing pandoc..."
    brew install pandoc || exit 1
fi

if ! command -v wkhtmltopdf >/dev/null 2>&1; then
    print_error "Installing wkhtmltopdf..."
    brew install wkhtmltopdf || exit 1
fi

print_success "Tools ready"

# Convert function
convert_to_pdf() {
    local md_file="$1"
    local title="$2"
    local pdf_file="${md_file%.md}.pdf"
    
    print_info "Converting $(basename "$md_file")..."
    
    # Create simple HTML
    local temp_html=$(mktemp).html
    
    cat > "$temp_html" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>$title</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 40px; }
        h1 { color: #2c5aa0; border-bottom: 2px solid #2c5aa0; }
        h2 { color: #2c5aa0; margin-top: 30px; }
        code { background: #f4f4f4; padding: 2px 4px; border-radius: 3px; }
        pre { background: #f8f8f8; border: 1px solid #ddd; padding: 15px; border-radius: 5px; }
        blockquote { border-left: 4px solid #2c5aa0; margin: 0; padding-left: 20px; font-style: italic; }
    </style>
</head>
<body>
    <div style="text-align:center; padding:20px; background:#f0f8ff; border-radius:10px; margin-bottom:30px;">
        <h1>$title</h1>
        <p><strong>PDF Problem Solver Toolkit</strong></p>
        <p>$(date '+%B %d, %Y')</p>
    </div>
EOF
    
    # Convert markdown content and append
    pandoc "$md_file" -t html >> "$temp_html"
    
    echo "</body></html>" >> "$temp_html"
    
    # Convert to PDF
    if wkhtmltopdf --page-size Letter --margin-top 0.75in --margin-bottom 0.75in \
        --margin-left 0.75in --margin-right 0.75in --quiet \
        "$temp_html" "$pdf_file" 2>/dev/null; then
        print_success "Created $(basename "$pdf_file")"
        rm "$temp_html"
        return 0
    else
        print_error "Failed $(basename "$pdf_file")"
        rm "$temp_html"
        return 1
    fi
}

# Convert all documentation
converted=0
total=0

files=(
    "README.md|User Guide"
    "COMPLETE-TOOLKIT-README.md|Complete Documentation"  
    "CLAUDE.md|Development Guide"
    "SOLUTION-SUMMARY.md|Technical Summary"
    "TOOLKIT-SUMMARY.md|Toolkit Overview"
)

if [ -d "additional-tools" ]; then
    files+=(
        "additional-tools/README.md|Additional Tools Guide"
        "additional-tools/OCR-TOOLS-SUMMARY.md|OCR Tools Guide"
    )
fi

for file_info in "${files[@]}"; do
    file="${file_info%|*}"
    title="${file_info#*|}"
    
    if [ -f "$file" ]; then
        total=$((total + 1))
        if convert_to_pdf "$file" "$title"; then
            converted=$((converted + 1))
        fi
    fi
done

echo
print_success "Completed: $converted of $total files converted"

if [ $converted -gt 0 ]; then
    echo
    print_info "📚 Generated PDF Documentation:"
    
    for file_info in "${files[@]}"; do
        file="${file_info%|*}"
        pdf="${file%.md}.pdf"
        if [ -f "$pdf" ]; then
            echo "   📄 $(basename "$pdf")"
        fi
    done
    
    echo
    print_info "🎓 Academic users can now access all documentation as PDFs!"
    print_info "💡 Both .md and .pdf versions available for all guides"
fi