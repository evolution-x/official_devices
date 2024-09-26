#!/bin/bash

RED='\033[0;31m'
ENDCOLOR='\033[0m'

BRANCH="udc"

echo "Fetching devices from OTA..."
curl -s "https://api.github.com/repos/Evolution-X/OTA/contents/builds?ref=$BRANCH" | jq -r '.[] | select(.name | endswith(".json")) | .name' | while read -r filename; do
  echo "\"${filename%.json}\""
done | sort -f | jq -s '.' > "devices/devices.json"

echo "Updated devices.json."

echo "Fetching device images from LineageOS wiki..."
jq -r '.[]' "devices/devices.json" | while read -r device; do
  output_path="devices/images/$device.png"

  if [ -f "$output_path" ]; then
    echo "Image for $device already exists. Skipping..."
    continue
  fi

  image_url="https://raw.githubusercontent.com/LineageOS/lineage_wiki/refs/heads/main/images/devices/$device.png"

  if curl --head --silent --fail "$image_url" > /dev/null; then
    echo "Downloading image for $device..."
    curl -s "$image_url" -o "$output_path"
  else
    echo -e "${RED}Image for $device does not exist on LineageOS wiki.${ENDCOLOR}"
  fi
done

echo "Creating instructions for devices..."
jq -r '.[]' "devices/devices.json" | while read -r device; do
  if [ ! -f "devices/instructions/$device.md" ]; then
    touch "devices/instructions/$device.md"
    echo "Created empty instructions for $device.. Please populate it manually"
  else
    echo "Instructions for $device already exists. Skipping..."
  fi
done
