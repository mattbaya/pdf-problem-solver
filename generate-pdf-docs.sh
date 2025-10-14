#!/bin/bash

# PDF Documentation Generator
# Converts all Markdown documentation to professional PDFs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      PDF Documentation Generator        ║${NC}"
    echo -e "${BLUE}║   Convert Markdown to Professional PDF  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo
}

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

print_step() {
    echo -e "${MAGENTA}▶ $1${NC}"
}

# Check and install dependencies
check_dependencies() {
    local missing_tools=()
    
    # Check for pandoc (best markdown to PDF converter)
    command -v pandoc >/dev/null 2>&1 || missing_tools+=("pandoc")
    
    # Check for LaTeX (needed for pandoc PDF generation)
    command -v pdflatex >/dev/null 2>&1 || missing_tools+=("mactex")
    
    # Check for wkhtmltopdf as fallback
    command -v wkhtmltopdf >/dev/null 2>&1 || missing_tools+=("wkhtmltopdf")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_warning "Installing documentation tools: ${missing_tools[*]}"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ! command -v brew >/dev/null 2>&1; then
                print_error "Homebrew required for installation"
                exit 1
            fi
            
            for tool in "${missing_tools[@]}"; do
                case $tool in
                    pandoc)
                        print_info "Installing Pandoc (universal document converter)..."
                        brew install pandoc
                        ;;
                    mactex)
                        print_info "Installing MacTeX (may take several minutes)..."
                        print_info "This is needed for high-quality PDF generation"
                        brew install --cask mactex
                        ;;
                    wkhtmltopdf)
                        print_info "Installing wkhtmltopdf (HTML to PDF converter)..."
                        brew install wkhtmltopdf
                        ;;
                esac
            done
            
            print_success "Documentation tools installed"
        else
            print_error "Please install missing tools:"
            echo "  Ubuntu/Debian: sudo apt-get install pandoc texlive-latex-base wkhtmltopdf"
            echo "  CentOS/RHEL: sudo yum install pandoc texlive wkhtmltopdf"
            exit 1
        fi
    else
        print_success "All documentation tools available"
    fi
}

# Convert markdown to PDF using pandoc
convert_with_pandoc() {
    local md_file="$1"
    local pdf_file="$2"
    local title="$3"
    
    # Create enhanced markdown with better formatting
    local temp_md=$(mktemp)
    
    # Add title and styling
    cat > "$temp_md" << EOF
---
title: "$title"
author: "PDF Problem Solver Toolkit"
date: "$(date '+%B %d, %Y')"
geometry: margin=1in
fontsize: 11pt
linestretch: 1.2
header-includes:
  - \\usepackage{fancyhdr}
  - \\pagestyle{fancy}
  - \\fancyhead[L]{PDF Problem Solver Toolkit}
  - \\fancyhead[R]{$title}
  - \\fancyfoot[C]{\\thepage}
---

EOF
    
    # Process the markdown content
    cat "$md_file" | sed 's/^# /## /' | sed '1s/^## /# /' >> "$temp_md"
    
    # Convert with pandoc
    if pandoc "$temp_md" -o "$pdf_file" \
        --pdf-engine=pdflatex \
        --variable colorlinks=true \
        --variable linkcolor=blue \
        --variable urlcolor=blue \
        --variable toccolor=blue \
        --toc \
        --number-sections 2>/dev/null; then
        
        print_success "Created with Pandoc: $pdf_file"
        rm "$temp_md"
        return 0
    else
        rm "$temp_md"
        return 1
    fi
}

