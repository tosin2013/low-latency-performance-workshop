#!/bin/bash
# Antora site validation script
# Validates Antora configuration and content structure before building

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
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
    ((FAILED_CHECKS++))
}

log_section() {
    echo ""
    echo "=================================================="
    echo -e "${CYAN}$1${NC}"
    echo "=================================================="
}

# Check if Antora site configuration exists
check_site_config() {
    log_section "Checking Antora Site Configuration"
    ((TOTAL_CHECKS++))
    
    if [ ! -f "default-site.yml" ]; then
        log_error "default-site.yml not found"
        return 1
    fi
    
    log_info "Validating default-site.yml..."
    
    # Validate YAML syntax
    if ! python3 -c "import yaml; yaml.safe_load(open('default-site.yml'))" 2>/dev/null; then
        log_error "default-site.yml has invalid YAML syntax"
        return 1
    fi
    
    # Check required fields
    local required_fields=("site.title" "content.sources" "ui.bundle.url" "output.dir")
    for field in "${required_fields[@]}"; do
        if ! python3 -c "import yaml; data = yaml.safe_load(open('default-site.yml')); print(data.get('${field%%.*}', {}).get('${field#*.}', ''))" 2>/dev/null | grep -q .; then
            log_warning "default-site.yml missing recommended field: $field"
        fi
    done
    
    ((PASSED_CHECKS++))
    log_success "Site configuration is valid"
    return 0
}

# Check Antora component configuration
check_component_config() {
    log_section "Checking Antora Component Configuration"
    ((TOTAL_CHECKS++))
    
    if [ ! -f "content/antora.yml" ]; then
        log_error "content/antora.yml not found"
        return 1
    fi
    
    log_info "Validating content/antora.yml..."
    
    # Validate YAML syntax
    if ! python3 -c "import yaml; yaml.safe_load(open('content/antora.yml'))" 2>/dev/null; then
        log_error "content/antora.yml has invalid YAML syntax"
        return 1
    fi
    
    # Check required fields
    local required_fields=("name" "title" "version")
    for field in "${required_fields[@]}"; do
        if ! grep -q "^${field}:" content/antora.yml; then
            log_error "content/antora.yml missing required field: $field"
            return 1
        fi
    done
    
    # Check for navigation file
    local nav_file=$(grep "^  - " content/antora.yml | head -1 | awk '{print $2}')
    if [ -n "$nav_file" ]; then
        local nav_path="content/$nav_file"
        if [ ! -f "$nav_path" ]; then
            log_error "Navigation file not found: $nav_path"
            return 1
        fi
        log_success "Navigation file exists: $nav_path"
    fi
    
    ((PASSED_CHECKS++))
    log_success "Component configuration is valid"
    return 0
}

