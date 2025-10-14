#!/bin/bash

# Professional PDF Documentation Generator
# Uses MacTeX for publication-quality academic documentation

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

echo -e "${BLUE}Professional PDF Documentation Generator${NC}"
echo "========================================="
echo

# Update PATH for MacTeX
eval "$(/usr/libexec/path_helper)" 2>/dev/null || true

# Check dependencies
check_tools() {
    local missing=()
    
    command -v pandoc >/dev/null 2>&1 || missing+=("pandoc")
    command -v xelatex >/dev/null 2>&1 || missing+=("mactex")
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing tools: ${missing[*]}"
        print_info "Install with: brew install pandoc && brew install --cask mactex"
        exit 1
    fi
    
    print_success "Professional tools available (pandoc + XeLaTeX)"
}

# Create inline LaTeX template with Unicode support
generate_pdf_with_xelatex() {
    local md_file="$1"
    local title="$2" 
    local pdf_file="${md_file%.md}.pdf"
    
    print_info "Creating professional PDF: $(basename "$pdf_file")"
    
    # Use pandoc with inline template and XeLaTeX
    if pandoc "$md_file" -o "$pdf_file" \
        --pdf-engine=xelatex \
        --variable mainfont="Times New Roman" \
        --variable sansfont="Arial" \
        --variable monofont="Courier New" \
        --variable geometry:margin=1in \
        --variable fontsize=11pt \
        --variable linestretch=1.2 \
        --variable colorlinks=true \
        --variable linkcolor=blue \
        --variable urlcolor=blue \
        --variable title="$title" \
        --variable author="PDF Problem Solver Toolkit" \
        --variable date="$(date '+%B %d, %Y')" \
        --table-of-contents \
        --number-sections \
        --highlight-style=tango \
        -V 'header-includes=\usepackage{fancyhdr}\pagestyle{fancy}\fancyhead[L]{PDF Problem Solver Toolkit}\fancyhead[R]{'$title'}\fancyfoot[C]{\thepage}\usepackage{xcolor}\definecolor{titlecolor}{RGB}{44,90,160}' 2>/dev/null; then
        
        print_success "Created professional PDF: $(basename "$pdf_file")"
        return 0
    else
        print_warning "XeLaTeX method failed, trying pdfLaTeX with Unicode substitution..."
        
        # Fallback: Create Unicode-safe version
        local temp_md=$(mktemp).md
        
        # Replace Unicode symbols with LaTeX-compatible versions
        cat "$md_file" | \
        sed 's/✓/\\textcolor{green}{[CHECK]}/g' | \
        sed 's/✗/\\textcolor{red}{[X]}/g' | \
        sed 's/⚠/\\textcolor{orange}{[WARNING]}/g' | \
        sed 's/ℹ/\\textcolor{blue}{[INFO]}/g' | \
        sed 's/▶/\\textcolor{purple}{>}/g' | \
        sed 's/✦/*/g; s/⌘/[CMD]/g; s/☃/[SNOWMAN]/g' | \
        sed 's/🎯/[TARGET]/g; s/🔧/[TOOLS]/g; s/📦/[PACKAGE]/g' | \
        sed 's/🔍/[SEARCH]/g; s/📚/[BOOKS]/g; s/📄/[DOC]/g' | \
        sed 's/🎨/[ART]/g; s/⚡/[LIGHTNING]/g' > "$temp_md"
        
        if pandoc "$temp_md" -o "$pdf_file" \
            --pdf-engine=pdflatex \
            --variable geometry:margin=1in \
            --variable fontsize=11pt \
            --variable colorlinks=true \
            --variable linkcolor=blue \
            --variable title="$title" \
            --variable author="PDF Problem Solver Toolkit" \
            --variable date="$(date '+%B %d, %Y')" \
            --table-of-contents \
            --number-sections \
            -V 'header-includes=\\usepackage{fancyhdr}\\pagestyle{fancy}\\fancyhead[L]{PDF Problem Solver Toolkit}\\fancyhead[R]{'$title'}\\fancyfoot[C]{\\thepage}\\usepackage{xcolor}' 2>/dev/null; then
            
            print_success "Created PDF with fallback method: $(basename "$pdf_file")"
            rm "$temp_md"
            return 0
        else
            print_error "Both methods failed for: $(basename "$pdf_file")"
            rm "$temp_md"
            return 1
        fi
    fi
}

