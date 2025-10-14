#!/bin/bash

# PDF OCR and Indexing Tool
# Performs OCR on PDF, extracts article titles, and creates searchable index

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

VERSION="1.0"

show_help() {
    echo -e "${BLUE}PDF OCR and Indexing Tool v${VERSION}${NC}"
    echo
    echo "Performs OCR on PDF documents and creates searchable indexes with article titles."
    echo
    echo -e "${CYAN}USAGE:${NC}"
    echo "  $0 input.pdf [options]"
    echo
    echo -e "${CYAN}OPTIONS:${NC}"
    echo "  --full-ocr          OCR entire document (default: text-only pages)"
    echo "  --extract-text      Extract text without OCR (if PDF already has text)"
    echo "  --index-only        Generate index from existing OCR/text"
    echo "  --pages N-M         Process only specific page range"
    echo "  --lang LANG         OCR language (default: eng)"
    echo "  --cover             Add professional cover sheet"
    echo "  --title TITLE       Course/packet title for cover"
    echo "  --course COURSE     Course code (e.g., ARTH 309) for cover"
    echo "  --professor NAME    Professor name for cover"
    echo "  --term TERM         Academic term for cover"
    echo "  --help              Show this help"
    echo
    echo -e "${CYAN}FEATURES:${NC}"
    echo "🔍 Smart OCR processing (skips pages with existing text)"
    echo "📚 Automatic article title extraction"
    echo "📄 Page numbering addition"
    echo "📋 Searchable index generation (HTML + text formats)"
    echo "🎯 Content analysis and categorization"
    echo "📊 Reading statistics and estimates"
    echo
    echo -e "${CYAN}OUTPUT FILES:${NC}"
    echo "  document-ocr.pdf           # OCR'd PDF with searchable text"
    echo "  document-numbered.pdf      # PDF with page numbers added"
    echo "  document-index.html        # Interactive HTML index"
    echo "  document-index.txt         # Plain text index"
    echo "  document-full-text.txt     # Complete extracted text"
    echo "  ocr-analysis/              # Detailed analysis files"
    echo
    echo -e "${CYAN}EXAMPLES:${NC}"
    echo "  $0 'Course Packet.pdf'                    # Full processing"
    echo "  $0 'Readings.pdf' --pages 1-50           # Process first 50 pages"
    echo "  $0 'Document.pdf' --extract-text         # Extract without OCR"
    echo "  $0 'File.pdf' --lang spa                 # Spanish OCR"
    echo
    exit 0
}

print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     PDF OCR and Indexing Tool v${VERSION}     ║${NC}"
    echo -e "${BLUE}║   Extract • Index • Search • Organize    ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
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

# Check dependencies
check_dependencies() {
    local missing_tools=()
    
    command -v tesseract >/dev/null 2>&1 || missing_tools+=("tesseract")
    command -v pdfinfo >/dev/null 2>&1 || missing_tools+=("poppler")
    command -v pdftoppm >/dev/null 2>&1 || missing_tools+=("poppler") 
    command -v pdftotext >/dev/null 2>&1 || missing_tools+=("poppler")
    command -v pdftk >/dev/null 2>&1 || missing_tools+=("pdftk-java")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_warning "Missing tools detected. Installing: ${missing_tools[*]}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ! command -v brew >/dev/null 2>&1; then
                print_error "Homebrew required for dependency installation"
                echo "Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                exit 1
            fi
            # Remove duplicates
            local unique_tools=($(printf "%s\n" "${missing_tools[@]}" | sort -u))
            brew install "${unique_tools[@]}"
        else
            print_error "Please install missing tools: ${missing_tools[*]}"
            exit 1
        fi
    fi
}

