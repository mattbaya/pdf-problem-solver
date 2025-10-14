#!/bin/bash

# Interactive PDF Font Fix Script
# Fixes printing issues caused by problematic font encodings in PDFs
# User-friendly version with automatic problem detection and file selection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
show_help() {
    echo -e "${BLUE}PDF Print Problem Fixer v2.0${NC}"
    echo
    echo "This script fixes PDFs that show garbled text or symbols when printing"
    echo "by converting problematic pages to high-resolution images."
    echo
    echo -e "${CYAN}USAGE:${NC}"
    echo "  $0                    # Interactive mode (recommended)"
    echo "  $0 --help           # Show this help"
    echo "  $0 file.pdf         # Quick mode with specific file"
    echo
    echo -e "${CYAN}WHAT IT DOES:${NC}"
    echo "• Scans PDF files for fonts with custom encodings that cause print problems"
    echo "• Converts problematic pages to high-resolution images (300 DPI)"
    echo "• Rebuilds the PDF with image-based pages that print correctly"
    echo "• Preserves the original file for digital use"
    echo
    echo -e "${CYAN}COMMON PRINT PROBLEMS THIS FIXES:${NC}"
    echo "• Text showing as symbols or garbled characters"
    echo "• Missing text on printed pages"
    echo "• Font substitution errors"
    echo "• Custom encoding issues"
    echo
    echo -e "${CYAN}SYSTEM REQUIREMENTS:${NC}"
    echo "• macOS (automatic dependency installation)"
    echo "• Will install Homebrew if not present"
    echo "• Automatically installs: pdftk, poppler-utils, ImageMagick"
    echo
    echo -e "${CYAN}EXAMPLES:${NC}"
    echo "  $0                                    # Start interactive mode"
    echo "  $0 'My Document.pdf'                 # Process specific file"
    echo
    exit 0
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  PDF Print Problem Fixer v2.0${NC}"
    echo -e "${BLUE}================================${NC}"
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

# Check if Homebrew is installed
check_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        print_warning "Homebrew is not installed on this system"
        echo "Homebrew is a package manager for macOS that makes it easy to install software."
        echo
        echo "Would you like to install Homebrew now? This is required for the PDF tools."
        echo "The installation command will be:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo
        read -p "Install Homebrew now? (y/N): " install_brew
        
        if [[ $install_brew =~ ^[Yy]$ ]]; then
            print_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Add Homebrew to PATH for current session
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if [[ $(uname -m) == "arm64" ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                else
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
            fi
            
            # Verify installation
            if command -v brew >/dev/null 2>&1; then
                print_success "Homebrew installed successfully!"
                echo
                print_info "Note: You may need to restart your terminal or run:"
                echo "  echo 'eval \"\$(brew shellenv)\"' >> ~/.zshrc"
                echo "  source ~/.zshrc"
                echo
            else
                print_error "Homebrew installation failed"
                echo "Please install Homebrew manually and run this script again"
                exit 1
            fi
        else
            print_info "Skipping Homebrew installation"
            print_error "Cannot proceed without Homebrew. Please install it manually:"
            echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            exit 1
        fi
    else
        print_success "Homebrew is installed"
    fi
}

# Install missing tools
install_missing_tools() {
    local tools_to_install=("$@")
    
    print_info "Installing missing tools: ${tools_to_install[*]}"
    echo "This will run: brew install ${tools_to_install[*]}"
    echo
    read -p "Proceed with installation? (y/N): " install_confirm
    
    if [[ $install_confirm =~ ^[Yy]$ ]]; then
        print_info "Installing tools..."
        if brew install "${tools_to_install[@]}"; then
            print_success "Tools installed successfully!"
            echo
        else
            print_error "Installation failed"
            echo "Please try installing manually:"
            echo "  brew install ${tools_to_install[*]}"
            exit 1
        fi
    else
        print_error "Cannot proceed without required tools"
        echo "Please install them manually:"
        echo "  brew install ${tools_to_install[*]}"
        exit 1
    fi
}

# Check if required tools are installed
check_dependencies() {
    print_info "Checking system dependencies..."
    
    # First check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "This script is designed for macOS"
        print_info "On Linux, install these packages instead:"
        echo "  sudo apt-get install pdftk poppler-utils imagemagick  # Ubuntu/Debian"
        echo "  sudo yum install pdftk poppler-utils ImageMagick      # CentOS/RHEL"
        echo
        read -p "Continue anyway? (y/N): " continue_linux
        if [[ ! $continue_linux =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check Homebrew first (macOS only)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        check_homebrew
    fi
    
    # Check for required tools
    local missing_brew_tools=()
    local all_good=true
    
    echo
    print_info "Checking required PDF tools..."
    
    # Check pdftk
    if ! command -v pdftk >/dev/null 2>&1; then
        print_warning "pdftk not found"
        missing_brew_tools+=("pdftk-java")
        all_good=false
    else
        print_success "pdftk found"
    fi
    
    # Check poppler tools
    if ! command -v pdfinfo >/dev/null 2>&1; then
        print_warning "poppler-utils not found"
        missing_brew_tools+=("poppler")
        all_good=false
    else
        print_success "poppler-utils found"
    fi
    
    # Check ImageMagick
    if ! command -v magick >/dev/null 2>&1; then
        print_warning "ImageMagick not found"
        missing_brew_tools+=("imagemagick")
        all_good=false
    else
        print_success "ImageMagick found"
    fi
    
    # Install missing tools if on macOS
    if [ "$all_good" = false ]; then
        echo
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # Remove duplicates from missing tools
            local unique_tools=($(printf "%s\n" "${missing_brew_tools[@]}" | sort -u))
            install_missing_tools "${unique_tools[@]}"
            
            # Verify installation worked
            echo "Verifying installation..."
            if command -v pdftk >/dev/null 2>&1 && command -v pdfinfo >/dev/null 2>&1 && command -v magick >/dev/null 2>&1; then
                print_success "All tools are now available!"
            else
                print_error "Some tools are still missing after installation"
                print_info "You may need to restart your terminal or update your PATH"
                exit 1
            fi
        else
            print_error "Please install the missing tools using your system's package manager"
            exit 1
        fi
    else
        print_success "All required tools are available!"
    fi
    
    echo
}

# Select PDF file
select_pdf_file() {
    local input_pdf=""
    
    echo "How would you like to select your PDF?"
    echo "1) Enter filename directly"
    echo "2) Choose from current directory"
    echo "3) Choose from a specific directory"
    echo
    read -p "Enter choice (1-3): " choice
    
    case $choice in
        1)
            read -p "Enter PDF filename: " input_pdf
            ;;
        2)
            echo
            print_info "PDF files in current directory:"
            local pdf_files=(*.pdf)
            if [ ${#pdf_files[@]} -eq 1 ] && [ ! -f "${pdf_files[0]}" ]; then
                print_warning "No PDF files found in current directory"
                return 1
            fi
            
            for i in "${!pdf_files[@]}"; do
                echo "$((i+1))) ${pdf_files[$i]}"
            done
            echo
            read -p "Select file number: " file_num
            
            if [[ $file_num =~ ^[0-9]+$ ]] && [ $file_num -ge 1 ] && [ $file_num -le ${#pdf_files[@]} ]; then
                input_pdf="${pdf_files[$((file_num-1))]}"
            else
                print_error "Invalid selection"
                return 1
            fi
            ;;
        3)
            read -p "Enter directory path: " dir_path
            if [ ! -d "$dir_path" ]; then
                print_error "Directory not found: $dir_path"
                return 1
            fi
            
            echo
            print_info "PDF files in $dir_path:"
            local pdf_files=("$dir_path"/*.pdf)
            if [ ${#pdf_files[@]} -eq 1 ] && [ ! -f "${pdf_files[0]}" ]; then
                print_warning "No PDF files found in specified directory"
                return 1
            fi
            
            for i in "${!pdf_files[@]}"; do
                local basename=$(basename "${pdf_files[$i]}")
                echo "$((i+1))) $basename"
            done
            echo
            read -p "Select file number: " file_num
            
            if [[ $file_num =~ ^[0-9]+$ ]] && [ $file_num -ge 1 ] && [ $file_num -le ${#pdf_files[@]} ]; then
                input_pdf="${pdf_files[$((file_num-1))]}"
            else
                print_error "Invalid selection"
                return 1
            fi
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    if [ ! -f "$input_pdf" ]; then
        print_error "File not found: $input_pdf"
        return 1
    fi
    
    echo "$input_pdf"
}

# Scan PDF for problematic fonts
scan_pdf_fonts() {
    local pdf_file="$1"
    local total_pages
    
    print_info "Scanning '$pdf_file' for font problems..."
    
    # Get total pages
    total_pages=$(pdfinfo "$pdf_file" | grep "Pages:" | awk '{print $2}')
    print_info "Document has $total_pages pages"
    
    echo
    print_info "Checking fonts throughout document..."
    
    # Create temporary file for results
    local temp_results=$(mktemp)
    local problem_pages=()
    
    # Check fonts on each page (in batches for efficiency)
    local batch_size=50
    local current_batch=1
    
    for ((start=1; start<=total_pages; start+=batch_size)); do
        local end=$((start + batch_size - 1))
        if [ $end -gt $total_pages ]; then
            end=$total_pages
        fi
        
        echo -n "  Checking pages $start-$end... "
        
        # Get font info for this batch
        local font_output=$(pdffonts -f $start -l $end "$pdf_file" 2>/dev/null || echo "")
        
        # Check for custom encodings
        if echo "$font_output" | grep -q "Custom"; then
            # Find specific pages with custom fonts
            for ((page=start; page<=end; page++)); do
                local page_fonts=$(pdffonts -f $page -l $page "$pdf_file" 2>/dev/null || echo "")
                if echo "$page_fonts" | grep -q "Custom"; then
                    problem_pages+=($page)
                    echo "$page: $(echo "$page_fonts" | grep "Custom" | awk '{print $1}' | tr '\n' ' ')" >> "$temp_results"
                fi
            done
            echo -e "${RED}PROBLEMS FOUND${NC}"
        else
            echo -e "${GREEN}OK${NC}"
        fi
        
        current_batch=$((current_batch + 1))
    done
    
    echo
    
    if [ ${#problem_pages[@]} -eq 0 ]; then
        print_success "No font encoding problems detected!"
        rm -f "$temp_results"
        return 1
    else
        print_warning "Found font problems on ${#problem_pages[@]} pages:"
        echo
        
        # Group consecutive pages for better display
        local ranges=()
        local range_start=${problem_pages[0]}
        local range_end=${problem_pages[0]}
        
        for ((i=1; i<${#problem_pages[@]}; i++)); do
            if [ ${problem_pages[$i]} -eq $((range_end + 1)) ]; then
                range_end=${problem_pages[$i]}
            else
                if [ $range_start -eq $range_end ]; then
                    ranges+=("$range_start")
                else
                    ranges+=("$range_start-$range_end")
                fi
                range_start=${problem_pages[$i]}
                range_end=${problem_pages[$i]}
            fi
        done
        
        # Add final range
        if [ $range_start -eq $range_end ]; then
            ranges+=("$range_start")
        else
            ranges+=("$range_start-$range_end")
        fi
        
        echo "  Problematic page ranges: ${ranges[*]}"
        echo
        
        print_info "Detailed font issues:"
        cat "$temp_results" | while read line; do
            echo "  Page $line"
        done
        
        rm -f "$temp_results"
        echo
        
        # Return the problem pages as a space-separated string
        echo "${problem_pages[*]}"
    fi
}

# Convert pages to ranges
pages_to_ranges() {
    local pages=($1)
    local ranges=()
    
    if [ ${#pages[@]} -eq 0 ]; then
        return
    fi
    
    local range_start=${pages[0]}
    local range_end=${pages[0]}
    
    for ((i=1; i<${#pages[@]}; i++)); do
        if [ ${pages[$i]} -eq $((range_end + 1)) ]; then
            range_end=${pages[$i]}
        else
            if [ $range_start -eq $range_end ]; then
                ranges+=("$range_start")
            else
                ranges+=("$range_start-$range_end")
            fi
            range_start=${pages[$i]}
            range_end=${pages[$i]}
        fi
    done
    
    # Add final range
    if [ $range_start -eq $range_end ]; then
        ranges+=("$range_start")
    else
        ranges+=("$range_start-$range_end")
    fi
    
    echo "${ranges[*]}"
}

# Fix specific pages
fix_pdf_pages() {
    local input_pdf="$1"
    local problem_pages="$2"
    local output_pdf="$3"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    local total_pages=$(pdfinfo "$input_pdf" | grep "Pages:" | awk '{print $2}')
    local pages_array=($problem_pages)
    
    print_info "Converting ${#pages_array[@]} problematic pages to images..."
    
    # Create directory for page images
    mkdir -p "$temp_dir/page_images"
    
    # Convert problematic pages to images
    local ranges=$(pages_to_ranges "$problem_pages")
    echo "  Processing page ranges: $ranges"
    
    for page in ${pages_array[@]}; do
        echo -n "  Converting page $page... "
        pdftoppm -f $page -l $page -png -r 300 "$input_pdf" "$temp_dir/page_images/page" 2>/dev/null
        echo "done"
    done
    
    print_info "Reconstructing PDF..."
    
    # Build the final PDF by combining parts
    local pdf_parts=()
    local temp_part_num=1
    
    # Sort pages for processing
    IFS=$'\n' sorted_pages=($(sort -n <<<"${pages_array[*]}")); unset IFS
    
    local current_page=1
    
    for problem_page in "${sorted_pages[@]}"; do
        # Add pages before this problem page
        if [ $current_page -lt $problem_page ]; then
            local before_end=$((problem_page - 1))
            echo "  Extracting pages $current_page-$before_end..."
            pdftk "$input_pdf" cat $current_page-$before_end output "$temp_dir/part_$temp_part_num.pdf"
            pdf_parts+=("$temp_dir/part_$temp_part_num.pdf")
            temp_part_num=$((temp_part_num + 1))
        fi
        
        # Convert the problem page image back to PDF
        echo "  Converting page $problem_page image to PDF..."
        local page_img=$(printf "$temp_dir/page_images/page-%03d.png" $problem_page)
        if [ -f "$page_img" ]; then
            magick "$page_img" "$temp_dir/fixed_page_$problem_page.pdf"
            pdf_parts+=("$temp_dir/fixed_page_$problem_page.pdf")
        else
            print_warning "Image for page $problem_page not found, skipping..."
        fi
        
        current_page=$((problem_page + 1))
    done
    
    # Add remaining pages after the last problem page
    if [ $current_page -le $total_pages ]; then
        echo "  Extracting pages $current_page-$total_pages..."
        pdftk "$input_pdf" cat $current_page-end output "$temp_dir/part_$temp_part_num.pdf"
        pdf_parts+=("$temp_dir/part_$temp_part_num.pdf")
    fi
    
    # Combine all parts
    print_info "Combining all parts into final PDF..."
    pdftk "${pdf_parts[@]}" cat output "$output_pdf"
    
    print_success "Fixed PDF created: $output_pdf"
}

# Main function
main() {
    # Handle command line arguments
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
    fi
    
    print_header
    
    # Check dependencies
    check_dependencies
    
    # Select PDF file
    print_info "Step 1: Select PDF file"
    local input_pdf=""
    
    # If a PDF file was provided as argument, use it
    if [ $# -eq 1 ] && [ -f "$1" ] && [[ "$1" =~ \.pdf$ ]]; then
        input_pdf="$1"
        print_info "Using provided file: $(basename "$input_pdf")"
    else
        if [ $# -eq 1 ] && [ ! -f "$1" ]; then
            print_error "File not found: $1"
            exit 1
        elif [ $# -eq 1 ] && [[ ! "$1" =~ \.pdf$ ]]; then
            print_error "File is not a PDF: $1"
            exit 1
        fi
        
        # Interactive file selection
        input_pdf=$(select_pdf_file)
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
    
    print_success "Selected: $(basename "$input_pdf")"
    echo
    
    # Ask about problem detection
    print_info "Step 2: Identify problematic pages"
    echo "How would you like to identify problem pages?"
    echo "1) Let me scan the entire PDF for font problems (recommended)"
    echo "2) I know the specific page numbers with problems"
    echo
    read -p "Enter choice (1-2): " detection_choice
    
    local problem_pages=""
    
    case $detection_choice in
        1)
            echo
            local scan_result=$(scan_pdf_fonts "$input_pdf")
            if [ $? -eq 1 ]; then
                print_success "No problems found - your PDF should print fine!"
                exit 0
            fi
            problem_pages="$scan_result"
            ;;
        2)
            echo
            read -p "Enter problematic page numbers (space-separated, e.g., '231 233 245'): " problem_pages
            if [ -z "$problem_pages" ]; then
                print_error "No page numbers provided"
                exit 1
            fi
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Generate output filename
    local output_pdf="${input_pdf%.pdf}-FIXED.pdf"
    echo
    read -p "Output filename [$output_pdf]: " custom_output
    if [ -n "$custom_output" ]; then
        output_pdf="$custom_output"
    fi
    
    # Confirm before processing
    echo
    print_info "Summary:"
    echo "  Input PDF: $(basename "$input_pdf")"
    echo "  Problem pages: $problem_pages"
    echo "  Output PDF: $(basename "$output_pdf")"
    echo
    read -p "Proceed with fixing? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        exit 0
    fi
    
    echo
    print_info "Step 3: Processing PDF..."
    
    # Fix the PDF
    fix_pdf_pages "$input_pdf" "$problem_pages" "$output_pdf"
    
    # Show results
    echo
    print_success "PDF processing completed!"
    
    local original_size=$(stat -f%z "$input_pdf" 2>/dev/null || stat -c%s "$input_pdf" 2>/dev/null || echo "0")
    local fixed_size=$(stat -f%z "$output_pdf" 2>/dev/null || stat -c%s "$output_pdf" 2>/dev/null || echo "0")
    
    echo
    print_info "File comparison:"
    printf "  Original: %s (%s bytes)\n" "$(basename "$input_pdf")" "$original_size"
    printf "  Fixed:    %s (%s bytes)\n" "$(basename "$output_pdf")" "$fixed_size"
    
    if [ $fixed_size -gt $original_size ]; then
        local size_increase=$(( (fixed_size - original_size) * 100 / original_size ))
        print_warning "File size increased by ~$size_increase% due to high-resolution image conversion"
        print_info "This is normal and ensures excellent print quality"
    fi
    
    echo
    print_success "The fixed PDF should now print correctly on all printers!"
    print_info "Keep the original PDF for digital use (OCR text intact)"
    print_info "Use the fixed PDF for printing purposes"
}

# Run the script
main "$@"