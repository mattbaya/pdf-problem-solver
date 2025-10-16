#!/bin/bash

# Generate Table of Contents for PDF
# Extracts headlines from PDF and creates a professional TOC page

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo -e "${BLUE}PDF Table of Contents Generator${NC}"
    echo
    echo "Extracts headlines from PDF pages and creates a professional table of contents."
    echo
    echo -e "${CYAN}USAGE:${NC}"
    echo "  $0 input.pdf [options]"
    echo
    echo -e "${CYAN}OPTIONS:${NC}"
    echo "  --output FILE       Output TOC PDF filename (default: input-TOC.pdf)"
    echo "  --prepend           Prepend TOC to the beginning of the PDF"
    echo "  --title TITLE       Document title for TOC header"
    echo "  --help              Show this help"
    echo
    echo -e "${CYAN}EXAMPLES:${NC}"
    echo "  $0 readings.pdf                           # Create TOC PDF"
    echo "  $0 readings.pdf --prepend                 # Add TOC to beginning"
    echo "  $0 readings.pdf --title \"Course Packet\"   # Custom title"
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
    local missing_tools=()

    command -v pdfinfo >/dev/null 2>&1 || missing_tools+=("poppler")
    command -v pdftotext >/dev/null 2>&1 || missing_tools+=("poppler")
    command -v pdftk >/dev/null 2>&1 || missing_tools+=("pdftk-java")
    command -v python3 >/dev/null 2>&1 || missing_tools+=("python3")

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi

    # Check for pdflatex (optional but needed for nice TOC)
    if ! command -v pdflatex >/dev/null 2>&1; then
        print_error "pdflatex not found. Install MacTeX or TeX Live."
        echo "macOS: brew install --cask mactex"
        echo "Linux: sudo apt-get install texlive-full"
        exit 1
    fi
}

# Extract headlines from PDF
extract_headlines() {
    local pdf_file="$1"
    local output_file="$2"

    print_info "Analyzing PDF content and extracting headlines..."

    local total_pages=$(pdfinfo "$pdf_file" | grep "Pages:" | awk '{print $2}')

    # Extract text from each page and identify headlines
    python3 <<'PYTHON_SCRIPT' "$pdf_file" "$output_file" "$total_pages"
import sys
import subprocess
import re

def extract_text_from_page(pdf_file, page_num):
    """Extract text from a specific PDF page"""
    try:
        result = subprocess.run(
            ['pdftotext', '-f', str(page_num), '-l', str(page_num), pdf_file, '-'],
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='ignore'
        )
        return result.stdout
    except:
        return ""

def identify_headline(page_text, page_num):
    """Identify the most likely headline on a page"""
    if not page_text or len(page_text.strip()) < 10:
        return None

    lines = [line.strip() for line in page_text.split('\n') if line.strip()]
    if not lines:
        return None

    # Pattern 1: ALL CAPS titles (common in academic papers)
    for i, line in enumerate(lines[:15]):  # Check first 15 lines
        if (len(line) > 15 and len(line) < 150 and
            line.isupper() and
            not line.startswith('HTTP') and
            '://' not in line and
            not re.match(r'^[\d\s\-\.]+$', line)):  # Not just numbers/dates
            return line.title()  # Convert to title case for readability

    # Pattern 2: Title Case headings
    for i, line in enumerate(lines[:10]):
        # Check if line is mostly title case and reasonable length
        words = line.split()
        if (len(line) > 20 and len(line) < 150 and
            len(words) > 2 and
            sum(1 for w in words if w and w[0].isupper()) >= len(words) * 0.7):
            return line

    # Pattern 3: Chapter/Section markers
    for i, line in enumerate(lines[:8]):
        if re.match(r'^(Chapter|Section|Part|Article)\s+\d+', line, re.IGNORECASE):
            # Get next line as subtitle if available
            if i + 1 < len(lines) and len(lines[i+1]) > 10:
                return f"{line}: {lines[i+1]}"
            return line

    # Pattern 4: First substantial line (fallback)
    for line in lines[:5]:
        if len(line) > 30 and len(line) < 120:
            # Truncate if too long
            if len(line) > 80:
                return line[:77] + "..."
            return line

    return f"Content on Page {page_num}"

def main():
    pdf_file = sys.argv[1]
    output_file = sys.argv[2]
    total_pages = int(sys.argv[3])

    headlines = []

    # Sample pages to find headlines (every 3rd page, plus first/last)
    # This balances accuracy with speed
    pages_to_check = set([1])  # Always check first page
    pages_to_check.update(range(1, min(total_pages + 1, 20)))  # First 20 pages
    pages_to_check.update(range(20, total_pages + 1, 3))  # Every 3rd after that
    pages_to_check.add(total_pages)  # Last page

    for page_num in sorted(pages_to_check):
        text = extract_text_from_page(pdf_file, page_num)
        headline = identify_headline(text, page_num)

        if headline:
            # Clean up headline
            headline = re.sub(r'\s+', ' ', headline).strip()
            # Limit length
            if len(headline) > 100:
                headline = headline[:97] + "..."

            headlines.append((page_num, headline))

        # Progress indicator
        if page_num % 20 == 0:
            print(f"  Processed page {page_num} of {total_pages}...", file=sys.stderr)

    # Write headlines to file
    with open(output_file, 'w', encoding='utf-8') as f:
        for page, headline in headlines:
            # Escape special LaTeX characters
            headline_escaped = headline.replace('&', '\\&').replace('%', '\\%').replace('$', '\\$').replace('#', '\\#').replace('_', '\\_')
            f.write(f"{page}|||{headline_escaped}\n")

    print(f"  Found {len(headlines)} headlines", file=sys.stderr)

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

    print_success "Extracted $(wc -l < "$output_file") headlines"
}

