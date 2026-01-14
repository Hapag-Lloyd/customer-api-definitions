#!/bin/bash

# Script to create Maven submodules from OpenAPI generated sources
# This script creates submodules for every directory in target/generated-sources/openapi
# and always ensures all submodules are added to the root pom.xml

set -e  # Exit on any error

# Configuration
GENERATED_DIR="target/generated-sources/openapi"
ROOT_POM="pom.xml"
BACKUP_POM="pom.xml.backup"


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if directory exists and contains pom.xml
is_valid_maven_project() {
    local dir="$1"
    if [[ -d "$dir" && -f "$dir/pom.xml" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to backup the root pom.xml
backup_root_pom() {
    if [[ -f "$ROOT_POM" ]]; then
        cp "$ROOT_POM" "$BACKUP_POM"
        log_info "Created backup of root pom.xml as $BACKUP_POM"
    fi
}

# Function to restore the root pom.xml from backup
restore_root_pom() {
    if [[ -f "$BACKUP_POM" ]]; then
        mv "$BACKUP_POM" "$ROOT_POM"
        log_warning "Restored root pom.xml from backup due to error"
    fi
}

# Function to check if xmlstarlet is available
check_xmlstarlet() {
    if ! command -v xmlstarlet >/dev/null 2>&1; then
        log_error "xmlstarlet is not installed or not in PATH"
        log_info "Please install xmlstarlet:"
        log_info "  Ubuntu/Debian: sudo apt-get install xmlstarlet"
        log_info "  CentOS/RHEL: sudo yum install xmlstarlet"
        log_info "  macOS: brew install xmlstarlet"
        log_info "  Windows (Git Bash): Download from http://xmlstar.sourceforge.net/"
        exit 1
    fi
}

# Function to set packaging to "pom" for multi-module projects
set_packaging_to_pom() {
    log_info "Setting packaging to 'pom' for multi-module project..."

    # Create a temporary file for XML operations
    local temp_pom="${ROOT_POM}.tmp"
    cp "$ROOT_POM" "$temp_pom"

    # Define namespace for Maven POM
    local ns_option="-N mvn=http://maven.apache.org/POM/4.0.0"

    # Check if packaging element already exists
    local packaging_exists
    packaging_exists=$(xmlstarlet sel $ns_option -t -c "count(/mvn:project/mvn:packaging)" "$temp_pom" 2>/dev/null || echo "0")

    if [[ "$packaging_exists" -gt 0 ]]; then
        # Get current packaging value
        local current_packaging
        current_packaging=$(xmlstarlet sel $ns_option -t -v "/mvn:project/mvn:packaging" "$temp_pom" 2>/dev/null || echo "")

        if [[ "$current_packaging" == "pom" ]]; then
            log_info "Packaging is already set to 'pom', skipping..."
        else
            log_info "Updating packaging from '$current_packaging' to 'pom'..."
            xmlstarlet ed -L $ns_option -u "/mvn:project/mvn:packaging" -v "pom" "$temp_pom"
            log_success "Updated packaging to 'pom'"
        fi
    else
        log_info "No packaging element found, creating one with value 'pom'..."

        # Find the best place to insert packaging (should be early in the POM)
        local version_exists
        version_exists=$(xmlstarlet sel $ns_option -t -c "count(/mvn:project/mvn:version)" "$temp_pom" 2>/dev/null || echo "0")

        if [[ "$version_exists" -gt 0 ]]; then
            # Insert after version
            xmlstarlet ed -L $ns_option -a "/mvn:project/mvn:version" -t elem -n "packaging" -v "pom" "$temp_pom"
        else
            # Insert after artifactId (which should always exist)
            xmlstarlet ed -L $ns_option -a "/mvn:project/mvn:artifactId" -t elem -n "packaging" -v "pom" "$temp_pom"
        fi

        log_success "Added packaging element with value 'pom'"
    fi

    # Format the XML properly and replace the original file
    xmlstarlet fo "$temp_pom" > "$ROOT_POM"
    rm -f "$temp_pom"
}

# Function to add modules to root pom.xml using xmlstarlet
add_modules_to_root_pom() {
    local modules=("$@")

    if [[ ${#modules[@]} -eq 0 ]]; then
        log_warning "No modules to add to root pom.xml"
        return
    fi

    log_info "Adding modules to root pom.xml using xmlstarlet..."

    # Create a temporary file for XML operations
    local temp_pom="${ROOT_POM}.tmp"
    cp "$ROOT_POM" "$temp_pom"

    # Define namespace for Maven POM
    local ns_option="-N mvn=http://maven.apache.org/POM/4.0.0"

    # Check if modules section already exists
    local modules_exist
    modules_exist=$(xmlstarlet sel $ns_option -t -c "count(/mvn:project/mvn:modules)" "$temp_pom" 2>/dev/null || echo "0")

    if [[ "$modules_exist" -gt 0 ]]; then
        log_info "Modules section found, adding missing modules..."

        # Add each module if it doesn't already exist
        for module in "${modules[@]}"; do
            local module_exists
            module_exists=$(xmlstarlet sel $ns_option -t -c "count(/mvn:project/mvn:modules/mvn:module[text()='$module'])" "$temp_pom" 2>/dev/null || echo "0")

            if [[ "$module_exists" -gt 0 ]]; then
                log_warning "Module $module already exists in pom.xml, skipping..."
            else
                # Add the module to the existing modules section
                xmlstarlet ed -L $ns_option -s "/mvn:project/mvn:modules" -t elem -n "module" -v "$module" "$temp_pom"
                log_success "Added module $module to existing modules section"
            fi
        done
    else
        log_info "No modules section found, creating one..."

        # Find the best place to insert the modules section
        local properties_exist dependencies_exist build_exist
        properties_exist=$(xmlstarlet sel $ns_option -t -c "count(/mvn:project/mvn:properties)" "$temp_pom" 2>/dev/null || echo "0")
        dependencies_exist=$(xmlstarlet sel $ns_option -t -c "count(/mvn:project/mvn:dependencies)" "$temp_pom" 2>/dev/null || echo "0")
        build_exist=$(xmlstarlet sel $ns_option -t -c "count(/mvn:project/mvn:build)" "$temp_pom" 2>/dev/null || echo "0")

        # Create the modules section first - insert after properties since we know it exists
        if [[ "$properties_exist" -gt 0 ]]; then
            # Insert after properties
            xmlstarlet ed -L $ns_option -a "/mvn:project/mvn:properties" -t elem -n "modules" "$temp_pom"
        elif [[ "$dependencies_exist" -gt 0 ]]; then
            # Insert before dependencies
            xmlstarlet ed -L $ns_option -i "/mvn:project/mvn:dependencies" -t elem -n "modules" "$temp_pom"
        elif [[ "$build_exist" -gt 0 ]]; then
            # Insert before build
            xmlstarlet ed -L $ns_option -i "/mvn:project/mvn:build" -t elem -n "modules" "$temp_pom"
        else
            # Insert as last child of project (before closing tag)
            xmlstarlet ed -L $ns_option -s "/mvn:project" -t elem -n "modules" "$temp_pom"
        fi

        # Add each module to the newly created modules section
        for module in "${modules[@]}"; do
            xmlstarlet ed -L $ns_option -s "/mvn:project/mvn:modules" -t elem -n "module" -v "$module" "$temp_pom"
            log_success "Added module $module to new modules section"
        done

        log_success "Created modules section with ${#modules[@]} modules"
    fi

    # Format the XML properly and replace the original file
    xmlstarlet fo "$temp_pom" > "$ROOT_POM"
    rm -f "$temp_pom"
}

# Function to create a submodule from a generated directory
create_submodule() {
    local source_dir="$1"
    local module_name="$2"

    log_info "Creating submodule '$module_name' from '$source_dir'..."

    # Create the submodule directory
    if [[ -d "$module_name" ]]; then
        log_warning "Directory '$module_name' already exists. Do you want to overwrite? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Skipping '$module_name'"
            return 1
        fi
        rm -rf "$module_name"
    fi

    # Copy the entire directory structure
    cp -r "$source_dir" "$module_name"

    # Remove unnecessary files for a submodule
    local files_to_remove=(
        "$module_name/.travis.yml"
        "$module_name/git_push.sh"
        "$module_name/.github"
        "$module_name/gradlew"
        "$module_name/gradlew.bat"
        "$module_name/gradle"
        "$module_name/build.gradle"
        "$module_name/build.sbt"
        "$module_name/gradle.properties"
        "$module_name/settings.gradle"
        "$module_name/.openapi-generator-ignore"
    )

    for file in "${files_to_remove[@]}"; do
        if [[ -e "$file" ]]; then
            rm -rf "$file"
            log_info "Removed unnecessary file/directory: $(basename "$file")"
        fi
    done

    log_success "Created submodule '$module_name'"
    return 0
}

# Main execution
main() {
    log_info "Starting Maven submodule creation process..."

    # Check if xmlstarlet is available
    check_xmlstarlet

    # Backup the root pom.xml
    backup_root_pom

    # Track all modules that should be in the pom.xml
    local all_modules=()
    local created_modules=()
    local failed_modules=()

    # First, check if there are generated sources to create submodules from
    if [[ -d "$GENERATED_DIR" ]]; then
        log_info "Found generated sources directory, checking for projects to convert..."

        # Find all directories in the generated sources
        local valid_modules=()

        while IFS= read -r -d '' dir; do
            dir_name=$(basename "$dir")

            if is_valid_maven_project "$dir"; then
                log_info "Found valid Maven project in generated sources: $dir_name"
                valid_modules+=("$dir_name")
            else
                log_warning "Skipping '$dir_name' - not a valid Maven project (no pom.xml found)"
            fi
        done < <(find "$GENERATED_DIR" -maxdepth 1 -type d ! -path "$GENERATED_DIR" -print0 2>/dev/null || true)

        if [[ ${#valid_modules[@]} -gt 0 ]]; then
            log_info "Found ${#valid_modules[@]} valid Maven projects to convert to submodules"

            # Create submodules from generated sources
            for module in "${valid_modules[@]}"; do
                source_path="$GENERATED_DIR/$module"

                if create_submodule "$source_path" "$module"; then
                    created_modules+=("$module")
                    all_modules+=("$module")
                else
                    failed_modules+=("$module")
                fi
            done
        else
            log_info "No valid Maven projects found in generated sources directory"
        fi
    else
        log_info "No generated sources directory found at '$GENERATED_DIR'"
        log_info "Skipping creation from generated sources"
    fi

    # Now check for any existing submodule directories that might not be in the pom.xml yet
    log_info "Checking for existing submodule directories..."

    local existing_modules=()
    for dir in */; do
        dir_name=${dir%/}  # Remove trailing slash
        if [[ -f "$dir/pom.xml" && "$dir_name" != "target" && "$dir_name" != "src" && "$dir_name" != ".git" && "$dir_name" != ".github" ]]; then
            existing_modules+=("$dir_name")
            # Add to all_modules if not already there
            if [[ ! " ${all_modules[*]} " =~ " $dir_name " ]]; then
                all_modules+=("$dir_name")
                log_info "Found existing submodule directory: $dir_name"
            fi
        fi
    done

    if [[ ${#existing_modules[@]} -gt 0 ]]; then
        log_info "Found ${#existing_modules[@]} total existing submodule directories"
    else
        log_info "No existing submodule directories found"
    fi

    # Add all modules to the root pom.xml (both newly created and existing)
    if [[ ${#all_modules[@]} -gt 0 ]]; then
        add_modules_to_root_pom "${all_modules[@]}"

        # Set packaging to "pom" for multi-module project
        set_packaging_to_pom

        # Report results
        if [[ ${#created_modules[@]} -gt 0 ]]; then
            log_success "Successfully created ${#created_modules[@]} new submodules:"
            for module in "${created_modules[@]}"; do
                echo "  - $module"
            done
        fi

        log_success "Ensured ${#all_modules[@]} total submodules are in pom.xml:"
        for module in "${all_modules[@]}"; do
            echo "  - $module"
        done

        # Remove backup if everything was successful
        if [[ ${#failed_modules[@]} -eq 0 ]]; then
            rm -f "$BACKUP_POM"
            log_info "Removed backup file as all operations completed successfully"
        fi
    else
        log_warning "No submodules found to add to pom.xml"
        # Remove backup since we didn't change anything
        rm -f "$BACKUP_POM"
    fi

    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        log_warning "Failed to create ${#failed_modules[@]} submodules:"
        for module in "${failed_modules[@]}"; do
            echo "  - $module"
        done
    fi

    # Final instructions
    echo ""
    log_info "Submodule process complete!"
    log_info "Next steps:"
    echo "  1. Review the submodules in their respective directories"
    echo "  2. Run 'mvn clean compile' to test the structure"
    echo "  3. Update any parent pom.xml references in the submodules if needed"
    echo "  4. Commit the changes to version control"

    if [[ -f "$BACKUP_POM" ]]; then
        echo ""
        log_warning "A backup of your original pom.xml is available as '$BACKUP_POM'"
        log_warning "Remove it manually after verifying everything works correctly"
    fi
}

# Trap to restore backup on script failure
trap 'restore_root_pom' ERR

# Run the main function
main "$@"
