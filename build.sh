#!/usr/bin/env bash

set -e

echo "Maven submodule setup..."

# Define parent project details for XML manipulation
PARENT_POM="pom.xml"

# Extract parent project details dynamically from the master pom.xml
echo "Reading parent project details from $PARENT_POM..."
if [ ! -f "$PARENT_POM" ]; then
    echo "Error: Parent POM file not found: $PARENT_POM"
    exit 1
fi

PARENT_GROUP_ID=$(xmlstarlet sel -t -v "//*[local-name()='project']/*[local-name()='groupId']" "$PARENT_POM" 2>/dev/null || echo "")
PARENT_ARTIFACT_ID=$(xmlstarlet sel -t -v "//*[local-name()='project']/*[local-name()='artifactId']" "$PARENT_POM" 2>/dev/null || echo "")
PARENT_VERSION=$(xmlstarlet sel -t -v "//*[local-name()='project']/*[local-name()='version']" "$PARENT_POM" 2>/dev/null || echo "")

# Validate that we successfully extracted the parent project details
if [ -z "$PARENT_GROUP_ID" ] || [ -z "$PARENT_ARTIFACT_ID" ] || [ -z "$PARENT_VERSION" ]; then
    echo "Error: Failed to extract parent project details from $PARENT_POM"
    echo "  GroupId: '$PARENT_GROUP_ID'"
    echo "  ArtifactId: '$PARENT_ARTIFACT_ID'"
    echo "  Version: '$PARENT_VERSION'"
    exit 1
fi

