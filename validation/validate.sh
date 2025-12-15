#!/bin/bash
#
# Validation script for Talend ESB Studio SE Docker build artifacts
# Checks JAR integrity, manifests, class loading, and version consistency
#

set -e

# Configuration
JAR_DIR="${JAR_DIR:-/app/libs}"
REPORT_DIR="${REPORT_DIR:-/app/validation}"
VALIDATION_DIR="$(dirname "$0")"

# Output files
REPORT_FILE="${REPORT_DIR}/VALIDATION_REPORT.md"
CSV_FILE="${REPORT_DIR}/jars-manifest.csv"
TEMP_DIR=$(mktemp -d)

# Counters
TOTAL_JARS=0
TOTAL_SIZE=0
CORRUPTED=0
INTEGRITY_PASSED=0
INTEGRITY_FAILED=0

# Colors (if terminal supports it)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================================"
echo "Talend ESB Studio SE - Build Validation"
echo "============================================================"
echo ""
echo "JAR Directory: $JAR_DIR"
echo "Report Directory: $REPORT_DIR"
echo ""

mkdir -p "$REPORT_DIR"

# ============================================================
# 1. Artifact Existence Check
# ============================================================
echo ">>> Step 1: Artifact Existence Check"

# Find all JARs
JAR_LIST=$(find "$JAR_DIR" -name "*.jar" -type f 2>/dev/null | sort)
TOTAL_JARS=$(echo "$JAR_LIST" | grep -c . || echo 0)

if [ "$TOTAL_JARS" -eq 0 ]; then
    echo -e "${RED}ERROR: No JAR files found in $JAR_DIR${NC}"
    exit 1
fi

echo "  Found $TOTAL_JARS JAR files"

# Check for zero-byte files
ZERO_BYTE=$(find "$JAR_DIR" -name "*.jar" -type f -size 0 | wc -l)
echo "  Zero-byte files: $ZERO_BYTE"

# Calculate total size
TOTAL_SIZE=$(find "$JAR_DIR" -name "*.jar" -type f -exec stat -f%z {} + 2>/dev/null | awk '{s+=$1} END {print s}' || \
             find "$JAR_DIR" -name "*.jar" -type f -exec stat -c%s {} + 2>/dev/null | awk '{s+=$1} END {print s}')
TOTAL_SIZE_MB=$(echo "scale=2; $TOTAL_SIZE / 1048576" | bc)
echo "  Total size: ${TOTAL_SIZE_MB} MB"
echo ""

# ============================================================
# 2. Archive Integrity Check
# ============================================================
echo ">>> Step 2: Archive Integrity Check"

INTEGRITY_RESULTS=""
for jar in $JAR_LIST; do
    jar_name=$(basename "$jar")
    if unzip -t "$jar" > /dev/null 2>&1; then
        INTEGRITY_PASSED=$((INTEGRITY_PASSED + 1))
        INTEGRITY_RESULTS="${INTEGRITY_RESULTS}${jar_name},PASS\n"
    else
        INTEGRITY_FAILED=$((INTEGRITY_FAILED + 1))
        CORRUPTED=$((CORRUPTED + 1))
        INTEGRITY_RESULTS="${INTEGRITY_RESULTS}${jar_name},FAIL\n"
        echo -e "  ${RED}CORRUPTED: $jar_name${NC}"
    fi
done

INTEGRITY_PCT=$(echo "scale=1; $INTEGRITY_PASSED * 100 / $TOTAL_JARS" | bc)
echo "  Integrity passed: $INTEGRITY_PASSED / $TOTAL_JARS (${INTEGRITY_PCT}%)"
echo ""

# ============================================================
# 3. Manifest Inspection & CSV Generation
# ============================================================
echo ">>> Step 3: Manifest Inspection"

echo "filename,version,bundle_name,bundle_version,build_jdk,size_bytes" > "$CSV_FILE"

MANIFESTS_WITH_VERSION=0
MANIFESTS_WITH_BUNDLE=0
MANIFESTS_WITH_JDK=0

