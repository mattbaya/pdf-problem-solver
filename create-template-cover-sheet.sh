#!/bin/bash

# Template-Based Cover Sheet Generator
# Uses placeholder values and TSV data to create professional cover sheets

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

echo -e "${BLUE}Template-Based Cover Sheet Generator${NC}"
echo "===================================="
echo

# Default values
TSV_FILE="Fall 2025 Course Packets - Form Responses.tsv"
TEMPLATE_FILE="cover-sheet-template-v2.tex"
COURSE_LOOKUP=""
OUTPUT_DIR="generated-covers"

# Usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -c, --course COURSE     Course to lookup (e.g., 'ARTH 309')"
    echo "  -t, --template FILE     Template file to use (default: $TEMPLATE_FILE)"
    echo "  -d, --data FILE         TSV data file (default: $TSV_FILE)"
    echo "  -o, --output DIR        Output directory (default: $OUTPUT_DIR)"
    echo "  -h, --help              Show this help"
    echo
    echo "Examples:"
    echo "  $0 -c 'ARTH 309'       # Generate cover for ARTH 309"
    echo "  $0 -c 'PHIL 201'       # Generate cover for PHIL 201"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--course)
            COURSE_LOOKUP="$2"
            shift 2
            ;;
        -t|--template)
            TEMPLATE_FILE="$2"
            shift 2
            ;;
        -d|--data)
            TSV_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check dependencies
check_dependencies() {
    # Update PATH for MacTeX first
    eval "$(/usr/libexec/path_helper)" 2>/dev/null || true
    
    local missing=()
    
    command -v xelatex >/dev/null 2>&1 || missing+=("mactex")
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        print_info "Install with: brew install --cask mactex"
        exit 1
    fi
    
    print_success "Dependencies available"
}

# Parse TSV data for course
parse_course_data() {
    local course="$1"
    local tsv_file="$2"
    
    print_info "Looking up course: $course"
    
    if [ ! -f "$tsv_file" ]; then
        print_error "TSV file not found: $tsv_file"
        return 1
    fi
    
    # Extract header line and find column positions
    local header=$(head -n1 "$tsv_file")
    local course_col=$(echo "$header" | tr '\t' '\n' | grep -n "Course Number" | cut -d: -f1)
    local title_col=$(echo "$header" | tr '\t' '\n' | grep -n "Course Title" | cut -d: -f1)
    local prof_col=$(echo "$header" | tr '\t' '\n' | grep -n "Professor" | cut -d: -f1)
    local dept_col=$(echo "$header" | tr '\t' '\n' | grep -n "Department" | cut -d: -f1)
    
    if [ -z "$course_col" ] || [ -z "$title_col" ] || [ -z "$prof_col" ] || [ -z "$dept_col" ]; then
        print_error "Could not find required columns in TSV file"
        print_info "Expected columns: Course Number, Course Title, Professor, Department"
        return 1
    fi
    
    print_info "Found columns: Course($course_col), Title($title_col), Professor($prof_col), Department($dept_col)"
    
    # Search for course data
    local course_data=$(grep -i "$course" "$tsv_file" | head -n1)
    
    if [ -z "$course_data" ]; then
        print_error "Course not found: $course"
        print_info "Available courses:"
        tail -n +2 "$tsv_file" | cut -f"$course_col" | sort -u | head -10
        return 1
    fi
    
    # Extract data fields
    COURSE_NUMBER=$(echo "$course_data" | cut -f"$course_col")
    COURSE_TITLE=$(echo "$course_data" | cut -f"$title_col")
    PROFESSOR_NAME=$(echo "$course_data" | cut -f"$prof_col")
    DEPARTMENT=$(echo "$course_data" | cut -f"$dept_col")
    TERM="Fall 2025"  # Inferred from filename
    
    print_success "Found course data:"
    echo "   Course: $COURSE_NUMBER"
    echo "   Title: $COURSE_TITLE"
    echo "   Professor: $PROFESSOR_NAME"
    echo "   Department: $DEPARTMENT"
    echo "   Term: $TERM"
}