# Fallback: Convert using HTML intermediate
convert_with_html() {
    local md_file="$1"  
    local pdf_file="$2"
    local title="$3"
    
    local temp_html=$(mktemp --suffix=.html)
    
    # Create professional HTML
    cat > "$temp_html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>TITLE_PLACEHOLDER</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 { 
            color: #2c5aa0; 
            border-bottom: 3px solid #2c5aa0; 
            padding-bottom: 10px;
        }
        h2 { 
            color: #2c5aa0; 
            margin-top: 30px;
        }
        h3 { 
            color: #5a6c7d; 
        }
        code {
            background: #f4f4f4;
            padding: 2px 5px;
            border-radius: 3px;
            font-family: 'Monaco', 'Consolas', monospace;
        }
        pre {
            background: #f8f8f8;
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
            overflow-x: auto;
        }
        blockquote {
            border-left: 4px solid #2c5aa0;
            margin: 0;
            padding-left: 20px;
            font-style: italic;
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
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 10px;
        }
        .footer {
            margin-top: 40px;
            padding: 20px;
            text-align: center;
            background: #f8f9fa;
            border-radius: 5px;
            font-size: 14px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>TITLE_PLACEHOLDER</h1>
        <p>PDF Problem Solver Toolkit Documentation</p>
        <p>Generated on DATE_PLACEHOLDER</p>
    </div>
    
    <div class="content">
CONTENT_PLACEHOLDER
    </div>
    
    <div class="footer">
        Generated by PDF Problem Solver Toolkit<br>
        For the latest version, visit the project directory
    </div>
</body>
</html>
EOF
    
    # Convert markdown to HTML and insert
    local html_content=""
    if command -v pandoc >/dev/null 2>&1; then
        html_content=$(pandoc "$md_file" -t html)
    else
        # Basic markdown to HTML (simplified)
        html_content=$(cat "$md_file" | \
            sed 's/^# \(.*\)/<h1>\1<\/h1>/' | \
            sed 's/^## \(.*\)/<h2>\1<\/h2>/' | \
            sed 's/^### \(.*\)/<h3>\1<\/h3>/' | \
            sed 's/^\*\*\(.*\)\*\*/<strong>\1<\/strong>/g' | \
            sed 's/^\*\(.*\)\*/<em>\1<\/em>/g' | \
            sed 's/^- \(.*\)/<li>\1<\/li>/' | \
            sed 's/^```/<pre><code>/' | \
            sed 's/```$/<\/code><\/pre>/' | \
            sed 's/`\([^`]*\)`/<code>\1<\/code>/g')
    fi
    
    # Replace placeholders
    sed "s/TITLE_PLACEHOLDER/$title/g" "$temp_html" | \
    sed "s/DATE_PLACEHOLDER/$(date '+%B %d, %Y')/g" | \
    sed "s/CONTENT_PLACEHOLDER/$html_content/" > "${temp_html}.final"
    
    # Convert HTML to PDF
    if wkhtmltopdf --page-size Letter --margin-top 0.75in --margin-bottom 0.75in \
        --margin-left 0.75in --margin-right 0.75in \
        "${temp_html}.final" "$pdf_file" 2>/dev/null; then
        
        print_success "Created with HTML converter: $pdf_file"
        rm "$temp_html" "${temp_html}.final"
        return 0
    else
        rm "$temp_html" "${temp_html}.final"
        return 1
    fi
}

# Process a single markdown file
process_markdown_file() {
    local md_file="$1"
    local base_name=$(basename "$md_file" .md)
    local pdf_file="${md_file%.md}.pdf"
    
    # Determine title from filename
    local title="$base_name"
    case "$base_name" in
        "README") title="PDF Problem Solver Toolkit - User Guide" ;;
        "COMPLETE-TOOLKIT-README") title="Complete Toolkit Documentation" ;;
        "CLAUDE") title="Project Development Guide" ;;
        "SOLUTION-SUMMARY") title="Technical Solution Summary" ;;
        "TOOLKIT-SUMMARY") title="Toolkit Overview" ;;
        "OCR-TOOLS-SUMMARY") title="OCR and Indexing Tools Guide" ;;
        *) title=$(echo "$base_name" | sed 's/-/ /g' | sed 's/\b\w/\U&/g') ;;
    esac
    
    print_step "Converting: $md_file → $pdf_file"
    
    # Try pandoc first (best quality)
    if command -v pandoc >/dev/null 2>&1 && command -v pdflatex >/dev/null 2>&1; then
        if convert_with_pandoc "$md_file" "$pdf_file" "$title"; then
            return 0
        fi
    fi
    
    # Fallback to HTML method
    if convert_with_html "$md_file" "$pdf_file" "$title"; then
        return 0
    fi
    
    print_error "Failed to convert: $md_file"
    return 1
}

# Main function
main() {
    print_header
    
    # Check dependencies
    check_dependencies
    
    echo
    print_info "Finding Markdown documentation files..."
    
    # Find all markdown files
    local md_files=()
    
    # Main directory
    for md_file in *.md; do
        if [ -f "$md_file" ]; then
            md_files+=("$md_file")
        fi
    done
    
    # Additional tools directory
    if [ -d "additional-tools" ]; then
        for md_file in additional-tools/*.md; do
            if [ -f "$md_file" ]; then
                md_files+=("$md_file")
            fi
        done
    fi
    
    if [ ${#md_files[@]} -eq 0 ]; then
        print_warning "No Markdown files found"
        exit 0
    fi
    
    print_info "Found ${#md_files[@]} Markdown files to convert"
    echo
    
    local converted=0
    local failed=0
    
    # Process each file
    for md_file in "${md_files[@]}"; do
        if process_markdown_file "$md_file"; then
            converted=$((converted + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    echo
    print_success "Documentation conversion completed!"
    print_info "Successfully converted: $converted files"
    if [ $failed -gt 0 ]; then
        print_warning "Failed conversions: $failed files"
    fi
    
    echo
    print_info "PDF documentation files created:"
    for md_file in "${md_files[@]}"; do
        local pdf_file="${md_file%.md}.pdf"
        if [ -f "$pdf_file" ]; then
            echo "  📄 $pdf_file"
        fi
    done
    
    echo
    print_info "Users can now access documentation in PDF format!"
    print_info "Both .md and .pdf versions are available for all guides."
}

# Run the script
main "$@"