#!/bin/bash

# Generate Professional Cover Sheet for PDF
# Creates a customizable cover page with optional logo

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo -e "${BLUE}PDF Cover Sheet Generator${NC}"
    echo
    echo "Creates a professional cover sheet for PDF documents."
    echo
    echo -e "${CYAN}USAGE:${NC}"
    echo "  $0 --output FILE [options]"
    echo
    echo -e "${CYAN}OPTIONS:${NC}"
    echo "  --output FILE       Output cover sheet PDF filename"
    echo "  --title TITLE       Document title"
    echo "  --author AUTHOR     Author name"
    echo "  --subtitle TEXT     Subtitle or description"
    echo "  --date DATE         Date (default: current date)"
    echo "  --contact INFO      Contact information"
    echo "  --logo FILE         Logo image file (PNG, JPG, PDF)"
    echo "  --help              Show this help"
    echo
    echo -e "${CYAN}EXAMPLES:${NC}"
    echo "  $0 --output cover.pdf --title \"Course Readings\" --author \"Prof. Smith\""
    echo "  $0 --output cover.pdf --title \"Report\" --logo logo.png --date \"2025\""
    echo
    exit 0
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check dependencies
check_dependencies() {
    if ! command -v pdflatex >/dev/null 2>&1; then
        print_error "pdflatex not found. Install MacTeX or TeX Live."
        echo "macOS: brew install --cask mactex"
        echo "Linux: sudo apt-get install texlive-full"
        exit 1
    fi
}

# Escape LaTeX special characters
escape_latex() {
    local text="$1"
    # Escape special LaTeX characters
    text="${text//\\/\\textbackslash}"
    text="${text//&/\\&}"
    text="${text//%/\\%}"
    text="${text//\$/\\$}"
    text="${text//#/\\#}"
    text="${text//_/\\_}"
    text="${text//\{/\\{}"
    text="${text//\}/\\}}"
    text="${text//~/\\textasciitilde}"
    text="${text//^/\\textasciicircum}"
    echo "$text"
}

# Generate cover sheet
generate_cover_sheet() {
    local output_pdf="$1"
    local title="$2"
    local author="$3"
    local subtitle="$4"
    local date_text="$5"
    local contact="$6"
    local logo="$7"

    print_info "Generating cover sheet..."

    local temp_dir=$(mktemp -d)
    local tex_file="$temp_dir/cover.tex"

    # Escape all inputs for LaTeX
    title=$(escape_latex "$title")
    author=$(escape_latex "$author")
    subtitle=$(escape_latex "$subtitle")
    date_text=$(escape_latex "$date_text")
    contact=$(escape_latex "$contact")

    # Start LaTeX document
    cat > "$tex_file" << 'EOF'
\documentclass[12pt]{article}
\usepackage[letterpaper,margin=1in]{geometry}
\usepackage{xcolor}
\usepackage{fontspec}
\usepackage{graphicx}
\usepackage{tikz}
\setmainfont{Times New Roman}

\definecolor{primarycolor}{RGB}{51,102,153}
\definecolor{secondarycolor}{RGB}{100,100,100}

\pagestyle{empty}

\begin{document}

% Title page layout
\begin{center}

EOF

    # Add logo if provided
    if [ -n "$logo" ] && [ -f "$logo" ]; then
        print_info "Including logo: $(basename "$logo")"

        # Copy logo to temp directory
        local logo_ext="${logo##*.}"
        local logo_copy="$temp_dir/logo.$logo_ext"
        cp "$logo" "$logo_copy"

        # Convert to PDF if it's an image
        if [[ "$logo_ext" =~ ^(png|jpg|jpeg)$ ]]; then
            if command -v convert >/dev/null 2>&1; then
                convert "$logo_copy" "$temp_dir/logo.pdf" 2>/dev/null || cp "$logo_copy" "$temp_dir/logo.pdf"
            fi
        fi

        echo "\\vspace{0.5in}" >> "$tex_file"
        echo "\\includegraphics[width=0.5\\textwidth,height=2.5in,keepaspectratio]{logo.$logo_ext}" >> "$tex_file"
        echo "\\vspace{0.5in}" >> "$tex_file"
    else
        echo "\\vspace{2in}" >> "$tex_file"
    fi

    # Add title
    echo "" >> "$tex_file"
    echo "{\\color{primarycolor} \\fontsize{28}{34}\\selectfont \\textbf{$title}}" >> "$tex_file"
    echo "" >> "$tex_file"
    echo "\\vspace{0.3in}" >> "$tex_file"
    echo "" >> "$tex_file"

    # Add subtitle if provided
    if [ -n "$subtitle" ]; then
        echo "{\\fontsize{16}{20}\\selectfont" >> "$tex_file"
        echo "\\textit{$subtitle}" >> "$tex_file"
        echo "}" >> "$tex_file"
        echo "" >> "$tex_file"
        echo "\\vspace{0.3in}" >> "$tex_file"
        echo "" >> "$tex_file"
    fi

    # Add author if provided
    if [ -n "$author" ]; then
        echo "{\\fontsize{14}{18}\\selectfont" >> "$tex_file"
        echo "\\textbf{$author}" >> "$tex_file"
        echo "}" >> "$tex_file"
        echo "" >> "$tex_file"
        echo "\\vspace{0.2in}" >> "$tex_file"
        echo "" >> "$tex_file"
    fi

    # Add date
    if [ -n "$date_text" ]; then
        echo "{\\fontsize{12}{16}\\selectfont" >> "$tex_file"
        echo "{\\color{secondarycolor} $date_text}" >> "$tex_file"
        echo "}" >> "$tex_file"
        echo "" >> "$tex_file"
    fi

    # Add contact info at bottom
    if [ -n "$contact" ]; then
        echo "\\vfill" >> "$tex_file"
        echo "" >> "$tex_file"
        echo "{\\fontsize{11}{14}\\selectfont" >> "$tex_file"
        echo "{\\color{secondarycolor}" >> "$tex_file"
        echo "$contact" >> "$tex_file"
        echo "}" >> "$tex_file"
        echo "}" >> "$tex_file"
        echo "" >> "$tex_file"
    fi

    # Close document
    cat >> "$tex_file" << 'EOF'

\end{center}

\end{document}
EOF

    # Compile LaTeX to PDF
    print_info "Compiling cover sheet to PDF..."
    cd "$temp_dir"
    pdflatex -interaction=nonstopmode "cover.tex" >/dev/null 2>&1

    if [ -f "$temp_dir/cover.pdf" ]; then
        cp "$temp_dir/cover.pdf" "$output_pdf"
        print_success "Created cover sheet: $(basename "$output_pdf")"
    else
        print_error "Failed to generate cover sheet PDF"
        # Show LaTeX log for debugging
        if [ -f "$temp_dir/cover.log" ]; then
            echo "LaTeX log:"
            tail -20 "$temp_dir/cover.log"
        fi
        rm -rf "$temp_dir"
        exit 1
    fi

    rm -rf "$temp_dir"
}

