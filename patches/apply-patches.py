#!/usr/bin/env python3
"""
Patch script for Talend ESB Studio SE build.
Removes defunct propertymapper-maven-plugin references.
"""
import re
import glob
import sys

def patch_pom(filepath):
    """Remove defunct plugin references from a pom.xml file."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"File not found: {filepath}")
        return False

    original = content

    # Remove the trojanbug pluginRepository block
    content = re.sub(
        r'<pluginRepository>\s*<id>trojanbug\.plugins</id>.*?</pluginRepository>',
        '',
        content,
        flags=re.DOTALL
    )

    # Remove the propertymapper-maven-plugin from pluginManagement
    content = re.sub(
        r'<plugin>\s*<groupId>eu\.trojanbug\.maven\.plugins</groupId>\s*<artifactId>propertymapper-maven-plugin</artifactId>.*?</plugin>',
        '',
        content,
        flags=re.DOTALL
    )

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Patched: {filepath}")
        return True
    return False

def main():
    print("=== Applying patches to Talend ESB Studio SE ===")

    # Patch main pom.xml
    main_pom = '/build/main/plugins/pom.xml'
    if patch_pom(main_pom):
        print("Main pom.xml patched successfully")
    else:
        print("Main pom.xml - no changes needed or file not found")

    # Patch child poms
    patched_count = 0
    for pom in glob.glob('/build/main/plugins/*/pom.xml'):
        if patch_pom(pom):
            patched_count += 1

    print(f"Patched {patched_count} child pom.xml files")
    print("=== Patching complete ===")
    return 0

if __name__ == '__main__':
    sys.exit(main())
