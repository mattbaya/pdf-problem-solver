#!/bin/bash

# PDF Cover Sheet Generator
# Creates professional cover sheets for academic packets

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

show_help() {
    echo -e "${BLUE}PDF Cover Sheet Generator${NC}"
    echo
    echo "Creates professional cover sheets for academic packets and course materials."
    echo
    echo -e "${CYAN}USAGE:${NC}"
    echo "  $0 [PDF file] [options]"
    echo
    echo -e "${CYAN}OPTIONS:${NC}"
    echo "  --title \"Course Title\"          Course or packet title"
    echo "  --course \"DEPT 123\"            Course area and number (e.g., ARTH 309)"  
    echo "  --professor \"Prof. Name\"       Professor's name"
    echo "  --term \"Fall 2025\"             Academic term"
    echo "  --subtitle \"Additional Info\"   Optional subtitle"
    echo "  --logo path/to/logo.png          Logo image file"
    echo "  --interactive                    Fill out fields interactively"
    echo "  --template STYLE                 Cover sheet style (academic, modern, minimal)"
    echo "  --output filename.pdf            Output filename"
    echo "  --help                           Show this help"
    echo
    echo -e "${CYAN}TEMPLATES:${NC}"
    echo "  academic  - Traditional academic style (default)"
    echo "  modern    - Clean modern design"
    echo "  minimal   - Simple and minimal"
    echo
    echo -e "${CYAN}EXAMPLES:${NC}"
    echo "  # Interactive mode"
    echo "  $0 --interactive"
    echo
    echo "  # Add cover to existing PDF"
    echo "  $0 readings.pdf --title \"Art History Readings\" --course \"ARTH 309\" \\"
    echo "      --professor \"Dr. Smith\" --term \"Fall 2025\""
    echo
    echo "  # Create standalone cover"
    echo "  $0 --title \"Course Packet\" --course \"HIST 201\" --template modern"
    echo
    exit 0
}

print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       PDF Cover Sheet Generator       ║${NC}"
    echo -e "${BLUE}║    Professional Academic Covers      ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
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

# Interactive field entry
interactive_entry() {
    echo -e "${CYAN}📝 Enter cover sheet information:${NC}"
    echo
    
    read -p "Course/Packet Title: " title
    read -p "Course (e.g., ARTH 309): " course
    read -p "Professor Name: " professor
    read -p "Term (e.g., Fall 2025): " term
    read -p "Subtitle (optional): " subtitle
    read -p "Logo file path (optional): " logo
    
    echo
    echo "Available templates:"
    echo "  1) academic - Traditional academic style"
    echo "  2) modern   - Clean modern design"  
    echo "  3) minimal  - Simple and minimal"
    read -p "Choose template (1-3): " template_choice
    
    case $template_choice in
        1) template="academic" ;;
        2) template="modern" ;;
        3) template="minimal" ;;
        *) template="academic" ;;
    esac
    
    echo
    echo "Cover sheet preview:"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Title: $title"
    echo "Course: $course"
    echo "Professor: $professor"
    echo "Term: $term"
    [ -n "$subtitle" ] && echo "Subtitle: $subtitle"
    [ -n "$logo" ] && echo "Logo: $logo"
    echo "Template: $template"
    echo
    
    read -p "Proceed with cover sheet creation? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_info "Cover sheet creation cancelled"
        exit 0
    fi
}