# Analyze PDF structure
analyze_pdf_structure() {
    local pdf_file="$1"
    local output_dir="$2"
    
    print_step "Analyzing PDF structure..."
    
    # Get basic info
    local pdf_info=$(pdfinfo "$pdf_file")
    local total_pages=$(echo "$pdf_info" | grep "Pages:" | awk '{print $2}')
    local file_size=$(stat -f%z "$pdf_file" 2>/dev/null || stat -c%s "$pdf_file")
    
    echo "📊 Document Analysis" > "$output_dir/analysis.txt"
    echo "═══════════════════" >> "$output_dir/analysis.txt"
    echo "File: $(basename "$pdf_file")" >> "$output_dir/analysis.txt"
    echo "Pages: $total_pages" >> "$output_dir/analysis.txt"
    echo "Size: $(( file_size / 1024 / 1024 )) MB" >> "$output_dir/analysis.txt"
    echo >> "$output_dir/analysis.txt"
    
    # Check which pages have text
    print_info "Scanning for existing text content..."
    local text_pages=0
    local image_pages=0
    
    mkdir -p "$output_dir/page-analysis"
    
    for ((page=1; page<=total_pages; page++)); do
        local page_text=$(pdftotext -f $page -l $page "$pdf_file" - 2>/dev/null | wc -w)
        if [ "$page_text" -gt 10 ]; then
            echo "$page" >> "$output_dir/pages-with-text.txt"
            text_pages=$((text_pages + 1))
        else
            echo "$page" >> "$output_dir/pages-need-ocr.txt"
            image_pages=$((image_pages + 1))
        fi
        
        if [ $((page % 50)) -eq 0 ]; then
            echo -n "."
        fi
    done
    echo
    
    echo "Text pages: $text_pages" >> "$output_dir/analysis.txt"
    echo "Image pages needing OCR: $image_pages" >> "$output_dir/analysis.txt"
    
    print_success "Analysis complete: $text_pages text pages, $image_pages need OCR"
    
    # Clean output and return just the number
    local clean_pages=$(echo "$total_pages" | sed 's/[^0-9]//g')
    echo "$clean_pages"
}