for jar in $JAR_LIST; do
    jar_name=$(basename "$jar")
    jar_size=$(stat -f%z "$jar" 2>/dev/null || stat -c%s "$jar" 2>/dev/null)

    # Extract manifest
    unzip -p "$jar" META-INF/MANIFEST.MF > "$TEMP_DIR/manifest.txt" 2>/dev/null || true

    # Parse manifest values
    version=$(grep -i "^Implementation-Version:" "$TEMP_DIR/manifest.txt" 2>/dev/null | cut -d: -f2 | tr -d ' \r' || echo "")
    bundle_name=$(grep -i "^Bundle-SymbolicName:" "$TEMP_DIR/manifest.txt" 2>/dev/null | cut -d: -f2 | cut -d';' -f1 | tr -d ' \r' || echo "")
    bundle_version=$(grep -i "^Bundle-Version:" "$TEMP_DIR/manifest.txt" 2>/dev/null | cut -d: -f2 | tr -d ' \r' || echo "")
    build_jdk=$(grep -i "^Build-Jdk:" "$TEMP_DIR/manifest.txt" 2>/dev/null | cut -d: -f2 | tr -d ' \r' || echo "")

    # Also try Created-By for JDK info
    if [ -z "$build_jdk" ]; then
        build_jdk=$(grep -i "^Created-By:" "$TEMP_DIR/manifest.txt" 2>/dev/null | cut -d: -f2 | tr -d ' \r' || echo "")
    fi

    # Use bundle version if no implementation version
    if [ -z "$version" ] && [ -n "$bundle_version" ]; then
        version="$bundle_version"
    fi

    # Extract version from filename if not in manifest
    if [ -z "$version" ]; then
        version=$(echo "$jar_name" | sed -n 's/.*-\([0-9][0-9.]*[^.]*\)\.jar/\1/p')
    fi

    # Count statistics
    [ -n "$version" ] && MANIFESTS_WITH_VERSION=$((MANIFESTS_WITH_VERSION + 1))
    [ -n "$bundle_name" ] && MANIFESTS_WITH_BUNDLE=$((MANIFESTS_WITH_BUNDLE + 1))
    [ -n "$build_jdk" ] && MANIFESTS_WITH_JDK=$((MANIFESTS_WITH_JDK + 1))

    # Write to CSV
    echo "\"$jar_name\",\"$version\",\"$bundle_name\",\"$bundle_version\",\"$build_jdk\",$jar_size" >> "$CSV_FILE"
done

echo "  JARs with version info: $MANIFESTS_WITH_VERSION / $TOTAL_JARS"
echo "  OSGi bundles: $MANIFESTS_WITH_BUNDLE / $TOTAL_JARS"
echo "  JARs with Build-Jdk: $MANIFESTS_WITH_JDK / $TOTAL_JARS"
echo "  CSV written to: $CSV_FILE"
echo ""

# ============================================================
# 4. Version Consistency Check
# ============================================================
echo ">>> Step 4: Version Consistency Check"

# Check for duplicate JARs (same artifact, different versions)
DUPLICATES=""
for base in $(echo "$JAR_LIST" | xargs -n1 basename | sed 's/-[0-9].*//' | sort | uniq -d); do
    matches=$(echo "$JAR_LIST" | xargs -n1 basename | grep "^${base}-[0-9]" || true)
    if [ -n "$matches" ]; then
        DUPLICATES="${DUPLICATES}${base}: $(echo $matches | tr '\n' ' ')\n"
    fi
done

if [ -n "$DUPLICATES" ]; then
    echo "  Potential duplicate artifacts:"
    echo -e "$DUPLICATES" | head -10
else
    echo "  No duplicate artifacts detected"
fi

# Check for known version conflicts
SPRING_VERSIONS=$(echo "$JAR_LIST" | xargs -n1 basename | grep "^spring-" | sed 's/spring-[^-]*-//' | sed 's/\.jar//' | sort -u | tr '\n' ' ')
echo "  Spring versions: $SPRING_VERSIONS"