# Check content structure
check_content_structure() {
    log_section "Checking Content Structure"
    ((TOTAL_CHECKS++))
    
    local required_dirs=(
        "content/modules"
        "content/modules/ROOT"
        "content/modules/ROOT/pages"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "Required directory not found: $dir"
            return 1
        fi
    done
    
    log_success "Content directory structure is valid"
    
    # Check for content files
    local page_count=$(find content/modules/ROOT/pages -name "*.adoc" 2>/dev/null | wc -l)
    if [ "$page_count" -eq 0 ]; then
        log_warning "No AsciiDoc pages found in content/modules/ROOT/pages"
    else
        log_info "Found $page_count AsciiDoc page(s)"
    fi
    
    ((PASSED_CHECKS++))
    return 0
}

# Check navigation file
check_navigation() {
    log_section "Checking Navigation"
    ((TOTAL_CHECKS++))
    
    local nav_file="content/modules/ROOT/nav.adoc"
    
    if [ ! -f "$nav_file" ]; then
        log_error "Navigation file not found: $nav_file"
        return 1
    fi
    
    log_info "Validating navigation file..."
    
    # Check for navigation entries
    if ! grep -q "^\* " "$nav_file"; then
        log_warning "Navigation file appears to be empty or has no entries"
    fi
    
    # Check that referenced pages exist
    local missing_pages=0
    while IFS= read -r line; do
        if [[ "$line" =~ xref:([^[]+)\[ ]]; then
            local page_ref="${BASH_REMATCH[1]}"
            local page_file="content/modules/ROOT/pages/${page_ref}"
            
            if [ ! -f "$page_file" ]; then
                log_warning "Navigation references missing page: $page_ref"
                ((missing_pages++))
            fi
        fi
    done < "$nav_file"
    
    if [ $missing_pages -eq 0 ]; then
        log_success "All navigation references are valid"
    else
        log_warning "Found $missing_pages missing page reference(s) in navigation"
    fi
    
    ((PASSED_CHECKS++))
    return 0
}

# Check AsciiDoc pages for common issues
check_asciidoc_pages() {
    log_section "Checking AsciiDoc Pages"
    ((TOTAL_CHECKS++))
    
    local pages_dir="content/modules/ROOT/pages"
    local page_files=$(find "$pages_dir" -name "*.adoc" 2>/dev/null)
    
    if [ -z "$page_files" ]; then
        log_warning "No AsciiDoc pages found"
        ((PASSED_CHECKS++))
        return 0
    fi
    
    local issues_found=0
    
    for page in $page_files; do
        log_info "Checking $(basename "$page")..."
        
        # Check for document title
        if ! grep -q "^= " "$page"; then
            log_warning "$(basename "$page"): Missing document title (= Title)"
            ((issues_found++))
        fi
        
        # Check for broken xrefs (basic check)
        if grep -q "xref:.*\[\]" "$page"; then
            log_warning "$(basename "$page"): Contains xrefs with empty link text"
            ((issues_found++))
        fi
        
        # Check for undefined attributes (basic check)
        if grep -qE '\{[a-zA-Z_][a-zA-Z0-9_-]*\}' "$page"; then
            # This is just informational - attributes might be defined in antora.yml
            log_info "$(basename "$page"): Uses attributes (ensure they're defined in antora.yml)"
        fi
    done
    
    if [ $issues_found -eq 0 ]; then
        log_success "All AsciiDoc pages passed basic checks"
    else
        log_warning "Found $issues_found issue(s) in AsciiDoc pages"
    fi
    
    ((PASSED_CHECKS++))
    return 0
}

# Check for required tools
check_build_tools() {
    log_section "Checking Build Tools"
    ((TOTAL_CHECKS++))

    local missing_tools=()

    # Check for container runtime
    if ! command -v podman &> /dev/null && ! command -v docker &> /dev/null; then
        missing_tools+=("podman or docker")
    else
        if command -v podman &> /dev/null; then
            local podman_version=$(timeout 2 podman --version 2>/dev/null | head -1 || echo "unknown")
            log_success "Found podman: $podman_version"
        elif command -v docker &> /dev/null; then
            local docker_version=$(timeout 2 docker --version 2>/dev/null | head -1 || echo "unknown")
            log_success "Found docker: $docker_version"
        fi
    fi

    # Check for Python (for YAML validation)
    if ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    else
        local python_version=$(python3 --version 2>&1)
        log_success "Found python3: $python_version"
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi

    ((PASSED_CHECKS++))
    return 0
}

# Run document validation
run_document_validation() {
    log_section "Running Document Validation"
    ((TOTAL_CHECKS++))

    if [ ! -f "scripts/validate-documents.sh" ]; then
        log_warning "Document validation script not found, skipping"
        ((PASSED_CHECKS++))
        return 0
    fi

    log_info "Running document validation on content files..."

    # Collect files to validate
    local files_to_validate=()

    # Add AsciiDoc pages if they exist
    if ls content/modules/ROOT/pages/*.adoc &>/dev/null; then
        files_to_validate+=(content/modules/ROOT/pages/*.adoc)
    fi

    # Add configuration files
    files_to_validate+=(content/antora.yml default-site.yml)

    # Run validation and capture output
    local validation_output
    validation_output=$(./scripts/validate-documents.sh "${files_to_validate[@]}" 2>&1)
    local validation_exit=$?

    # Check if validation passed
    if [ $validation_exit -eq 0 ]; then
        log_success "Document validation passed"
        ((PASSED_CHECKS++))
        return 0
    else
        log_error "Document validation found issues"
        echo "$validation_output" | tail -20
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo "=================================================="
    echo -e "${CYAN}Antora Site Validation${NC}"
    echo "=================================================="
    echo ""
    
    log_info "Validating Antora site before build..."
    echo ""
    
    # Run all checks
    check_build_tools
    check_site_config
    check_component_config
    check_content_structure
    check_navigation
    check_asciidoc_pages
    
    # Optionally run full document validation
    if [ "${SKIP_DOC_VALIDATION:-false}" != "true" ]; then
        run_document_validation
    fi
    
    # Print summary
    echo ""
    echo "=================================================="
    log_info "Validation Summary"
    echo "=================================================="
    echo "Total checks: $TOTAL_CHECKS"
    echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
    echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo ""
    
    if [ $FAILED_CHECKS -gt 0 ]; then
        log_error "Antora site validation failed!"
        echo ""
        log_info "Please fix the issues above before building the site."
        exit 1
    elif [ $WARNINGS -gt 0 ]; then
        log_warning "Validation passed with warnings"
        echo ""
        log_info "Consider addressing the warnings above."
        exit 0
    else
        log_success "All validations passed! Site is ready to build."
        exit 0
    fi
}

# Run main function
main "$@"

