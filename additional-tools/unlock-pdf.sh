#!/bin/bash

# PDF Unlock Tool  
# Removes passwords and restrictions from PDFs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo "PDF Unlock Tool"
    echo
    echo "Removes passwords and printing/copying restrictions from PDFs."
    echo
    echo "USAGE:"
    echo "  $0 input.pdf [password]"
    echo
    echo "EXAMPLES:"
    echo "  $0 protected.pdf                    # Will prompt for password"
    echo "  $0 protected.pdf mypassword         # Use provided password"
    echo
    echo "NOTE: Only use on PDFs you own or have permission to unlock."
    echo
    exit 0
}

unlock_pdf() {
    local input_pdf="$1"
    local password="$2"
    local output_pdf="${input_pdf%.pdf}-unlocked.pdf"
    
    echo -e "${CYAN}Removing PDF security restrictions...${NC}"
    
    if [ -n "$password" ]; then
        if qpdf --decrypt --password="$password" "$input_pdf" "$output_pdf" 2>/dev/null; then
            echo -e "${GREEN}✓ PDF unlocked successfully!${NC}"
        else
            echo -e "${RED}✗ Failed to unlock PDF - incorrect password?${NC}"
            exit 1
        fi
    else
        if qpdf --decrypt "$input_pdf" "$output_pdf" 2>/dev/null; then
            echo -e "${GREEN}✓ PDF unlocked successfully!${NC}"
        else
            echo -e "${YELLOW}PDF requires a password${NC}"
            read -s -p "Enter password: " password
            echo
            if qpdf --decrypt --password="$password" "$input_pdf" "$output_pdf" 2>/dev/null; then
                echo -e "${GREEN}✓ PDF unlocked successfully!${NC}"
            else
                echo -e "${RED}✗ Failed to unlock PDF - incorrect password${NC}"
                exit 1
            fi
        fi
    fi
    
    echo "Output: $output_pdf"
}

# Main
if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ $# -eq 0 ]; then
    show_help
fi

if [ ! -f "$1" ]; then
    echo -e "${RED}Error: File not found: $1${NC}"
    exit 1
fi

if ! command -v qpdf >/dev/null 2>&1; then
    echo -e "${RED}Error: qpdf not installed${NC}"
    echo "Install with: brew install qpdf"
    exit 1
fi

unlock_pdf "$1" "$2"