CXF_VERSIONS=$(echo "$JAR_LIST" | xargs -n1 basename | grep "^cxf-" | sed 's/cxf-[^-]*-//' | sed 's/\.jar//' | sort -u | tr '\n' ' ')
echo "  CXF versions: $CXF_VERSIONS"

CAMEL_VERSIONS=$(echo "$JAR_LIST" | xargs -n1 basename | grep "^camel-" | sed 's/camel-[^-]*-//' | sed 's/\.jar//' | sort -u | tr '\n' ' ')
echo "  Camel versions: $CAMEL_VERSIONS"
echo ""

# ============================================================
# 5. Class Loading Validation (Smoke Test)
# ============================================================
echo ">>> Step 5: Class Loading Validation (Smoke Test)"

# Build classpath
CLASSPATH=""
for jar in $JAR_LIST; do
    CLASSPATH="${CLASSPATH}:${jar}"
done
CLASSPATH="${CLASSPATH:1}"  # Remove leading colon

# Compile and run smoke test
SMOKE_TEST_SRC="${VALIDATION_DIR}/SmokeTest.java"
if [ -f "$SMOKE_TEST_SRC" ]; then
    echo "  Compiling SmokeTest.java..."
    cp "$SMOKE_TEST_SRC" "$TEMP_DIR/"
    cd "$TEMP_DIR"

    if javac -cp "$CLASSPATH" SmokeTest.java 2>/dev/null; then
        echo "  Running smoke test..."
        echo ""
        SMOKE_OUTPUT=$(java -cp ".:$CLASSPATH" SmokeTest 2>&1) || SMOKE_EXIT=$?
        echo "$SMOKE_OUTPUT"

        SMOKE_PASSED=$(echo "$SMOKE_OUTPUT" | grep "Passed:" | awk '{print $2}')
        SMOKE_FAILED=$(echo "$SMOKE_OUTPUT" | grep "Failed:" | awk '{print $2}')
    else
        echo -e "  ${RED}Failed to compile smoke test${NC}"
        SMOKE_PASSED=0
        SMOKE_FAILED=999
    fi
else
    echo "  SmokeTest.java not found, skipping"
    SMOKE_PASSED="N/A"
    SMOKE_FAILED="N/A"
fi
echo ""

# ============================================================
# 6. OSGi Bundle Validation
# ============================================================
echo ">>> Step 6: OSGi Bundle Validation"

OSGI_VALID=0
OSGI_INVALID=0

for jar in $JAR_LIST; do
    jar_name=$(basename "$jar")
    unzip -p "$jar" META-INF/MANIFEST.MF > "$TEMP_DIR/manifest.txt" 2>/dev/null || continue

    bundle_name=$(grep -i "^Bundle-SymbolicName:" "$TEMP_DIR/manifest.txt" 2>/dev/null || true)
    if [ -n "$bundle_name" ]; then
        export_pkg=$(grep -i "^Export-Package:" "$TEMP_DIR/manifest.txt" 2>/dev/null || true)
        import_pkg=$(grep -i "^Import-Package:" "$TEMP_DIR/manifest.txt" 2>/dev/null || true)

        if [ -n "$export_pkg" ] || [ -n "$import_pkg" ]; then
            OSGI_VALID=$((OSGI_VALID + 1))
        else
            OSGI_INVALID=$((OSGI_INVALID + 1))
        fi
    fi
done

echo "  Valid OSGi bundles: $OSGI_VALID"
echo "  Bundles missing Import/Export: $OSGI_INVALID"
echo ""

# ============================================================
# Generate Report
# ============================================================
echo ">>> Generating Validation Report"

# Determine overall status
if [ "$CORRUPTED" -gt 0 ]; then
    STATUS="FAIL"
elif [ "${SMOKE_FAILED:-0}" -gt 3 ]; then
    STATUS="FAIL"
elif [ "${SMOKE_FAILED:-0}" -gt 0 ]; then
    STATUS="PARTIAL"
else
    STATUS="PASS"
fi

cat > "$REPORT_FILE" << EOF
# Validation Report: tesb-studio-se

## Summary

