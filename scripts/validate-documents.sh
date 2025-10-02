#!/bin/bash
# Document validation script for pre-commit hook
# Validates AsciiDoc, Markdown, and YAML files

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
WARNINGS=0

# Log functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_FILES++))
}

# Check if required tools are installed
check_prerequisites() {
    local missing_tools=()
    
    # Check for yamllint
    if ! command -v yamllint &> /dev/null; then
        missing_tools+=("yamllint")
    fi
    
    # Check for asciidoctor (optional but recommended)
    if ! command -v asciidoctor &> /dev/null; then
        log_warning "asciidoctor not found - AsciiDoc validation will be limited"
    fi
    
    # Check for markdownlint (optional)
    if ! command -v markdownlint &> /dev/null && ! command -v mdl &> /dev/null; then
        log_warning "markdownlint/mdl not found - Markdown validation will be limited"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install with: pip install yamllint"
        return 1
    fi
    
    return 0
}

# Validate YAML files
validate_yaml() {
    local file=$1
    ((TOTAL_FILES++))
    
    log_info "Validating YAML: $file"
    
    # Basic YAML syntax check
    if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
        log_error "YAML syntax error in $file"
        return 1
    fi
    
    # yamllint check
    if command -v yamllint &> /dev/null; then
        if yamllint -d relaxed "$file" 2>&1 | grep -q "error"; then
            log_error "yamllint found errors in $file"
            yamllint -d relaxed "$file"
            return 1
        fi
    fi
    
    ((PASSED_FILES++))
    log_success "YAML validation passed: $file"
    return 0
}

# Validate AsciiDoc files
validate_asciidoc() {
    local file=$1
    ((TOTAL_FILES++))

    log_info "Validating AsciiDoc: $file"

    # Check for common AsciiDoc issues
    local issues=0

    # Check for proper heading hierarchy
    if grep -q "^======" "$file"; then
        log_warning "File $file uses level 5 headings (======) - consider restructuring"
    fi

    # Check for trailing whitespace
    if grep -q "[[:space:]]$" "$file"; then
        log_warning "File $file contains trailing whitespace"
    fi

    # Check for tabs (should use spaces)
    if grep -qP "\t" "$file"; then
        log_warning "File $file contains tabs - use spaces instead"
    fi

    # Check for incorrect anchor format [id="..."] on separate line before heading
    if grep -B1 "^==" "$file" | grep -q '^\[id=".*"\]$'; then
        log_error "File $file uses [id=\"...\"] format - use [[anchor-name]] or [#anchor-name] instead"
        log_info "Found problematic anchors:"
        grep -B1 "^==" "$file" | grep '^\[id=".*"\]$'
        ((issues++))
    fi

    # Check for empty xrefs
    if grep -q "xref:.*\[\]" "$file"; then
        log_warning "File $file contains xrefs with empty link text"
    fi

    # Check for unbalanced code block delimiters
    local code_block_count=$(grep -c "^----$" "$file" 2>/dev/null)
    # If grep returns empty or fails, set to 0
    code_block_count=${code_block_count:-0}
    if [ "$code_block_count" -gt 0 ] && [ $((code_block_count % 2)) -ne 0 ]; then
        log_error "File $file has unbalanced code block delimiters (----)"
        log_info "Found $code_block_count occurrences of '----' (should be even)"
        ((issues++))
    fi

    # Validate with asciidoctor if available
    if command -v asciidoctor &> /dev/null; then
        if ! asciidoctor --safe-mode=safe --failure-level=WARN -o /dev/null "$file" 2>&1; then
            log_error "asciidoctor validation failed for $file"
            asciidoctor --safe-mode=safe --failure-level=WARN -o /dev/null "$file"
            return 1
        fi
    fi

    # Check for required sections in module files
    if [[ "$file" == *"module-"*.adoc ]]; then
        if ! grep -q "^= " "$file"; then
            log_error "Module file $file missing document title (= Title)"
            return 1
        fi
    fi

    if [ $issues -gt 0 ]; then
        return 1
    fi

    ((PASSED_FILES++))
    log_success "AsciiDoc validation passed: $file"
    return 0
}

# Validate Markdown files
validate_markdown() {
    local file=$1
    ((TOTAL_FILES++))
    
    log_info "Validating Markdown: $file"
    
    # Check for common Markdown issues
    local issues=0
    
    # Check for trailing whitespace
    if grep -q "[[:space:]]$" "$file"; then
        log_warning "File $file contains trailing whitespace"
    fi
    
    # Check for tabs
    if grep -qP "\t" "$file"; then
        log_warning "File $file contains tabs - use spaces instead"
    fi
    
    # Check for proper heading hierarchy (should start with #)
    if ! grep -q "^# " "$file" && [ "$(basename "$file")" != "README.md" ]; then
        log_warning "File $file may be missing a top-level heading"
    fi
    
    # Validate with markdownlint if available
    if command -v markdownlint &> /dev/null; then
        if ! markdownlint "$file" 2>&1; then
            log_warning "markdownlint found issues in $file"
        fi
    elif command -v mdl &> /dev/null; then
        if ! mdl "$file" 2>&1; then
            log_warning "mdl found issues in $file"
        fi
    fi
    
    ((PASSED_FILES++))
    log_success "Markdown validation passed: $file"
    return 0
}

# Main validation function
validate_file() {
    local file=$1
    
    # Skip files in certain directories
    if [[ "$file" == *"node_modules"* ]] || \
       [[ "$file" == *".cache"* ]] || \
       [[ "$file" == *"www/"* ]] || \
       [[ "$file" == *"build/"* ]]; then
        return 0
    fi
    
    case "$file" in
        *.yml|*.yaml)
            validate_yaml "$file"
            ;;
        *.adoc)
            validate_asciidoc "$file"
            ;;
        *.md)
            validate_markdown "$file"
            ;;
        *)
            return 0
            ;;
    esac
}

# Main execution
main() {
    echo "=================================================="
    log_info "Document Validation Script"
    echo "=================================================="
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    echo ""
    
    # Get list of files to validate
    local files=()
    
    if [ $# -eq 0 ]; then
        # No arguments - validate all tracked files
        log_info "Validating all tracked documents..."
        mapfile -t files < <(git ls-files | grep -E '\.(yml|yaml|adoc|md)$')
    else
        # Validate specific files (for pre-commit hook)
        files=("$@")
    fi
    
    if [ ${#files[@]} -eq 0 ]; then
        log_info "No documents to validate"
        exit 0
    fi
    
    echo ""
    log_info "Found ${#files[@]} document(s) to validate"
    echo ""
    
    # Validate each file
    local validation_failed=0
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            if ! validate_file "$file"; then
                validation_failed=1
            fi
            echo ""
        fi
    done
    
    # Print summary
    echo "=================================================="
    log_info "Validation Summary"
    echo "=================================================="
    echo "Total files checked: $TOTAL_FILES"
    echo -e "${GREEN}Passed: $PASSED_FILES${NC}"
    echo -e "${RED}Failed: $FAILED_FILES${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo ""
    
    if [ $FAILED_FILES -gt 0 ]; then
        log_error "Document validation failed!"
        echo ""
        log_info "To fix issues:"
        log_info "  - Check YAML syntax with: yamllint <file>"
        log_info "  - Check AsciiDoc with: asciidoctor --safe-mode=safe <file>"
        log_info "  - Check Markdown with: markdownlint <file>"
        exit 1
    elif [ $WARNINGS -gt 0 ]; then
        log_warning "Validation passed with warnings"
        exit 0
    else
        log_success "All documents validated successfully!"
        exit 0
    fi
}

# Run main function
main "$@"

