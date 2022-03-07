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

# If `forceResolution`, then delete the `Package.resolved`
if [ "$forceResolution" = true ] || [ "$forceResolution" = 'true' ]; then
	echo "Deleting Package.resolved to force it to be regenerated under new format."
	rm -rf "$RESOLVED_PATH" 2> /dev/null
fi

# Cleanup Caches
XCODEBUILD_SETTINGS=""
if [ ! -z "$workspace" ]; then
	XCODEBUILD_SETTINGS="-workspace=\"$workspace\" -scheme=\"$scheme\""
fi

DERIVED_DATA=$(xcodebuild $XCODEBUILD_SETTINGS -showBuildSettings -disableAutomaticPackageResolution | grep -m 1 BUILD_DIR | grep -oE "\/.*" | sed 's|/Build/Products||')
SPM_CACHE="~/Library/Caches/org.swift.swiftpm/"

rm -rf "$DERIVED_DATA"
rm -rf "$CACHE_PATH"

# Resolve Dependencies
echo "::group::xcodebuild resolve dependencies"
xcodebuild -resolvePackageDependencies
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