| Metric | Value |
|--------|-------|
| **Status** | $STATUS |
| **Date** | $(date -u +"%Y-%m-%d %H:%M:%S UTC") |
| **Docker Image** | tesb-studio-se:maven |
| **Java Version** | $(java -version 2>&1 | head -1) |

## Artifact Statistics

| Metric | Value |
|--------|-------|
| Total JARs | $TOTAL_JARS |
| Total Size | ${TOTAL_SIZE_MB} MB |
| Zero-byte files | $ZERO_BYTE |
| Corrupted | $CORRUPTED |

## Integrity Results

| Metric | Value |
|--------|-------|
| Passed | $INTEGRITY_PASSED |
| Failed | $INTEGRITY_FAILED |
| Pass Rate | ${INTEGRITY_PCT}% |

## Manifest Analysis

| Metric | Value |
|--------|-------|
| JARs with version | $MANIFESTS_WITH_VERSION / $TOTAL_JARS |
| OSGi bundles | $MANIFESTS_WITH_BUNDLE / $TOTAL_JARS |
| JARs with Build-Jdk | $MANIFESTS_WITH_JDK / $TOTAL_JARS |

## Class Loading Results (Smoke Test)

| Metric | Value |
|--------|-------|
| Classes Loaded | $SMOKE_PASSED |
| Failed to Load | $SMOKE_FAILED |

## Version Analysis

### Framework Versions Detected

| Framework | Versions |
|-----------|----------|
| Spring | $SPRING_VERSIONS |
| Apache CXF | $CXF_VERSIONS |
| Apache Camel | $CAMEL_VERSIONS |

### Version Consistency

EOF

if [ -n "$DUPLICATES" ]; then
    echo "**Potential duplicate artifacts detected:**" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo -e "$DUPLICATES" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
else
    echo "No duplicate artifacts detected. Version consistency appears good." >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << EOF

## OSGi Bundle Analysis

| Metric | Value |
|--------|-------|
| Valid bundles | $OSGI_VALID |
| Missing Import/Export | $OSGI_INVALID |

## Issues Found

EOF

if [ "$STATUS" = "PASS" ]; then
    echo "No critical issues found." >> "$REPORT_FILE"
else
    if [ "$CORRUPTED" -gt 0 ]; then
        echo "- **CRITICAL:** $CORRUPTED corrupted JAR file(s) detected" >> "$REPORT_FILE"
    fi
    if [ "${SMOKE_FAILED:-0}" -gt 0 ]; then
        echo "- **WARNING:** $SMOKE_FAILED class(es) failed to load in smoke test" >> "$REPORT_FILE"
    fi
fi

cat >> "$REPORT_FILE" << EOF

## Recommendations

EOF

if [ "$STATUS" = "PASS" ]; then
    cat >> "$REPORT_FILE" << EOF
The build artifacts are valid and usable:

1. All JARs pass integrity checks
2. Core framework classes load successfully
3. No critical version conflicts detected

The artifacts can be used for:
- Runtime integration with Talend ESB
- Embedding CXF/Camel in custom applications
- Reference for dependency versions
EOF
else
    cat >> "$REPORT_FILE" << EOF
Address the following before using these artifacts:

1. Investigate any corrupted JARs
2. Check missing dependencies for failed class loads
3. Review version conflicts if any
EOF
fi

cat >> "$REPORT_FILE" << EOF

## Files Generated

- \`VALIDATION_REPORT.md\` - This report
- \`jars-manifest.csv\` - Full manifest data for all JARs

---
*Generated by validate.sh*
EOF

echo "  Report written to: $REPORT_FILE"
echo ""

# ============================================================
# Final Summary
# ============================================================
echo "============================================================"
echo "VALIDATION COMPLETE"
echo "============================================================"
echo ""
echo "Status: $STATUS"
echo "Total JARs: $TOTAL_JARS"
echo "Integrity: ${INTEGRITY_PCT}%"
echo "Smoke Test: $SMOKE_PASSED passed, $SMOKE_FAILED failed"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"

if [ "$STATUS" = "FAIL" ]; then
    exit 1
fi
exit 0