# Generate cover sheet from template
generate_cover_sheet() {
    local template_file="$1"
    local output_file="$2"
    
    print_info "Generating cover sheet: $(basename "$output_file")"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Create temporary LaTeX file with substitutions
    local temp_tex=$(mktemp).tex
    
    # Perform template substitutions
    sed "s/<Course-Title>/$COURSE_TITLE/g" "$template_file" | \
    sed "s/<Course-Number>/$COURSE_NUMBER/g" | \
    sed "s/<Professor-Name>/$PROFESSOR_NAME/g" | \
    sed "s/<Department>/$DEPARTMENT/g" | \
    sed "s/<Term>/$TERM/g" > "$temp_tex"
    
    # Compile with XeLaTeX
    local temp_dir=$(dirname "$temp_tex")
    local base_name=$(basename "$temp_tex" .tex)
    local current_dir=$(pwd)
    
    # Copy logo to compilation directory
    if [ -f "$current_dir/williams-logo.png" ]; then
        cp "$current_dir/williams-logo.png" "$temp_dir/"
    fi
    
    cd "$temp_dir"
    
    print_info "Compiling with XeLaTeX..."
    
    if xelatex -interaction=nonstopmode "$temp_tex" >/dev/null 2>&1; then
        # Copy back to original directory with absolute path
        cp "${base_name}.pdf" "$current_dir/$output_file"
        print_success "Cover sheet created: $(basename "$output_file")"
        
        # Cleanup temporary files
        rm -f "${base_name}".{tex,pdf,aux,log}
        cd "$current_dir"
        return 0
    else
        print_error "LaTeX compilation failed"
        print_info "Check that Williams logo file exists: williams-logo.png"
        
        # Cleanup
        rm -f "$temp_tex"
        cd "$current_dir"
        return 1
    fi
}

# Interactive course selection
interactive_selection() {
    if [ ! -f "$TSV_FILE" ]; then
        print_error "TSV file not found: $TSV_FILE"
        exit 1
    fi
    
    print_info "Available courses in $TSV_FILE:"
    echo
    
    # Get course column
    local header=$(head -n1 "$TSV_FILE")
    local course_col=$(echo "$header" | tr '\t' '\n' | grep -n "Course Number" | cut -d: -f1)
    
    if [ -z "$course_col" ]; then
        print_error "Could not find 'Course Number' column"
        exit 1
    fi
    
    # List available courses
    local courses=($(tail -n +2 "$TSV_FILE" | cut -f"$course_col" | sort -u))
    
    for i in "${!courses[@]}"; do
        echo "   $((i+1)). ${courses[i]}"
    done
    
    echo
    read -p "Enter course number or name: " course_input
    
    # Check if it's a number (selection) or course name
    if [[ "$course_input" =~ ^[0-9]+$ ]] && [ "$course_input" -ge 1 ] && [ "$course_input" -le "${#courses[@]}" ]; then
        COURSE_LOOKUP="${courses[$((course_input-1))]}"
    else
        COURSE_LOOKUP="$course_input"
    fi
    
    print_info "Selected course: $COURSE_LOOKUP"
}

# Main function
main() {
    check_dependencies
    
    # If no course specified, show interactive selection
    if [ -z "$COURSE_LOOKUP" ]; then
        interactive_selection
    fi
    
    # Parse course data
    if ! parse_course_data "$COURSE_LOOKUP" "$TSV_FILE"; then
        exit 1
    fi
    
    # Generate output filename
    local safe_course=$(echo "$COURSE_NUMBER" | sed 's/[^A-Za-z0-9]/_/g')
    local output_file="$OUTPUT_DIR/Cover_Sheet_${safe_course}.pdf"
    
    # Generate cover sheet
    if generate_cover_sheet "$TEMPLATE_FILE" "$output_file"; then
        echo
        print_success "Template-based cover sheet generation completed!"
        print_info "📄 Created: $(basename "$output_file")"
        
        if [ -f "$output_file" ]; then
            echo
            print_info "🎓 Features:"
            echo "   • Williams College branding and colors"
            echo "   • Professional typography and layout"
            echo "   • Course information from TSV data"
            echo "   • Template-based for consistent formatting"
            
            echo
            print_info "💡 To create more covers:"
            echo "   $0 -c 'COURSE_NAME'       # For specific course"
            echo "   $0                         # Interactive selection"
        fi
    else
        print_error "Failed to generate cover sheet"
        exit 1
    fi
}

# Run main function
main "$@"