# Generate TOC using LaTeX
generate_toc_pdf() {
    local headlines_file="$1"
    local output_pdf="$2"
    local title="$3"
    local pdf_file="$4"

    print_info "Generating professional Table of Contents..."

    local temp_dir=$(mktemp -d)
    local tex_file="$temp_dir/toc.tex"

    # Get PDF info
    local total_pages=$(pdfinfo "$pdf_file" | grep "Pages:" | awk '{print $2}')

    # Create LaTeX document
    cat > "$tex_file" << 'EOF'
\documentclass[11pt]{article}
\usepackage[letterpaper,margin=0.75in]{geometry}
\usepackage{xcolor}
\usepackage{fontspec}
\usepackage{titlesec}
\usepackage{enumitem}
\setmainfont{Times New Roman}

\definecolor{primarycolor}{RGB}{51,102,153}

\pagestyle{empty}

% Customize section headings
\titleformat{\section}
  {\color{primarycolor}\fontsize{24}{28}\selectfont\bfseries}
  {}{0em}{}

\begin{document}

\section*{Table of Contents}

\vspace{0.3in}

EOF

    # Add title if provided
    if [ -n "$title" ]; then
        echo "{\fontsize{14}{18}\\selectfont" >> "$tex_file"
        echo "\\textbf{$title}\\\\" >> "$tex_file"
        echo "Total Pages: $total_pages" >> "$tex_file"
        echo "}" >> "$tex_file"
        echo "" >> "$tex_file"
        echo "\\vspace{0.2in}" >> "$tex_file"
        echo "" >> "$tex_file"
    fi

    # Add headlines
    echo "\\begin{itemize}[leftmargin=0.5in,itemsep=0.15in]" >> "$tex_file"

    while IFS='|||' read -r page headline; do
        if [ -n "$page" ] && [ -n "$headline" ]; then
            echo "\\item \\textbf{Page $page:} $headline" >> "$tex_file"
        fi
    done < "$headlines_file"

    echo "\\end{itemize}" >> "$tex_file"

    # Close document
    cat >> "$tex_file" << 'EOF'

\vspace{0.5in}

{\footnotesize\color{gray}
\textit{This table of contents was automatically generated by analyzing the document content.}
}

\end{document}
EOF

    # Compile LaTeX to PDF
    print_info "Compiling TOC to PDF..."
    cd "$temp_dir"
    pdflatex -interaction=nonstopmode "toc.tex" >/dev/null 2>&1

    if [ -f "$temp_dir/toc.pdf" ]; then
        mv "$temp_dir/toc.pdf" "$output_pdf"
        print_success "Created Table of Contents: $output_pdf"
    else
        print_error "Failed to generate PDF"
        rm -rf "$temp_dir"
        exit 1
    fi

    rm -rf "$temp_dir"
}

# Main function
main() {
    local pdf_file=""
    local output_file=""
    local prepend=false
    local title=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            --prepend)
                prepend=true
                shift
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            -*)
                print_error "Unknown option: $1"
                exit 1
                ;;
            *)
                if [ -z "$pdf_file" ]; then
                    pdf_file="$1"
                else
                    print_error "Multiple PDF files specified"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$pdf_file" ]; then
        print_error "No PDF file specified"
        echo "Use --help for usage information"
        exit 1
    fi

    if [ ! -f "$pdf_file" ]; then
        print_error "File not found: $pdf_file"
        exit 1
    fi

    # Set default output filename
    if [ -z "$output_file" ]; then
        output_file="${pdf_file%.pdf}-TOC.pdf"
    fi

    # Check dependencies
    check_dependencies

    print_info "Processing: $(basename "$pdf_file")"
    echo

    # Extract headlines
    local temp_headlines=$(mktemp)
    extract_headlines "$pdf_file" "$temp_headlines"

    # Generate TOC PDF
    generate_toc_pdf "$temp_headlines" "$output_file" "$title" "$pdf_file"

    # Prepend to original PDF if requested
    if [ "$prepend" = true ]; then
        print_info "Prepending TOC to original PDF..."
        local temp_combined=$(mktemp).pdf
        pdftk "$output_file" "$pdf_file" cat output "$temp_combined"

        if [ -f "$temp_combined" ]; then
            local final_output="${pdf_file%.pdf}-with-TOC.pdf"
            mv "$temp_combined" "$final_output"
            print_success "Created combined PDF: $final_output"
            rm "$output_file"  # Remove standalone TOC
        else
            print_error "Failed to combine PDFs"
        fi
    fi

    rm -f "$temp_headlines"

    echo
    print_success "Table of Contents generation complete!"
}

main "$@"