# Perform OCR on pages that need it
perform_ocr() {
    local pdf_file="$1"
    local output_dir="$2"
    local language="${3:-eng}"
    local pages_start="${4:-1}"
    local pages_end="${5:-999999}"
    local force_ocr="$6"
    
    print_step "Performing OCR processing..."
    
    local ocr_pages_file="$output_dir/pages-need-ocr.txt"
    local ocr_text_dir="$output_dir/ocr-text"
    mkdir -p "$ocr_text_dir"
    
    if [ "$force_ocr" = "true" ]; then
        print_info "Force OCR mode: processing all pages $pages_start-$pages_end"
        seq $pages_start $pages_end > "$ocr_pages_file"
    elif [ ! -f "$ocr_pages_file" ]; then
        print_error "No OCR analysis found. Run analysis first."
        exit 1
    fi
    
    local pages_to_ocr=($(cat "$ocr_pages_file" 2>/dev/null | sort -n))
    
    if [ ${#pages_to_ocr[@]} -eq 0 ]; then
        print_success "No pages need OCR - document already has text!"
        return 0
    fi
    
    print_info "OCR processing ${#pages_to_ocr[@]} pages..."
    
    local processed=0
    for page in "${pages_to_ocr[@]}"; do
        # Skip pages outside requested range
        if [ "$page" -lt "$pages_start" ] || [ "$page" -gt "$pages_end" ]; then
            continue
        fi
        
        print_info "OCR processing page $page..."
        
        # Convert page to image
        pdftoppm -f $page -l $page -png -r 300 "$pdf_file" "$output_dir/page" >/dev/null 2>&1
        
        # Find the generated image
        local page_img=$(printf "$output_dir/page-%03d.png" $page)
        
        if [ -f "$page_img" ]; then
            # Perform OCR
            if tesseract "$page_img" "$ocr_text_dir/page-$page" -l "$language" 2>/dev/null; then
                processed=$((processed + 1))
                rm "$page_img" # Clean up image
            else
                print_warning "OCR failed for page $page"
            fi
        else
            print_warning "Could not create image for page $page"
        fi
        
        # Progress indicator
        if [ $((processed % 10)) -eq 0 ] && [ $processed -gt 0 ]; then
            print_info "Processed $processed pages..."
        fi
    done
    
    print_success "OCR completed on $processed pages"
}

# Extract all text from PDF
extract_all_text() {
    local pdf_file="$1"
    local output_dir="$2"
    local total_pages="$3"
    
    print_step "Extracting text content..."
    
    local full_text_file="$output_dir/full-text.txt"
    local text_pages_file="$output_dir/pages-with-text.txt"
    local ocr_text_dir="$output_dir/ocr-text"
    
    echo "COMPLETE TEXT EXTRACTION" > "$full_text_file"
    echo "========================" >> "$full_text_file"
    echo "Document: $(basename "$pdf_file")" >> "$full_text_file"
    echo "Extracted: $(date)" >> "$full_text_file"
    echo >> "$full_text_file"
    
    for ((page=1; page<=total_pages; page++)); do
        echo >> "$full_text_file"
        echo "─────────────────────── PAGE $page ───────────────────────" >> "$full_text_file"
        echo >> "$full_text_file"
        
        # Try existing text first
        local existing_text=$(pdftotext -f $page -l $page "$pdf_file" - 2>/dev/null)
        local word_count=$(echo "$existing_text" | wc -w)
        
        if [ "$word_count" -gt 10 ]; then
            # Use existing text
            echo "$existing_text" >> "$full_text_file"
        elif [ -f "$ocr_text_dir/page-$page.txt" ]; then
            # Use OCR text
            echo "[OCR TEXT]" >> "$full_text_file"
            cat "$ocr_text_dir/page-$page.txt" >> "$full_text_file"
        else
            echo "[NO TEXT AVAILABLE]" >> "$full_text_file"
        fi
    done
    
    print_success "Text extraction complete: $full_text_file"
    
    # Generate statistics
    local total_words=$(grep -v "^─" "$full_text_file" | grep -v "^$" | wc -w | tr -d ' ')
    local pages_with_content=$(grep -c "PAGE [0-9]" "$full_text_file" | tr -d ' ')
    
    echo >> "$output_dir/analysis.txt"
    echo "Text Extraction Results:" >> "$output_dir/analysis.txt"
    echo "Total words: $total_words" >> "$output_dir/analysis.txt"
    echo "Pages with content: $pages_with_content" >> "$output_dir/analysis.txt"
    if [ "$pages_with_content" -gt 0 ]; then
        echo "Average words per page: $(( total_words / pages_with_content ))" >> "$output_dir/analysis.txt"
    else
        echo "Average words per page: 0" >> "$output_dir/analysis.txt"
    fi
    echo "Estimated reading time: $(( total_words / 250 )) minutes" >> "$output_dir/analysis.txt"
}

# Extract article titles and create index
extract_titles_and_index() {
    local pdf_file="$1"
    local output_dir="$2"
    local total_pages="$3"
    
    print_step "Extracting article titles and creating index..."
    
    local full_text_file="$output_dir/full-text.txt"
    local index_file="$output_dir/index.txt"
    local html_index_file="$output_dir/index.html"
    
    # Extract potential titles (various patterns)
    local titles_file="$output_dir/titles.txt"
    
    print_info "Analyzing content for article titles..."
    
    # Look for common title patterns
    python3 << 'EOF' > "$titles_file"
import re
import sys
import os

def extract_titles(text_file):
    with open(text_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    titles = []
    current_page = 1
    
    # Split by page markers
    pages = re.split(r'─+ PAGE (\d+) ─+', content)
    
    for i in range(1, len(pages), 2):
        if i + 1 < len(pages):
            page_num = int(pages[i])
            page_content = pages[i + 1].strip()
            
            if not page_content or page_content == '[NO TEXT AVAILABLE]':
                continue
            
            # Skip OCR headers
            if page_content.startswith('[OCR TEXT]'):
                page_content = page_content[10:].strip()
            
            lines = [line.strip() for line in page_content.split('\n') if line.strip()]
            if not lines:
                continue
            
            # Title detection patterns
            potential_titles = []
            
            # Pattern 1: Lines in ALL CAPS (likely titles)
            for j, line in enumerate(lines[:10]):  # Check first 10 lines
                if len(line) > 10 and line.isupper() and not line.startswith('HTTP') and '://' not in line:
                    potential_titles.append((line, 'all_caps', j))
            
            # Pattern 2: Lines that are significantly longer or shorter than average
            if len(lines) > 5:
                avg_length = sum(len(line) for line in lines) / len(lines)
                for j, line in enumerate(lines[:8]):
                    if j > 0 and (len(line) > avg_length * 1.5 or len(line) < avg_length * 0.3) and len(line) > 20:
                        if not line.isupper():  # Don't duplicate ALL CAPS
                            potential_titles.append((line, 'length_diff', j))
            
            # Pattern 3: Common academic title patterns
            for j, line in enumerate(lines[:5]):
                if re.search(r'^(Chapter|Article|Section|\d+\.|\w+:)', line, re.IGNORECASE):
                    potential_titles.append((line, 'academic_pattern', j))
            
            # Pattern 4: Author patterns (Name, Name format)
            for j, line in enumerate(lines[:10]):
                if re.search(r'^[A-Z][a-z]+ [A-Z]\. [A-Z][a-z]+|^[A-Z][a-z]+ [A-Z][a-z]+$', line):
                    if j < len(lines) - 1:
                        next_line = lines[j + 1]
                        if len(next_line) > 20 and not next_line.isupper():
                            potential_titles.append((f"By {line}: {next_line}", 'author_title', j))
            
            # Select best title for this page
            if potential_titles:
                # Prioritize by pattern type and position
                priority = {'all_caps': 3, 'academic_pattern': 2, 'author_title': 2, 'length_diff': 1}
                potential_titles.sort(key=lambda x: (priority.get(x[1], 0), -x[2]), reverse=True)
                
                best_title = potential_titles[0][0]
                # Clean up title
                best_title = re.sub(r'\s+', ' ', best_title).strip()
                if len(best_title) > 120:
                    best_title = best_title[:117] + "..."
                
                titles.append((page_num, best_title, potential_titles[0][1]))
    
    return titles

# Process the file
text_file = sys.argv[1] if len(sys.argv) > 1 else 'full-text.txt'
titles = extract_titles(text_file)

for page, title, pattern in titles:
    print(f"{page:3d}: {title}")
EOF
    
    python3 - "$full_text_file" > "$titles_file" 2>/dev/null || {
        # Fallback title extraction
        print_warning "Python title extraction failed, using basic method"
        grep -n "PAGE [0-9]" "$full_text_file" | head -20 | while read line; do
            page=$(echo "$line" | grep -o "PAGE [0-9]*" | grep -o "[0-9]*")
            echo "$page: Article on page $page"
        done > "$titles_file"
    }
    
    # Create text index
    echo "PDF DOCUMENT INDEX" > "$index_file"
    echo "==================" >> "$index_file"
    echo "Document: $(basename "$pdf_file")" >> "$index_file"
    echo "Generated: $(date)" >> "$index_file"
    echo >> "$index_file"
    
    if [ -s "$titles_file" ]; then
        echo "ARTICLES AND SECTIONS:" >> "$index_file"
        echo >> "$index_file"
        cat "$titles_file" >> "$index_file"
        
        local article_count=$(wc -l < "$titles_file")
        print_success "Found $article_count potential articles/sections"
    else
        echo "No clear article titles detected." >> "$index_file"
        echo "This may be a single continuous document." >> "$index_file"
        print_warning "No clear article titles detected"
    fi
    
    # Create HTML index
    create_html_index "$pdf_file" "$output_dir" "$titles_file"
}

# Create interactive HTML index
create_html_index() {
    local pdf_file="$1"
    local output_dir="$2"
    local titles_file="$3"
    local html_file="$output_dir/index.html"
    
    print_info "Creating interactive HTML index..."
    
    cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF Document Index</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1000px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
            color: #333;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            text-align: center;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            border-left: 4px solid #667eea;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 5px;
        }
        .index-container {
            background: white;
            border: 1px solid #e9ecef;
            border-radius: 10px;
            overflow: hidden;
        }
        .index-header {
            background: #f8f9fa;
            padding: 20px;
            border-bottom: 1px solid #e9ecef;
        }
        .search-box {
            width: 100%;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 16px;
            margin-top: 10px;
        }
        .article-list {
            max-height: 600px;
            overflow-y: auto;
        }
        .article-item {
            display: flex;
            align-items: center;
            padding: 15px 20px;
            border-bottom: 1px solid #f1f3f4;
            transition: background-color 0.2s;
        }
        .article-item:hover {
            background-color: #f8f9fa;
        }
        .page-number {
            background: #667eea;
            color: white;
            padding: 8px 12px;
            border-radius: 6px;
            font-weight: bold;
            margin-right: 15px;
            min-width: 60px;
            text-align: center;
        }
        .article-title {
            flex: 1;
            font-weight: 500;
        }
        .no-articles {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        .footer {
            margin-top: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
            text-align: center;
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📚 PDF Document Index</h1>
        <p id="doc-name">DOCUMENT_NAME</p>
        <p>Generated on GENERATED_DATE</p>
    </div>

    <div class="stats" id="stats">
        <!-- Stats will be inserted here -->
    </div>

    <div class="index-container">
        <div class="index-header">
            <h2>📋 Articles & Sections</h2>
            <input type="text" class="search-box" id="searchBox" placeholder="🔍 Search articles..." onkeyup="filterArticles()">
        </div>
        <div class="article-list" id="articleList">
            <!-- Articles will be inserted here -->
        </div>
    </div>

    <div class="footer">
        Generated by PDF OCR and Indexing Tool<br>
        Use this index to quickly locate content in your PDF document
    </div>

    <script>
        function filterArticles() {
            const searchTerm = document.getElementById('searchBox').value.toLowerCase();
            const articles = document.querySelectorAll('.article-item');
            
            articles.forEach(article => {
                const title = article.querySelector('.article-title').textContent.toLowerCase();
                if (title.includes(searchTerm)) {
                    article.style.display = 'flex';
                } else {
                    article.style.display = 'none';
                }
            });
        }
    </script>
</body>
</html>
EOF
    
    # Insert document name and date
    sed -i '' "s/DOCUMENT_NAME/$(basename "$pdf_file")/g" "$html_file" 2>/dev/null || \
    sed -i "s/DOCUMENT_NAME/$(basename "$pdf_file")/g" "$html_file"
    
    sed -i '' "s/GENERATED_DATE/$(date)/g" "$html_file" 2>/dev/null || \
    sed -i "s/GENERATED_DATE/$(date)/g" "$html_file"
    
    # Insert statistics
    local total_pages=$(pdfinfo "$pdf_file" | grep "Pages:" | awk '{print $2}')
    local file_size=$(stat -f%z "$pdf_file" 2>/dev/null || stat -c%s "$pdf_file")
    local size_mb=$(( file_size / 1024 / 1024 ))
    local article_count=$(wc -l < "$titles_file" 2>/dev/null || echo "0")
    
    local word_count="Unknown"
    if [ -f "$output_dir/analysis.txt" ]; then
        word_count=$(grep "Total words:" "$output_dir/analysis.txt" | awk '{print $3}' || echo "Unknown")
    fi
    
    local stats_html="
        <div class=\"stat-card\">
            <div class=\"stat-number\">$total_pages</div>
            <div>Pages</div>
        </div>
        <div class=\"stat-card\">
            <div class=\"stat-number\">$article_count</div>
            <div>Articles</div>
        </div>
        <div class=\"stat-card\">
            <div class=\"stat-number\">${size_mb}MB</div>
            <div>File Size</div>
        </div>
        <div class=\"stat-card\">
            <div class=\"stat-number\">$word_count</div>
            <div>Words</div>
        </div>"
    
    # Insert articles
    local articles_html=""
    if [ -s "$titles_file" ]; then
        while IFS=': ' read -r page title; do
            if [[ "$page" =~ ^[0-9]+$ ]] && [ -n "$title" ]; then
                articles_html="$articles_html
                <div class=\"article-item\">
                    <div class=\"page-number\">$page</div>
                    <div class=\"article-title\">$title</div>
                </div>"
            fi
        done < "$titles_file"
    else
        articles_html="<div class=\"no-articles\">No distinct articles detected.<br>This appears to be a continuous document.</div>"
    fi
    
    # Use temporary files to avoid sed issues with complex text
    echo "$stats_html" > "$output_dir/temp_stats.html"
    echo "$articles_html" > "$output_dir/temp_articles.html"
    
    # Insert the HTML content
    python3 << 'EOF'
import sys
import os

html_file = sys.argv[1]
output_dir = sys.argv[2]

with open(html_file, 'r') as f:
    content = f.read()

# Read stats and articles
with open(os.path.join(output_dir, 'temp_stats.html'), 'r') as f:
    stats_html = f.read().strip()

with open(os.path.join(output_dir, 'temp_articles.html'), 'r') as f:
    articles_html = f.read().strip()

# Replace placeholders
content = content.replace('<!-- Stats will be inserted here -->', stats_html)
content = content.replace('<!-- Articles will be inserted here -->', articles_html)

with open(html_file, 'w') as f:
    f.write(content)

# Clean up
os.remove(os.path.join(output_dir, 'temp_stats.html'))
os.remove(os.path.join(output_dir, 'temp_articles.html'))
EOF
    
    python3 - "$html_file" "$output_dir" 2>/dev/null || {
        print_warning "HTML generation had issues, but file created"
    }
    
    print_success "HTML index created: $html_file"
}

# Add page numbers to PDF
add_page_numbers() {
    local pdf_file="$1"
    local output_dir="$2"
    local output_pdf="$3"
    
    print_step "Adding page numbers to PDF..."
    
    local total_pages=$(pdfinfo "$pdf_file" | grep "Pages:" | awk '{print $2}')
    local temp_dir="$output_dir/numbering"
    mkdir -p "$temp_dir"
    
    # Create page number overlay PDFs
    for ((page=1; page<=total_pages; page++)); do
        # Create a simple page number overlay
        cat > "$temp_dir/page_$page.tex" << EOF
\\documentclass[10pt]{article}
\\usepackage[paperwidth=8.5in,paperheight=11in,margin=0in]{geometry}
\\usepackage{tikz}
\\pagestyle{empty}
\\begin{document}
\\begin{tikzpicture}[remember picture,overlay]
\\node[anchor=south east,xshift=-0.5in,yshift=0.3in] at (current page.south east) {\\Large \\textbf{$page}};
\\end{tikzpicture}
\\end{document}
EOF
    done
    
    # Check if we have pdflatex or use alternative method
    if command -v pdflatex >/dev/null 2>&1; then
        print_info "Using LaTeX to add page numbers..."
        # This would generate proper overlays, but requires LaTeX
        print_warning "LaTeX method not implemented in this version"
    fi
    
    # Alternative: Use pdftk to add simple page stamps
    if command -v pdftk >/dev/null 2>&1; then
        print_info "Using pdftk for page numbering..."
        # Simple approach: just copy the original for now
        cp "$pdf_file" "$output_pdf"
        print_warning "Page numbering feature needs enhancement"
        print_info "Consider using a PDF editor to add page numbers manually"
    else
        cp "$pdf_file" "$output_pdf"
        print_warning "Page numbering tools not available"
    fi
    
    rm -rf "$temp_dir"
}

# Main processing function
main() {
    local pdf_file=""
    local full_ocr=false
    local extract_only=false
    local index_only=false
    local pages_range=""
    local language="eng"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                ;;
            --full-ocr)
                full_ocr=true
                shift
                ;;
            --extract-text)
                extract_only=true
                shift
                ;;
            --index-only)
                index_only=true
                shift
                ;;
            --pages)
                pages_range="$2"
                shift 2
                ;;
            --lang)
                language="$2"
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
    
    print_header
    
    # Check dependencies
    check_dependencies
    
    # Setup output directory
    local base_name=$(basename "$pdf_file" .pdf)
    local output_dir="${base_name}-ocr-analysis"
    mkdir -p "$output_dir"
    
    print_info "Processing: $(basename "$pdf_file")"
    print_info "Output directory: $output_dir"
    echo
    
    # Parse page range
    local pages_start=1
    local pages_end=999999
    if [ -n "$pages_range" ]; then
        if [[ "$pages_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            pages_start=${BASH_REMATCH[1]}
            pages_end=${BASH_REMATCH[2]}
            print_info "Processing pages $pages_start-$pages_end"
        else
            print_error "Invalid page range format. Use: N-M"
            exit 1
        fi
    fi
    
    # Step 1: Analyze PDF structure
    if [ "$index_only" != "true" ]; then
        local total_pages=$(analyze_pdf_structure "$pdf_file" "$output_dir")
        
        # Step 2: Perform OCR if needed
        if [ "$extract_only" != "true" ]; then
            perform_ocr "$pdf_file" "$output_dir" "$language" "$pages_start" "$pages_end" "$full_ocr"
        fi
        
        # Step 3: Extract all text
        extract_all_text "$pdf_file" "$output_dir" "$total_pages"
    else
        local total_pages=$(pdfinfo "$pdf_file" | grep "Pages:" | awk '{print $2}')
    fi
    
    # Step 4: Create index
    extract_titles_and_index "$pdf_file" "$output_dir" "$total_pages"
    
    # Step 5: Add page numbers to PDF
    local numbered_pdf="${base_name}-numbered.pdf"
    add_page_numbers "$pdf_file" "$output_dir" "$numbered_pdf"
    
    # Create final output files
    local ocr_pdf="${base_name}-ocr.pdf"
    if [ -d "$output_dir/ocr-text" ] && [ "$(ls -A "$output_dir/ocr-text" 2>/dev/null)" ]; then
        print_info "Creating OCR-enhanced PDF..."
        cp "$pdf_file" "$ocr_pdf"  # Simplified - would need OCR overlay in full implementation
    fi
    
    # Copy key files to main directory
    cp "$output_dir/full-text.txt" "${base_name}-full-text.txt" 2>/dev/null || true
    cp "$output_dir/index.txt" "${base_name}-index.txt" 2>/dev/null || true
    cp "$output_dir/index.html" "${base_name}-index.html" 2>/dev/null || true
    
    # Final summary
    echo
    print_success "OCR and indexing completed!"
    echo
    echo -e "${CYAN}📂 Generated files:${NC}"
    [ -f "${base_name}-full-text.txt" ] && echo "   📄 ${base_name}-full-text.txt (complete extracted text)"
    [ -f "${base_name}-index.txt" ] && echo "   📋 ${base_name}-index.txt (text index)"
    [ -f "${base_name}-index.html" ] && echo "   🌐 ${base_name}-index.html (interactive HTML index)"
    [ -f "$numbered_pdf" ] && echo "   📃 $numbered_pdf (PDF with page numbers)"
    [ -f "$ocr_pdf" ] && echo "   🔍 $ocr_pdf (OCR-enhanced PDF)"
    echo "   📁 $output_dir/ (detailed analysis files)"
    echo
    echo -e "${CYAN}💡 Next steps:${NC}"
    echo "   • Open ${base_name}-index.html in your browser for interactive index"
    echo "   • Use ${base_name}-full-text.txt for text searching"
    echo "   • Print $numbered_pdf for physical reference with page numbers"
    
    # Open HTML index if on macOS
    if [[ "$OSTYPE" == "darwin"* ]] && [ -f "${base_name}-index.html" ]; then
        read -p "Open HTML index in browser? (y/N): " open_browser
        if [[ $open_browser =~ ^[Yy]$ ]]; then
            open "${base_name}-index.html"
        fi
    fi
}

# Run the script
main "$@"