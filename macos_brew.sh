#!/bin/zsh
# IPSW feed: https://mesu.apple.com/assets/macos/com_apple_macOSIPSW/com_apple_macOSIPSW.xml

# Get the action to execute
action=$1
if [ -z "$action" ]; then
  echo "No action provided"
  echo "Usage: $0 <action>"
  echo "  action: build|publish"
  exit 1
fi

# Define the environment
REGISTRY_HOST=${REGISTRY_HOST:-registry-1.docker.io}
REGISTRY_IMAGE=${REGISTRY_IMAGE:-letiemble/macos-brew}

# Define macOS versions
macos_versions=(
  "sequoia:15.4.1:latest"
)

# Install the required tools
brew install hashicorp/tap/packer
brew install cirruslabs/cli/tart

# Build action
if [ "$action" = "build" ]; then
  # Initialize Packer
  packer init templates/brew.pkr.hcl

  # Loop through macOS versions and build/publish images
  for version in "${macos_versions[@]}"; do
    IFS=':' read -r name ver latest <<< "$version"

    # Build the image
    echo "Building macOS $ver with code name $name"
    packer build -var "macos_codename=$name" -var "macos_version=$ver" templates/brew.pkr.hcl
  done
fi

# Publish action
if [ "$action" = "publish" ]; then
  # Check that environment variables are defined
  if [ -z "${DOCKER_HUB_USER}" ]; then
    echo "DOCKER_HUB_USER is not defined"
    exit 1
  fi
  if [ -z "${DOCKER_HUB_PASSWORD}" ]; then
    echo "DOCKER_HUB_PASSWORD is not defined"
    exit 1
  fi

  # Login to the registry
  echo "${DOCKER_HUB_PASSWORD}" | tart login $REGISTRY_HOST --username "${DOCKER_HUB_USER}" --password-stdin

  for version in "${macos_versions[@]}"; do
    IFS=':' read -r name ver latest <<< "$version"

    # Publish the image
    if [ "$latest" = "latest" ]; then
      tart push "macos-${ver}-brew" "$REGISTRY_HOST/$REGISTRY_IMAGE:$ver" "$REGISTRY_HOST/$REGISTRY_IMAGE:$latest"
    else
      tart push "macos-${ver}-brew" "$REGISTRY_HOST/$REGISTRY_IMAGE:$ver"
    fi
  done

  # Logout from the registry
  tart logout $REGISTRY_HOST
fi