# Enhanced cover sheet generation using LaTeX
create_latex_cover_sheet() {
    local title="$1"
    local course="$2"
    local professor="$3"
    local term="$4"
    local output="$5"
    
    print_info "Creating professional LaTeX cover sheet..."
    
    local tex_file=$(mktemp).tex
    
    cat > "$tex_file" << EOF
\\documentclass[12pt]{article}
\\usepackage[letterpaper,margin=0.75in]{geometry}
\\usepackage{xcolor}
\\usepackage{tikz}
\\usepackage{fontspec}
\\setmainfont{Times New Roman}
\\setsansfont{Arial}

\\definecolor{universityblue}{RGB}{25,74,135}
\\definecolor{accentgray}{RGB}{128,128,128}

\\pagestyle{empty}

\\begin{document}

\\begin{center}

% University header
\\vspace{0.5in}
{\\color{universityblue} \\fontsize{18}{22}\\selectfont \\textbf{ACADEMIC COURSE MATERIALS}}

\\vspace{0.3in}
\\rule{4in}{2pt}

\\vspace{0.8in}

% Main title
{\\color{universityblue} \\fontsize{28}{34}\\selectfont \\textbf{$title}}

\\vspace{0.4in}

% Course information box
\\begin{tikzpicture}
\\draw[universityblue, thick, rounded corners=8pt] (-3, -1.5) rectangle (3, 1.5);
\\fill[universityblue!10, rounded corners=8pt] (-3, -1.5) rectangle (3, 1.5);
\\end{tikzpicture}

\\vspace{-2.5in}

\\begin{minipage}{4.5in}
\\centering

\\vspace{0.3in}
{\\fontsize{20}{24}\\selectfont \\textbf{$course}}

\\vspace{0.2in}
{\\fontsize{16}{20}\\selectfont $professor}

\\vspace{0.1in}
{\\color{accentgray} \\fontsize{14}{18}\\selectfont $term}

\\vspace{0.3in}

\\end{minipage}

\\vfill

% Footer
{\\color{accentgray} \\fontsize{12}{14}\\selectfont 
Generated by PDF Problem Solver Toolkit \\\\
$(date '+%B %d, %Y')}

\\end{center}

\\end{document}
EOF
    
    # Compile with XeLaTeX
    local temp_dir=$(dirname "$tex_file")
    local base_name=$(basename "$tex_file" .tex)
    
    cd "$temp_dir"
    
    if xelatex -interaction=nonstopmode "$tex_file" >/dev/null 2>&1; then
        cp "${base_name}.pdf" "$output"
        print_success "Professional LaTeX cover created: $(basename "$output")"
        
        # Cleanup
        rm -f "${base_name}".{tex,pdf,aux,log}
        return 0
    else
        print_error "LaTeX cover compilation failed"
        rm -f "$tex_file"
        return 1
    fi
}

# Main function
main() {
    check_tools
    
    echo
    print_info "Generating professional academic documentation..."
    
    local converted=0
    local total=0
    
    # Document list with professional titles
    local docs=(
        "README.md:User Guide - Getting Started with PDF Problem Solver"
        "COMPLETE-TOOLKIT-README.md:Complete Professional Documentation"
        "CLAUDE.md:Developer Guide - Project Architecture and Standards"
        "SOLUTION-SUMMARY.md:Technical Implementation Summary"
        "TOOLKIT-SUMMARY.md:Comprehensive Feature Overview"
        "ENHANCED-LATEX-FEATURES.md:Advanced LaTeX Integration Guide"
    )
    
    # Add additional tools documentation
    if [ -d "additional-tools" ]; then
        docs+=(
            "additional-tools/README.md:Additional Tools Reference Manual"
            "additional-tools/OCR-TOOLS-SUMMARY.md:OCR and Academic Processing Guide"
        )
    fi
    
    # Generate PDFs
    for doc in "${docs[@]}"; do
        local file="${doc%:*}"
        local title="${doc#*:}"
        
        if [ -f "$file" ]; then
            total=$((total + 1))
            if generate_pdf_with_xelatex "$file" "$title"; then
                converted=$((converted + 1))
            fi
        fi
    done
    
    # Create sample professional cover sheet
    print_info "Creating sample professional cover sheet..."
    if create_latex_cover_sheet \
        "PDF Problem Solver Toolkit" \
        "Professional Documentation Suite" \
        "Academic Computing Services" \
        "$(date '+%B %Y')" \
        "Professional-Cover-Sample.pdf"; then
        echo
        print_info "📋 Sample cover sheet demonstrates LaTeX capabilities"
        print_info "    Use this template for your own course materials"
    fi
    
    echo
    print_success "Professional PDF generation completed!"
    print_info "Successfully created: $converted of $total documentation PDFs"
    
    if [ $converted -gt 0 ]; then
        echo
        print_info "📚 Professional Academic Documentation:"
        
        for doc in "${docs[@]}"; do
            local file="${doc%:*}"
            local pdf="${file%.md}.pdf"
            if [ -f "$pdf" ]; then
                echo "   📄 $(basename "$pdf")"
            fi
        done
        
        [ -f "Professional-Cover-Sample.pdf" ] && echo "   📋 Professional-Cover-Sample.pdf"
        
        echo
        print_info "🎓 Professional Features:"
        echo "   ✓ University-quality typography"
        echo "   ✓ Proper academic formatting"
        echo "   ✓ Table of contents with page numbers"
        echo "   ✓ Cross-references and hyperlinks"
        echo "   ✓ Professional headers and footers"
        echo "   ✓ Color-coded sections and emphasis"
        
        echo
        print_info "💡 Next steps:"
        echo "   • Use these PDFs for professional distribution"
        echo "   • Customize cover sheet template for your institution"
        echo "   • Leverage LaTeX features for advanced documents"
        echo "   • Consider implementing enhanced features from ENHANCED-LATEX-FEATURES.md"
    fi
}

# Run main function
main "$@"