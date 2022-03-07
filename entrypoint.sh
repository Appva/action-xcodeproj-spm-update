#!/bin/bash
set -e

# Load Options
while getopts "a:b:c:d:e:" o; do
   case "${o}" in
       a)
         export directory=${OPTARG}
       ;;
       b)
         export forceResolution=${OPTARG}
       ;;
       c)
         export failWhenOutdated=${OPTARG}
       ;;
       d)
         export workspace=${OPTARG}
       ;;
       e)
         export scheme=${OPTARG}
       ;;
  esac
done

# Workspace sanity check
if [ ! -z "$workspace" ] && [ -z "$scheme" ]; then
	echo "When workspace is defined, you must also define a scheme."
	exit 1
fi

PROJECT_TYPE=".xcodeproj"
if [ ! -z "$workspace" ]; then
	PROJECT_TYPE=".xcworkspace"
fi

# Change Directory
if [ "$directory" != "." ]; then
	echo "Changing directory to '$directory'."
	cd $directory
fi

# Identify `Package.resolved` location
RESOLVED_PATH=$(find . -type f -name "Package.resolved" | grep "$PROJECT_TYPE")
CHECKSUM=$(shasum "$RESOLVED_PATH")

echo "Identified Package.resolved at '$RESOLVED_PATH'."

# Find DerivedData folder, needs to be done before deleting the Package.resolved file in case forceResolution is true.
if [ ! -z "$workspace" ]; then
  DERIVED_DATA=$(xcodebuild -workspace "$workspace" -scheme "$scheme" -showBuildSettings -disableAutomaticPackageResolution | grep -m 1 BUILD_DIR | grep -oE "\/.*" | sed 's|/Build/Products||')
else
  DERIVED_DATA=$(xcodebuild -showBuildSettings -disableAutomaticPackageResolution | grep -m 1 BUILD_DIR | grep -oE "\/.*" | sed 's|/Build/Products||')
fi

# If `forceResolution`, then delete the `Package.resolved`
if [ "$forceResolution" = true ] || [ "$forceResolution" = 'true' ]; then
	echo "Deleting Package.resolved to force it to be regenerated under new format."
	rm -rf "$RESOLVED_PATH" 2> /dev/null
fi

# Define the SPM cache folder
SPM_CACHE="~/Library/Caches/org.swift.swiftpm/"

# Cleanup Caches
rm -rf "$DERIVED_DATA"
rm -rf "$CACHE_PATH"

# Resolve Dependencies
echo "::group::xcodebuild resolve dependencies"
if [ ! -z "$workspace" ]; then
  xcodebuild -resolvePackageDependencies -workspace "$workspace" -scheme "$scheme"
else
  xcodebuild -resolvePackageDependencies
fi
echo "::endgroup"

# Determine Changes
NEWCHECKSUM=$(shasum "$RESOLVED_PATH")

if [ "$CHECKSUM" != "$NEWCHECKSUM" ]; then
	echo "::set-output name=dependenciesChanged::true"

	if [ "$failWhenOutdated" = true ] || [ "$failWhenOutdated" = 'true' ]; then
		exit 1
	fi
else
	echo "::set-output name=dependenciesChanged::false"
fi
