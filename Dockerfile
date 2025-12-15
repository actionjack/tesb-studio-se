# Dockerfile for building Talend ESB Studio SE
# This is an archaeological build attempt for a legacy codebase (2006-2014 era)
#
# IMPORTANT: This repository contains only the ESB-specific plugins for Talend Studio.
# It is designed to be built as part of the full Talend Open Studio build system
# using the studio-se-master gitslave setup with a target platform.
#
# This Dockerfile attempts to:
# 1. Run the existing Maven dependency management build
# 2. Apply patches for defunct repositories
#
# Expected outcome: Partial success - dependency downloads work, but full compilation
# requires the complete Talend Open Studio target platform.

FROM eclipse-temurin:8-jdk AS builder

# Build arguments for customization
ARG MAVEN_VERSION=3.6.3
ARG USER_HOME_DIR="/root"

# Install Maven
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
    | tar -xzC /opt \
    && ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven

ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

# Set Maven memory options for large builds
ENV MAVEN_OPTS="-Xmx2048m -XX:MaxMetaspaceSize=512m"

# Working directory
WORKDIR /build

# Copy source code
COPY . /build/

# ============================================================================
# PATCH 1: Remove defunct propertymapper-maven-plugin repository
# The Google Code repository is no longer available (shutdown 2016).
# We use a Python script for reliable XML manipulation.
# ============================================================================
RUN apt-get update && apt-get install -y python3 && rm -rf /var/lib/apt/lists/*
RUN python3 /build/patches/apply-patches.py

# ============================================================================
# Stage 1: Maven Dependency Build
# Build the library management modules which download dependencies to lib/ folders
# Using released version 5.6.2 instead of 5.6.0-SNAPSHOT
# ============================================================================
RUN echo "=== Stage 1: Maven Dependency Build (using released 5.6.2) ===" && \
    cd /build/main/plugins && \
    mvn clean install -DskipTests -B -e \
        -Dtesb.version=5.6.2 \
        2>&1 | tee /build/maven-build.log; \
    BUILD_STATUS=$?; \
    echo "Maven build exit status: $BUILD_STATUS" >> /build/maven-build.log; \
    if [ $BUILD_STATUS -eq 0 ]; then \
        echo "BUILD SUCCESS" > /build/build-status.txt; \
    else \
        echo "BUILD FAILED (exit code: $BUILD_STATUS)" > /build/build-status.txt; \
    fi

# ============================================================================
# Stage 2: Analyze build results
# ============================================================================
RUN echo "=== Build Artifacts ===" && \
    echo "Downloaded JARs in lib directories:" && \
    find /build -type d -name "lib" -exec sh -c 'echo "=== {} ===" && ls -la "{}" 2>/dev/null | head -20' \; && \
    echo "" && \
    echo "Total JAR files found:" && \
    find /build/main/plugins -name "*.jar" -type f | wc -l

# Create comprehensive build summary
RUN echo "=== Build Summary ===" > /build/build-summary.txt && \
    echo "Date: $(date)" >> /build/build-summary.txt && \
    echo "" >> /build/build-summary.txt && \
    echo "Build Status:" >> /build/build-summary.txt && \
    cat /build/build-status.txt >> /build/build-summary.txt && \
    echo "" >> /build/build-summary.txt && \
    echo "Java version:" >> /build/build-summary.txt && \
    java -version 2>&1 >> /build/build-summary.txt && \
    echo "" >> /build/build-summary.txt && \
    echo "Maven version:" >> /build/build-summary.txt && \
    mvn -version >> /build/build-summary.txt && \
    echo "" >> /build/build-summary.txt && \
    echo "JAR files downloaded:" >> /build/build-summary.txt && \
    find /build/main/plugins -name "*.jar" -type f | wc -l >> /build/build-summary.txt && \
    echo "" >> /build/build-summary.txt && \
    echo "Lib directories:" >> /build/build-summary.txt && \
    find /build/main/plugins -type d -name "lib" -exec sh -c 'echo "{}: $(ls "{}" 2>/dev/null | wc -l) files"' \; >> /build/build-summary.txt && \
    echo "" >> /build/build-summary.txt && \
    echo "Build log tail (last 30 lines):" >> /build/build-summary.txt && \
    tail -30 /build/maven-build.log >> /build/build-summary.txt 2>/dev/null || true

# Final stage - minimal image with build results
FROM eclipse-temurin:8-jre-alpine AS final

WORKDIR /app

# Copy build outputs
COPY --from=builder /build/main/plugins/*/lib /app/libs/
COPY --from=builder /build/maven-build.log /app/
COPY --from=builder /build/build-summary.txt /app/
COPY --from=builder /build/build-status.txt /app/

# Default command shows build summary
CMD ["cat", "/app/build-summary.txt"]