# Check dependencies
check_dependencies() {
    local missing_tools=()
    local install_tools=()
    
    # Check core PDF tools
    command -v pdftk >/dev/null 2>&1 || missing_tools+=("pdftk-java")
    command -v qpdf >/dev/null 2>&1 || missing_tools+=("qpdf")
    
    # Check cover generation tools
    command -v wkhtmltopdf >/dev/null 2>&1 || missing_tools+=("wkhtmltopdf")
    command -v magick >/dev/null 2>&1 || missing_tools+=("imagemagick")
    
    # Check for LaTeX (optional but preferred)
    local has_latex=false
    if command -v pdflatex >/dev/null 2>&1; then
        has_latex=true
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_warning "Installing required tools: ${missing_tools[*]}"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ! command -v brew >/dev/null 2>&1; then
                print_error "Homebrew required for installation"
                echo "Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                exit 1
            fi
            
            # Install missing tools
            if brew install "${missing_tools[@]}" 2>/dev/null; then
                print_success "Tools installed successfully"
            else
                print_error "Some tools failed to install"
                print_info "Try installing manually: brew install ${missing_tools[*]}"
            fi
            
            # Offer LaTeX installation if not present
            if [ "$has_latex" = "false" ]; then
                print_info "For highest quality covers, install LaTeX:"
                print_info "  brew install --cask mactex"
                print_info "Cover sheets will use HTML-to-PDF fallback method"
            fi
        else
            print_error "Please install missing tools: ${missing_tools[*]}"
            print_info "Ubuntu/Debian: sudo apt-get install pdftk qpdf wkhtmltopdf imagemagick"
            print_info "CentOS/RHEL: sudo yum install pdftk qpdf wkhtmltopdf ImageMagick"
            exit 1
        fi
    elif [ "$has_latex" = "true" ]; then
        print_success "All tools available including LaTeX"
    else
        print_success "Core tools available (HTML-to-PDF mode)"
    fi
}

# Create LaTeX cover sheet
create_latex_cover() {
    local title="$1"
    local course="$2" 
    local professor="$3"
    local term="$4"
    local subtitle="$5"
    local logo="$6"
    local template="$7"
    local output_dir="$8"
    
    local tex_file="$output_dir/cover.tex"
    
    print_step "Creating LaTeX cover sheet..."
    
    # Choose template style
    case $template in
        modern)
            create_modern_template "$tex_file" "$title" "$course" "$professor" "$term" "$subtitle" "$logo"
            ;;
        minimal)
            create_minimal_template "$tex_file" "$title" "$course" "$professor" "$term" "$subtitle" "$logo"
            ;;
        *)
            create_academic_template "$tex_file" "$title" "$course" "$professor" "$term" "$subtitle" "$logo"
            ;;
    esac
    
    # Compile LaTeX
    cd "$output_dir"
    if pdflatex -interaction=nonstopmode cover.tex >/dev/null 2>&1; then
        print_success "LaTeX cover sheet created"
        echo "cover.pdf"
    else
        print_warning "LaTeX compilation failed, trying fallback method"
        echo ""
    fi
}

# Academic template
create_academic_template() {
    local tex_file="$1"
    local title="$2"
    local course="$3" 
    local professor="$4"
    local term="$5"
    local subtitle="$6"
    local logo="$7"
    
    cat > "$tex_file" << EOF
\\documentclass[12pt]{article}
\\usepackage[letterpaper,margin=1in]{geometry}
\\usepackage{graphicx}
\\usepackage{xcolor}
\\usepackage{helvet}
\\usepackage{titling}
\\renewcommand\\familydefault{\\sfdefault}

% Colors
\\definecolor{darkblue}{RGB}{25,74,135}
\\definecolor{lightgray}{RGB}{128,128,128}

\\pagestyle{empty}

\\begin{document}

\\begin{center}

% Logo section
EOF

    if [ -n "$logo" ] && [ -f "$logo" ]; then
        echo "\\includegraphics[width=2in]{$logo}" >> "$tex_file"
        echo "\\\\[0.5in]" >> "$tex_file"
    else
        echo "\\vspace{1in}" >> "$tex_file"
    fi

    cat >> "$tex_file" << EOF

% Title section
{\\color{darkblue} \\Huge \\textbf{$title}}

\\\\[0.3in]

EOF

    if [ -n "$subtitle" ]; then
        echo "{\\Large \\textit{$subtitle}}" >> "$tex_file"
        echo "\\\\[0.4in]" >> "$tex_file"
    else
        echo "\\vspace{0.4in}" >> "$tex_file"
    fi

    cat >> "$tex_file" << EOF

% Course information box
\\fbox{%
\\begin{minipage}{4in}
\\centering
\\vspace{0.2in}

{\\Large \\textbf{$course}}

\\vspace{0.2in}

{\\large $professor}

\\vspace{0.1in}

{\\large $term}

\\vspace{0.2in}
\\end{minipage}%
}

\\vfill

% Footer
{\\color{lightgray} \\large Academic Course Materials}

\\end{center}

\\end{document}
EOF
}