echo "Parent project details:"
echo "  GroupId: $PARENT_GROUP_ID"
echo "  ArtifactId: $PARENT_ARTIFACT_ID"
echo "  Version: $PARENT_VERSION"

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

            # Remove groupId element from project (inherited from parent)
            xmlstarlet ed \
                -d "//*[local-name()='project']/*[local-name()='groupId']" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # Extract and copy SCM section from parent POM
            echo "  Copying SCM section from parent POM..."
            if xmlstarlet sel -t -c "//*[local-name()='scm']" "$PARENT_POM" > /dev/null 2>&1; then
                # Extract SCM values from parent
                SCM_CONNECTION=$(xmlstarlet sel -t -v "//*[local-name()='scm']/*[local-name()='connection']" "$PARENT_POM" 2>/dev/null || echo "")
                SCM_DEV_CONNECTION=$(xmlstarlet sel -t -v "//*[local-name()='scm']/*[local-name()='developerConnection']" "$PARENT_POM" 2>/dev/null || echo "")
                SCM_URL=$(xmlstarlet sel -t -v "//*[local-name()='scm']/*[local-name()='url']" "$PARENT_POM" 2>/dev/null || echo "")

                # Remove existing SCM section and add new one with parent values
                xmlstarlet ed \
                    -d "//*[local-name()='scm']" \
                    -s "//*[local-name()='project']" -t elem -n "scm" \
                    "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

                # Add SCM elements if they exist in parent
                if [ -n "$SCM_CONNECTION" ]; then
                    xmlstarlet ed \
                        -s "//*[local-name()='scm']" -t elem -n "connection" -v "$SCM_CONNECTION" \
                        "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
                fi
                if [ -n "$SCM_DEV_CONNECTION" ]; then
                    xmlstarlet ed \
                        -s "//*[local-name()='scm']" -t elem -n "developerConnection" -v "$SCM_DEV_CONNECTION" \
                        "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
                fi
                if [ -n "$SCM_URL" ]; then
                    xmlstarlet ed \
                        -s "//*[local-name()='scm']" -t elem -n "url" -v "$SCM_URL" \
                        "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
                fi
            fi

            # Extract and copy licenses section from parent POM
            echo "  Copying licenses section from parent POM..."
            if xmlstarlet sel -t -c "//*[local-name()='licenses']" "$PARENT_POM" > /dev/null 2>&1; then
                # Extract license information from parent
                LICENSE_NAME=$(xmlstarlet sel -t -v "//*[local-name()='licenses']/*[local-name()='license']/*[local-name()='name']" "$PARENT_POM" 2>/dev/null || echo "")
                LICENSE_URL=$(xmlstarlet sel -t -v "//*[local-name()='licenses']/*[local-name()='license']/*[local-name()='url']" "$PARENT_POM" 2>/dev/null || echo "")

                # Remove existing licenses section and add new one with parent values
                xmlstarlet ed \
                    -d "//*[local-name()='licenses']" \
                    -s "//*[local-name()='project']" -t elem -n "licenses" \
                    -s "//*[local-name()='licenses']" -t elem -n "license" \
                    "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

                # Add license elements if they exist in parent
                if [ -n "$LICENSE_NAME" ]; then
                    xmlstarlet ed \
                        -s "//*[local-name()='license']" -t elem -n "name" -v "$LICENSE_NAME" \
                        "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
                fi
                if [ -n "$LICENSE_URL" ]; then
                    xmlstarlet ed \
                        -s "//*[local-name()='license']" -t elem -n "url" -v "$LICENSE_URL" \
                        "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
                fi
            fi

            # Extract and copy developers section from parent POM
            echo "  Copying developers section from parent POM..."
            if xmlstarlet sel -t -c "//*[local-name()='developers']" "$PARENT_POM" > /dev/null 2>&1; then
                # Extract developer information from parent
                DEV_ORGANIZATION=$(xmlstarlet sel -t -v "//*[local-name()='developers']/*[local-name()='developer']/*[local-name()='organization']" "$PARENT_POM" 2>/dev/null || echo "")
                DEV_ORG_URL=$(xmlstarlet sel -t -v "//*[local-name()='developers']/*[local-name()='developer']/*[local-name()='organizationUrl']" "$PARENT_POM" 2>/dev/null || echo "")

                # Remove existing developers section and add new one with parent values
                xmlstarlet ed \
                    -d "//*[local-name()='developers']" \
                    -s "//*[local-name()='project']" -t elem -n "developers" \
                    -s "//*[local-name()='developers']" -t elem -n "developer" \
                    "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

                # Add developer elements if they exist in parent
                if [ -n "$DEV_ORGANIZATION" ]; then
                    xmlstarlet ed \
                        -s "//*[local-name()='developer']" -t elem -n "organization" -v "$DEV_ORGANIZATION" \
                        "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
                fi
                if [ -n "$DEV_ORG_URL" ]; then
                    xmlstarlet ed \
                        -s "//*[local-name()='developer']" -t elem -n "organizationUrl" -v "$DEV_ORG_URL" \
                        "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
                fi
            else
                # Remove existing developers section if parent doesn't have one
                xmlstarlet ed \
                    -d "//*[local-name()='developers']" \
                    "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
            fi

            # Remove url element (not needed in submodules)
            xmlstarlet ed \
                -d "//*[local-name()='project']/*[local-name()='url']" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # Remove description element (use name instead)
            xmlstarlet ed \
                -d "//*[local-name()='project']/*[local-name()='description']" \
                "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"

            # Add skip configuration to maven-compiler-plugin
            echo "  Adding skip configuration to maven-compiler-plugin..."
            if xmlstarlet sel -t -c "//*[local-name()='plugin'][*[local-name()='groupId']='org.apache.maven.plugins' and *[local-name()='artifactId']='maven-compiler-plugin']" "$target_dir/pom.xml" > /dev/null 2>&1; then
                # Check if configuration section exists, if not create it
                if ! xmlstarlet sel -t -c "//*[local-name()='plugin'][*[local-name()='groupId']='org.apache.maven.plugins' and *[local-name()='artifactId']='maven-compiler-plugin']/*[local-name()='configuration']" "$target_dir/pom.xml" > /dev/null 2>&1; then
                    xmlstarlet ed \
                        -s "//*[local-name()='plugin'][*[local-name()='groupId']='org.apache.maven.plugins' and *[local-name()='artifactId']='maven-compiler-plugin']" -t elem -n "configuration" \
                        "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
                fi

                # Add skip element to configuration
                xmlstarlet ed \
                    -s "//*[local-name()='plugin'][*[local-name()='groupId']='org.apache.maven.plugins' and *[local-name()='artifactId']='maven-compiler-plugin']/*[local-name()='configuration']" -t elem -n "skip" -v "\${skipCompilation}" \
                    "$target_dir/pom.xml" > "$target_dir/pom.xml.tmp" && mv "$target_dir/pom.xml.tmp" "$target_dir/pom.xml"
            fi

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
