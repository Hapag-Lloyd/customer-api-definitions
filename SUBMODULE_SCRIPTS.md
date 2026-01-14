# Submodule Creation Script

This directory contains a bash script to automatically create Maven submodules from OpenAPI generated sources.

## Overview

The OpenAPI Generator Maven plugin generates complete Maven projects in the `target/generated-sources/openapi/` directory. This script helps you convert those generated projects into proper Maven submodules in your main project.

## Script

### Bash Script (`create-submodules.sh`)

- **Platform**: Linux, macOS, Windows (with Git Bash/WSL)
- **Usage**: `./create-submodules.sh`
- **Behavior**: Automatically handles both creating new submodules from generated sources AND ensuring all existing submodules are in pom.xml

## What the Script Does

The script automatically handles both scenarios in a single run:

### For Generated Sources (if available)

1. **Scan** the `target/generated-sources/openapi` directory for subdirectories containing Maven projects
2. **Validate** each directory contains a valid `pom.xml` file
3. **Create** submodule directories in the project root
4. **Copy** the generated source code to the new submodules
5. **Clean up** unnecessary files (Gradle files, CI files, etc.)

### For All Submodules (including existing ones)

6. **Scan** the project root for ANY directories containing `pom.xml` files
7. **Update** the root `pom.xml` to include ALL submodules (newly created + existing)
8. **Backup** the original `pom.xml` for safety

The script is smart enough to handle any combination of scenarios:

- Only generated sources exist → Creates submodules and adds to POM
- Only existing submodules exist → Adds existing submodules to POM
- Both exist → Creates new submodules AND ensures existing ones are in POM

## Prerequisites

Before running the script:

1. **Install xmlstarlet** for XML manipulation:

   ```bash
   # Ubuntu/Debian
   sudo apt-get install xmlstarlet

   # CentOS/RHEL/Fedora
   sudo yum install xmlstarlet    # or dnf install xmlstarlet

   # macOS
   brew install xmlstarlet

   # Windows (Git Bash)
   # Download from http://xmlstar.sourceforge.net/ and add to PATH
   ```

2. Generate the OpenAPI sources first:

   ```bash
   mvn clean compile
   ```

3. Ensure the `target/generated-sources/openapi` directory contains the generated projects (if you want to create new submodules)

## Usage

The script works automatically and handles all scenarios:

```bash
# Run the script - it will automatically:
# 1. Create submodules from any generated OpenAPI sources (if they exist)
# 2. Ensure ALL existing submodule directories are added to pom.xml
./create-submodules.sh
```

**Common scenarios:**

- **First time setup**: Run `mvn clean compile` first, then `./create-submodules.sh`
- **Adding existing submodules to POM**: Just run `./create-submodules.sh` (no generated sources needed)
- **Mixed scenario**: The script handles both new and existing submodules automatically

## Generated Structure

After running the script, your project structure will look like:

```
project-root/
├── pom.xml (updated with modules)
├── src/
├── target/
├── ratesheet-api-java-native/          # New submodule
│   ├── pom.xml
│   ├── src/
│   └── ...
├── ratesheet-api-java-resttemplate/    # New submodule
│   ├── pom.xml
│   ├── src/
│   └── ...
└── create-submodules.sh
```

## Files Removed from Submodules

The script automatically removes files that are not needed in Maven submodules:

- `.travis.yml` - CI configuration
- `git_push.sh` - Git automation script
- `.github/` - GitHub workflows
- `gradlew*` - Gradle wrapper files
- `gradle/` - Gradle directory
- `build.gradle` - Gradle build file
- `build.sbt` - SBT build file
- `gradle.properties` - Gradle properties
- `settings.gradle` - Gradle settings
- `.openapi-generator-ignore` - Generator ignore file

## Safety Features

- **Backup**: Creates `pom.xml.backup` before making changes
- **Validation**: Checks for existing modules before adding them
- **Confirmation**: Prompts before overwriting existing directories (unless forced)
- **Error handling**: Restores backup if script fails
- **Logging**: Colored output for better visibility

## After Running the Script

1. **Review** the created submodules
2. **Test** the build: `mvn clean compile`
3. **Update** any parent references in submodule `pom.xml` files if needed
4. **Commit** the changes to version control
5. **Remove** the backup file once verified: `rm pom.xml.backup`

## Troubleshooting

### Script fails with "xmlstarlet is not installed"

- Install xmlstarlet using the commands shown in the Prerequisites section
- On Windows with Git Bash, download from http://xmlstar.sourceforge.net/ and add to PATH

### Script fails with "Generated sources directory does not exist"

- Run `mvn clean compile` first to generate the OpenAPI sources

### "No valid Maven projects found"

- Check that the generated directories contain `pom.xml` files
- Verify the OpenAPI Generator configuration in your main `pom.xml`

### Permission denied (Bash)

- Make the script executable: `chmod +x create-submodules.sh`

## Customization

You can modify the script to:

- Change which files are removed from submodules
- Modify the backup file names
- Add custom validation logic
- Change the modules section placement in `pom.xml`