# Modern template
create_modern_template() {
    local tex_file="$1"
    local title="$2"
    local course="$3" 
    local professor="$4"
    local term="$5"
    local subtitle="$6"
    local logo="$7"
    
    cat > "$tex_file" << EOF
\\documentclass[12pt]{article}
\\usepackage[letterpaper,margin=0.75in]{geometry}
\\usepackage{graphicx}
\\usepackage{xcolor}
\\usepackage{tikz}
\\usepackage{helvet}
\\renewcommand\\familydefault{\\sfdefault}

% Modern colors
\\definecolor{accent}{RGB}{46,125,185}
\\definecolor{secondary}{RGB}{108,117,125}

\\pagestyle{empty}

\\begin{document}

\\begin{tikzpicture}[remember picture,overlay]
% Header bar
\\fill[accent] (current page.north west) rectangle ([yshift=-1in]current page.north east);
\\end{tikzpicture}

\\vspace{0.5in}

\\begin{center}

EOF

    if [ -n "$logo" ] && [ -f "$logo" ]; then
        echo "\\includegraphics[width=1.5in]{$logo}" >> "$tex_file"
        echo "\\\\[0.4in]" >> "$tex_file"
    else
        echo "\\vspace{0.8in}" >> "$tex_file"
    fi

    cat >> "$tex_file" << EOF

{\\color{accent} \\fontsize{36}{40}\\selectfont \\textbf{$title}}

\\\\[0.3in]

EOF

    if [ -n "$subtitle" ]; then
        echo "{\\color{secondary} \\Large $subtitle}" >> "$tex_file"
        echo "\\\\[0.5in]" >> "$tex_file"
    else
        echo "\\vspace{0.5in}" >> "$tex_file"
    fi

    cat >> "$tex_file" << EOF

% Modern info layout
\\begin{minipage}{5in}
\\centering

\\begin{tabular}{c}
{\\color{accent} \\fontsize{18}{22}\\selectfont \\textbf{$course}} \\\\[0.2in]
{\\fontsize{16}{20}\\selectfont $professor} \\\\[0.1in]  
{\\color{secondary} \\fontsize{14}{18}\\selectfont $term}
\\end{tabular}

\\end{minipage}

\\vfill

\\end{center}

\\end{document}
EOF
}

# Minimal template
create_minimal_template() {
    local tex_file="$1"
    local title="$2"
    local course="$3" 
    local professor="$4"
    local term="$5"
    local subtitle="$6"
    local logo="$7"
    
    cat > "$tex_file" << EOF
\\documentclass[12pt]{article}
\\usepackage[letterpaper,margin=1.5in]{geometry}
\\usepackage{graphicx}
\\usepackage{helvet}
\\renewcommand\\familydefault{\\sfdefault}

\\pagestyle{empty}

\\begin{document}

\\begin{center}

\\vspace{2in}

EOF

    if [ -n "$logo" ] && [ -f "$logo" ]; then
        echo "\\includegraphics[width=1in]{$logo}" >> "$tex_file"
        echo "\\\\[0.4in]" >> "$tex_file"
    fi

    cat >> "$tex_file" << EOF

{\\fontsize{28}{32}\\selectfont $title}

\\\\[0.2in]

EOF

    if [ -n "$subtitle" ]; then
        echo "{\\large $subtitle}" >> "$tex_file"
        echo "\\\\[0.4in]" >> "$tex_file"
    else
        echo "\\vspace{0.4in}" >> "$tex_file"
    fi

    cat >> "$tex_file" << EOF

\\rule{3in}{0.4pt}

\\\\[0.3in]

{\\Large $course}

\\\\[0.2in]

$professor

\\\\[0.1in]

$term

\\vfill

\\end{center}

\\end{document}
EOF
}

