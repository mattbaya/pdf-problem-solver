#!/bin/bash

# Academic PDF Documentation Generator
# Creates professional PDF documentation from Markdown files

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

echo -e "${BLUE}PDF Documentation Generator for Academic Users${NC}"
echo "=============================================="
echo

# Check dependencies
if ! command -v pandoc >/dev/null 2>&1; then
    print_error "pandoc required. Install: brew install pandoc"
    exit 1
fi

if ! command -v wkhtmltopdf >/dev/null 2>&1; then
    print_error "wkhtmltopdf required. Install: brew install wkhtmltopdf"
    exit 1
fi

print_success "Documentation tools available"
echo

# Convert markdown to PDF via HTML (handles Unicode better)
convert_md_to_pdf() {
    local md_file="$1"
    local title="$2"
    local pdf_file="${md_file%.md}.pdf"
    
    print_info "Converting: $(basename "$md_file")"
    
    # Create temporary HTML file
    local temp_html=$(mktemp).html
    
    # Convert markdown to HTML with pandoc
    pandoc "$md_file" -o "$temp_html" \
        --standalone \
        --css=/dev/null \
        --metadata title="$title" \
        --metadata author="PDF Problem Solver Toolkit" \
        --metadata date="$(date '+%B %d, %Y')" \
        --template=<(cat << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>$title$</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        h1 { 
            color: #2c5aa0; 
            border-bottom: 3px solid #2c5aa0; 
            padding-bottom: 10px;
            text-align: center;
        }
        h2 { 
            color: #2c5aa0; 
            margin-top: 30px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }
        h3 { 
            color: #5a6c7d; 
            margin-top: 25px;
        }
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Monaco', 'Consolas', monospace;
            font-size: 0.9em;
        }
        pre {
            background: #f8f8f8;
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
            overflow-x: auto;
            font-size: 0.9em;
        }
        pre code {
            background: none;
            padding: 0;
        }
        blockquote {
            border-left: 4px solid #2c5aa0;
            margin: 20px 0;
            padding-left: 20px;
            font-style: italic;
            background: #f9f9f9;
            padding: 10px 20px;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 8px 12px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
        ul, ol {
            margin: 10px 0;
            padding-left: 30px;
        }
        li {
            margin: 5px 0;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 10px;
        }
        .header h1 {
            color: white;
            border: none;
            margin: 0;
        }
        .footer {
            margin-top: 40px;
            padding: 15px;
            text-align: center;
            background: #f8f9fa;
            border-radius: 5px;
            font-size: 14px;
            color: #666;
        }
        strong {
            color: #2c5aa0;
        }
        em {
            color: #5a6c7d;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>$title$</h1>
        <p><strong>PDF Problem Solver Toolkit</strong></p>
        <p>Generated on $date$</p>
    </div>
    
    $body$
    
    <div class="footer">
        <strong>PDF Problem Solver Toolkit</strong><br>
        Professional PDF processing solutions for academic and business use
    </div>
</body>
</html>
EOF
) 2>/dev/null
    
    # Convert HTML to PDF
    if wkhtmltopdf --page-size Letter \
        --margin-top 0.75in --margin-bottom 0.75in \
        --margin-left 0.75in --margin-right 0.75in \
        --print-media-type \
        --disable-smart-shrinking \
        "$temp_html" "$pdf_file" >/dev/null 2>&1; then
        
        print_success "Created: $(basename "$pdf_file")"
        rm "$temp_html"
        return 0
    else
        print_error "Failed: $(basename "$pdf_file")"
        rm "$temp_html"
        return 1
    fi
}

# Generate PDFs for all documentation
total=0
converted=0

docs=(
    "README.md:User Guide - Getting Started"
    "COMPLETE-TOOLKIT-README.md:Complete Documentation"
    "CLAUDE.md:Development Guide"
    "SOLUTION-SUMMARY.md:Technical Solution Details"  
    "TOOLKIT-SUMMARY.md:Toolkit Overview"
)

if [ -d "additional-tools" ]; then
    docs+=(
        "additional-tools/README.md:Additional Tools Guide"
        "additional-tools/OCR-TOOLS-SUMMARY.md:OCR and Indexing Tools"
    )
fi

for doc in "${docs[@]}"; do
    file="${doc%:*}"
    title="${doc#*:}"
    
    if [ -f "$file" ]; then
        total=$((total + 1))
        if convert_md_to_pdf "$file" "$title"; then
            converted=$((converted + 1))
        fi
    fi
done

echo
print_success "PDF Generation Complete!"
echo "Successfully converted: $converted of $total files"

echo
print_info "📚 Available PDF Documentation:"

# List generated PDFs
for doc in "${docs[@]}"; do
    file="${doc%:*}"
    pdf_file="${file%.md}.pdf"
    
    if [ -f "$pdf_file" ]; then
        echo "   📄 $(basename "$pdf_file")"
    fi
done

echo
print_info "🎓 Academic users can now:"
echo "   • Read all documentation in PDF format"
echo "   • Print guides for offline reference"  
echo "   • Share documentation easily"
echo "   • Access formatted guides on any device"

echo
print_info "💡 Both .md and .pdf versions are maintained"
print_info "   Use .pdf for reading, .md for development"