# Extract title from PDF
extract_pdf_title() {
    local pdf_file="$1"

    # Try to get title from PDF metadata
    if command -v pdfinfo >/dev/null 2>&1; then
        local metadata_title=$(pdfinfo "$pdf_file" 2>/dev/null | grep "Title:" | sed 's/Title:[[:space:]]*//')
        if [ -n "$metadata_title" ] && [ "$metadata_title" != "Untitled" ]; then
            echo "$metadata_title"
            return
        fi
    fi

    # Try to extract first substantial line from page 1
    if command -v pdftotext >/dev/null 2>&1; then
        local first_page_title=$(pdftotext -f 1 -l 1 "$pdf_file" - 2>/dev/null | head -20 | grep -v "^$" | grep -v "^[[:space:]]*$" | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        if [ -n "$first_page_title" ] && [ ${#first_page_title} -gt 5 ] && [ ${#first_page_title} -lt 150 ]; then
            echo "$first_page_title"
            return
        fi
    fi

    # Fallback to filename
    basename "$pdf_file" .pdf
}

# Main function
main() {
    local output_pdf=""
    local title=""
    local author=""
    local subtitle=""
    local date_text=""
    local contact=""
    local logo=""
    local source_pdf=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                ;;
            --output)
                output_pdf="$2"
                shift 2
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            --author)
                author="$2"
                shift 2
                ;;
            --subtitle)
                subtitle="$2"
                shift 2
                ;;
            --date)
                date_text="$2"
                shift 2
                ;;
            --contact)
                contact="$2"
                shift 2
                ;;
            --logo)
                logo="$2"
                shift 2
                ;;
            --source-pdf)
                source_pdf="$2"
                shift 2
                ;;
            -*)
                print_error "Unknown option: $1"
                exit 1
                ;;
            *)
                print_error "Unexpected argument: $1"
                exit 1
                ;;
        esac
    done

    if [ -z "$output_pdf" ]; then
        print_error "Output file not specified (use --output)"
        echo "Use --help for usage information"
        exit 1
    fi

    # Auto-extract title if not provided and source PDF is given
    if [ -z "$title" ] && [ -n "$source_pdf" ] && [ -f "$source_pdf" ]; then
        print_info "Extracting title from source PDF..."
        title=$(extract_pdf_title "$source_pdf")
        print_info "Detected title: $title"
    fi

    # Use defaults if not provided
    if [ -z "$title" ]; then
        title="Document"
    fi

    if [ -z "$date_text" ]; then
        date_text=$(date "+%B %Y")
    fi

    # Check dependencies
    check_dependencies

    # Generate cover sheet
    generate_cover_sheet "$output_pdf" "$title" "$author" "$subtitle" "$date_text" "$contact" "$logo"

    print_success "Cover sheet generation complete!"
}

main "$@"