# Fallback HTML-to-PDF cover creation
create_html_cover() {
    local title="$1"
    local course="$2" 
    local professor="$3"
    local term="$4"
    local subtitle="$5"
    local logo="$6"
    local template="$7"
    local output_dir="$8"
    
    local html_file="$output_dir/cover.html"
    
    print_step "Creating HTML cover sheet..."
    
    cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        @page { 
            size: letter; 
            margin: 0; 
        }
        body {
            font-family: 'Helvetica Neue', Arial, sans-serif;
            margin: 0;
            padding: 0;
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
        }
        .academic {
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            color: #1a4d73;
        }
        .modern {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .minimal {
            background: white;
            color: #333;
        }
        .logo {
            max-width: 150px;
            margin-bottom: 30px;
        }
        .title {
            font-size: 48px;
            font-weight: bold;
            margin-bottom: 20px;
            line-height: 1.2;
        }
        .subtitle {
            font-size: 24px;
            font-style: italic;
            margin-bottom: 40px;
            opacity: 0.8;
        }
        .info-box {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            margin: 20px;
            border: 2px solid rgba(255,255,255,0.2);
        }
        .course {
            font-size: 28px;
            font-weight: bold;
            margin-bottom: 15px;
        }
        .professor {
            font-size: 22px;
            margin-bottom: 10px;
        }
        .term {
            font-size: 18px;
            opacity: 0.9;
        }
    </style>
</head>
<body class="TEMPLATE_CLASS">
EOF
    
    # Insert logo if provided
    if [ -n "$logo" ] && [ -f "$logo" ]; then
        echo "    <img src=\"file://$logo\" class=\"logo\" alt=\"Logo\">" >> "$html_file"
    fi
    
    # Insert content
    echo "    <div class=\"title\">$title</div>" >> "$html_file"
    
    if [ -n "$subtitle" ]; then
        echo "    <div class=\"subtitle\">$subtitle</div>" >> "$html_file"
    fi
    
    cat >> "$html_file" << EOF
    <div class="info-box">
        <div class="course">$course</div>
        <div class="professor">$professor</div>
        <div class="term">$term</div>
    </div>
</body>
</html>
EOF
    
    # Apply template
    sed -i '' "s/TEMPLATE_CLASS/$template/g" "$html_file" 2>/dev/null || \
    sed -i "s/TEMPLATE_CLASS/$template/g" "$html_file"
    
    # Convert to PDF using various methods
    local pdf_file="$output_dir/cover.pdf"
    
    # Try wkhtmltopdf first
    if command -v wkhtmltopdf >/dev/null 2>&1; then
        wkhtmltopdf --page-size Letter "$html_file" "$pdf_file" >/dev/null 2>&1 && {
            print_success "HTML cover sheet created"
            echo "cover.pdf"
            return
        }
    fi
    
    # Try headless Chrome/Chromium
    for browser in google-chrome chromium-browser chrome; do
        if command -v $browser >/dev/null 2>&1; then
            $browser --headless --disable-gpu --print-to-pdf="$pdf_file" "$html_file" >/dev/null 2>&1 && {
                print_success "HTML cover sheet created via Chrome"
                echo "cover.pdf"
                return
            }
        fi
    done
    
    print_warning "Could not convert HTML to PDF"
    print_info "HTML cover created at: $html_file"
    print_info "Open in browser and print to PDF manually"
    echo ""
}

# Add cover to existing PDF
add_cover_to_pdf() {
    local cover_pdf="$1"
    local original_pdf="$2"
    local output_pdf="$3"
    
    print_step "Adding cover sheet to PDF..."
    
    if command -v pdftk >/dev/null 2>&1; then
        pdftk "$cover_pdf" "$original_pdf" cat output "$output_pdf"
        print_success "Cover sheet added to PDF"
    elif command -v qpdf >/dev/null 2>&1; then
        qpdf --empty --pages "$cover_pdf" "$original_pdf" -- "$output_pdf"
        print_success "Cover sheet added to PDF"
    else
        print_error "No PDF manipulation tools available"
        print_info "Install pdftk or qpdf to combine PDFs"
        return 1
    fi
}

# Main function
main() {
    local input_pdf=""
    local title=""
    local course=""
    local professor=""
    local term=""
    local subtitle=""
    local logo=""
    local template="academic"
    local output_pdf=""
    local interactive=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            --course)
                course="$2"
                shift 2
                ;;
            --professor)
                professor="$2"
                shift 2
                ;;
            --term)
                term="$2"
                shift 2
                ;;
            --subtitle)
                subtitle="$2"
                shift 2
                ;;
            --logo)
                logo="$2"
                shift 2
                ;;
            --template)
                template="$2"
                shift 2
                ;;
            --output)
                output_pdf="$2"
                shift 2
                ;;
            --interactive)
                interactive=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                exit 1
                ;;
            *)
                if [ -z "$input_pdf" ] && [[ "$1" =~ \.pdf$ ]]; then
                    input_pdf="$1"
                else
                    print_error "Invalid argument: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    print_header
    
    # Interactive mode
    if [ "$interactive" = "true" ] || ([ -z "$title" ] && [ -z "$course" ]); then
        interactive_entry
    fi
    
    # Validate required fields
    if [ -z "$title" ]; then
        print_error "Title is required"
        exit 1
    fi
    
    # Set defaults
    [ -z "$course" ] && course="Course Materials"
    [ -z "$professor" ] && professor="Academic Department"
    [ -z "$term" ] && term="$(date +%Y)"
    
    # Setup output
    if [ -z "$output_pdf" ]; then
        if [ -n "$input_pdf" ]; then
            output_pdf="${input_pdf%.pdf}-with-cover.pdf"
        else
            output_pdf="cover-sheet.pdf"
        fi
    fi
    
    # Check dependencies
    check_dependencies
    
    # Create working directory
    local work_dir=$(mktemp -d)
    trap "rm -rf $work_dir" EXIT
    
    print_info "Creating cover sheet..."
    echo "Title: $title"
    echo "Course: $course"
    echo "Professor: $professor"
    echo "Term: $term"
    [ -n "$subtitle" ] && echo "Subtitle: $subtitle"
    echo "Template: $template"
    echo
    
    # Create cover sheet
    local cover_file=""
    if command -v pdflatex >/dev/null 2>&1; then
        cover_file=$(create_latex_cover "$title" "$course" "$professor" "$term" "$subtitle" "$logo" "$template" "$work_dir")
    fi
    
    if [ -z "$cover_file" ] || [ ! -f "$work_dir/$cover_file" ]; then
        cover_file=$(create_html_cover "$title" "$course" "$professor" "$term" "$subtitle" "$logo" "$template" "$work_dir")
    fi
    
    if [ -n "$cover_file" ] && [ -f "$work_dir/$cover_file" ]; then
        if [ -n "$input_pdf" ] && [ -f "$input_pdf" ]; then
            # Add cover to existing PDF
            add_cover_to_pdf "$work_dir/$cover_file" "$input_pdf" "$output_pdf"
        else
            # Just copy the cover
            cp "$work_dir/$cover_file" "$output_pdf"
        fi
        
        print_success "Cover sheet completed!"
        echo "Output: $output_pdf"
        
        # Open if on macOS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            read -p "Open PDF to preview? (y/N): " open_pdf
            if [[ $open_pdf =~ ^[Yy]$ ]]; then
                open "$output_pdf"
            fi
        fi
    else
        print_error "Failed to create cover sheet"
        exit 1
    fi
}

# Run the script
main "$@"