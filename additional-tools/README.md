# PDF Additional Tools

This directory contains specialized PDF tools that complement the main print problem fixer. Each tool focuses on a specific PDF issue.

## 🎯 Main Tool (in parent directory)
- **`fix-pdf-fonts-interactive.sh`** - Primary tool for fixing printing problems caused by font encoding issues

## 🔧 Additional Specialized Tools

### 📊 Analysis Tools
- **`analyze-pdf.sh`** - Comprehensive PDF analysis and problem detection
  ```bash
  ./analyze-pdf.sh document.pdf
  ```
  - Detects font encoding problems
  - Analyzes file size and optimization opportunities
  - Checks security restrictions
  - Identifies compatibility issues
  - Provides specific recommendations

### 📦 Optimization Tools  
- **`compress-pdf.sh`** - Reduce PDF file size
  ```bash
  ./compress-pdf.sh large-document.pdf [quality]
  ```
  - Quality levels: `screen`, `ebook`, `printer`, `prepress`
  - Maintains acceptable quality while reducing size
  - Perfect for email attachments or web uploads

- **`optimize-pdf.sh`** - Optimize for web and compatibility
  ```bash
  ./optimize-pdf.sh document.pdf
  ```
  - Linearizes for faster web loading
  - Improves compatibility with older viewers
  - Fixes minor structural issues

### 🔓 Security Tools
- **`unlock-pdf.sh`** - Remove passwords and restrictions
  ```bash
  ./unlock-pdf.sh protected.pdf [password]
  ```
  - Removes password protection
  - Eliminates printing/copying restrictions
  - Interactive password prompting

### 🛠️ Repair Tools
- **`repair-pdf.sh`** - Fix corrupted PDFs
  ```bash
  ./repair-pdf.sh corrupted.pdf
  ```
  - Multiple repair methods (qpdf, Ghostscript)
  - Handles various types of corruption
  - Preserves maximum content

### 🎛️ Comprehensive Toolkit
- **`pdf-repair-toolkit.sh`** - Interactive menu for all tools
  ```bash
  ./pdf-repair-toolkit.sh
  ```
  - Guided interface for selecting appropriate fixes
  - Combines multiple tools in one interface
  - Advanced users who want all options

## 🚀 Quick Usage Examples

```bash
# Analyze a PDF for all potential issues
./analyze-pdf.sh "My Document.pdf"

# Fix font problems (main use case)
../fix-pdf-fonts-interactive.sh "Problem Doc.pdf"

# Compress a large file for email
./compress-pdf.sh "Large Report.pdf" screen

# Remove password protection
./unlock-pdf.sh "Protected Doc.pdf"

# Repair a corrupted file
./repair-pdf.sh "Damaged File.pdf"

# Full optimization
./optimize-pdf.sh "Document.pdf"

# Interactive mode with all options
./pdf-repair-toolkit.sh
```

## 🎯 When to Use Which Tool

| Problem | Recommended Tool | Description |
|---------|------------------|-------------|
| Text shows as symbols when printing | `../fix-pdf-fonts-interactive.sh` | **Primary tool** - fixes font encoding |
| File too large for email/upload | `compress-pdf.sh` | Reduces file size |
| Can't print or copy text | `unlock-pdf.sh` | Removes restrictions |
| PDF won't open or crashes | `repair-pdf.sh` | Fixes corruption |
| Slow loading on web | `optimize-pdf.sh` | Web optimization |
| Not sure what's wrong | `analyze-pdf.sh` | Diagnoses issues |
| Want all options | `pdf-repair-toolkit.sh` | Interactive toolkit |

## 📋 Installation Requirements

All tools automatically check for and help install required dependencies:

**macOS (via Homebrew):**
- `pdftk-java` - PDF manipulation
- `poppler` - PDF analysis (pdfinfo, pdffonts)
- `qpdf` - PDF optimization and repair
- `ghostscript` - PDF compression and repair
- `imagemagick` - Image processing (for font fix tool)

**Auto-installation:**
Each tool will prompt to install missing dependencies via Homebrew.

## 🆘 Troubleshooting

### "Command not found" errors
Run the tool again - it will offer to install missing dependencies.

### "Permission denied"
```bash
chmod +x additional-tools/*.sh
```

### Tool suggests wrong fix
Use `analyze-pdf.sh` first to get comprehensive analysis and recommendations.

---

**Remember:** The main print problem fixer (`../fix-pdf-fonts-interactive.sh`) should be your first choice for printing issues. These additional tools handle other specific PDF problems.