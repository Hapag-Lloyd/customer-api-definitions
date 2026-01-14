#!/usr/bin/env bash

set -e

echo "Starting OpenAPI code generation and submodule setup..."

# generates the OpenAPI sub modules
echo "Running Maven clean package to generate OpenAPI sources..."
mvn clean package

# Define parent project details for XML manipulation
PARENT_GROUP_ID="com.hlag.api"
PARENT_ARTIFACT_ID="openapi-specs"
PARENT_VERSION="1.0.0-SNAPSHOT"

# Get the list of generated submodules
GENERATED_DIR="target/generated-sources/openapi"

if [ ! -d "$GENERATED_DIR" ]; then
    echo "Error: Generated sources directory not found: $GENERATED_DIR"
    exit 1
fi

echo "Processing generated submodules..."

# for every sub module
for submodule_dir in "$GENERATED_DIR"/*; do
    if [ -d "$submodule_dir" ]; then
        submodule_name=$(basename "$submodule_dir")
        target_dir="$submodule_name"

        echo "Processing submodule: $submodule_name"

        # Create target directory if it doesn't exist
        mkdir -p "$target_dir"

        # copy the whole target/generated-sources/openapi directory into the sub module
        echo "  Copying generated sources to $target_dir..."
        rsync -av --delete "$submodule_dir/" "$target_dir/"

        # modify the pom.xml using xmlstarlet
        if [ -f "$target_dir/pom.xml" ]; then
            echo "  Modifying pom.xml..."

            # Create a backup
            cp "$target_dir/pom.xml" "$target_dir/pom.xml.bak"

            # set the master pom as parent
            xmlstarlet ed \
                -d "//*[local-name()='parent']" \
                -s "//*[local-name()='project']" -t elem -n "parent" \
                -s "//*[local-name()='parent']" -t elem -n "groupId" -v "$PARENT_GROUP_ID" \
                -s "//*[local-name()='parent']" -t elem -n "artifactId" -v "$PARENT_ARTIFACT_ID" \
                -s "//*[local-name()='parent']" -t elem -n "version" -v "$PARENT_VERSION" \
                -s "//*[local-name()='parent']" -t elem -n "relativePath" -v "../pom.xml" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # Remove version element from project (inherited from parent)
            xmlstarlet ed \
                -d "//*[local-name()='project']/*[local-name()='version']" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # overwrite the scm section with master
            xmlstarlet ed \
                -d "//*[local-name()='scm']" \
                -s "//*[local-name()='project']" -t elem -n "scm" \
                -s "//*[local-name()='scm']" -t elem -n "connection" -v "scm:git:git://github.com/Hapag-Lloyd/customer-api-definitions" \
                -s "//*[local-name()='scm']" -t elem -n "developerConnection" -v "scm:git:ssh://gitHub.com:Hapag-Lloyd/customer-api-definitions.git" \
                -s "//*[local-name()='scm']" -t elem -n "url" -v "https://github.com/Hapag-Lloyd/customer-api-definitions/tree/main" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # overwrite the license section with master
            xmlstarlet ed \
                -d "//*[local-name()='licenses']" \
                -s "//*[local-name()='project']" -t elem -n "licenses" \
                -s "//*[local-name()='licenses']" -t elem -n "license" \
                -s "//*[local-name()='license']" -t elem -n "name" -v "Apache 2.0" \
                -s "//*[local-name()='license']" -t elem -n "url" -v "https://github.com/Hapag-Lloyd/customer-api-definitions/blob/main/LICENSE" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # remove all properties
            xmlstarlet ed \
                -d "//*[local-name()='properties']" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # Remove developers section (inherited from parent)
            xmlstarlet ed \
                -d "//*[local-name()='developers']" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # Remove url element (not needed in submodules)
            xmlstarlet ed \
                -d "//*[local-name()='project']/*[local-name()='url']" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # Remove description element (use name instead)
            xmlstarlet ed \
                -d "//*[local-name()='project']/*[local-name()='description']" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # Clean up backup
            rm -f "$target_dir/pom.xml.bak"

            echo "  Successfully modified pom.xml for $submodule_name"
        else
            echo "  Warning: No pom.xml found in $target_dir"
        fi

        echo "  Completed processing $submodule_name"
    fi
done

echo "Build script completed successfully!"
echo "Generated and configured submodules:"
for submodule_dir in "$GENERATED_DIR"/*; do
    if [ -d "$submodule_dir" ]; then
        echo "  - $(basename "$submodule_dir")"
    fi
done
