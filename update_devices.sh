#!/bin/bash

RED='\033[0;31m'
ENDCOLOR='\033[0m'

BRANCH="udc"
ANDROID_VERSION="14"

# devices.json

echo "Fetching devices from OTA..."
curl -s "https://api.github.com/repos/Evolution-X/OTA/contents/builds?ref=$BRANCH" | jq -r '.[] | select(.name | endswith(".json")) | .name' | while read -r filename; do
  echo "\"${filename%.json}\""
done | sort -f | jq -s '.' > "devices/devices.json"

echo "Updated devices.json."

# device image fetching

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

# Installation instructions

echo "Creating instructions for devices..."
jq -r '.[]' "devices/devices.json" | while read -r device; do
  md_file="devices/instructions/$device.md"

  if [ ! -f "$md_file" ]; then
    json_url="https://raw.githubusercontent.com/Evolution-X/OTA/refs/heads/$BRANCH/builds/$device.json"
    json_content=$(curl -s "$json_url")

    if [ "$(echo "$json_content" | jq '.response | length')" -gt 0 ]; then
      initial_images=$(echo "$json_content" | jq -r '.response[0].initial_installation_images[]')

      fastboot_commands=""
      for image in $initial_images; do
        if [ "$image" == "super_empty" ]; then
          fastboot_commands+="\`\`\`fastboot wipe-super $image.img\`\`\`\n"
        else
          fastboot_commands+="\`\`\`fastboot flash $image $image.img\`\`\`\n"
        fi
      done
      fastboot_commands+="\`\`\`fastboot reboot recovery\`\`\`\n"
      images_to_download=$(echo "$initial_images" | tr '\n' ' ')
      images_to_download="${images_to_download// /, }"
      images_to_download="${images_to_download%, }, rom"
      download_url="https://sourceforge.net/projects/evolution-x/files/$device/$ANDROID_VERSION/"

      {
        echo "## THESE INSTRUCTIONS ASSUME YOUR DEVICES BOOTLOADER IS ALREADY UNLOCKED"
        echo
        echo "1. Download $images_to_download for $device from [$download_url]($download_url)"
        echo "2. Reboot to bootloader"
        echo "3."
        echo -e "$fastboot_commands"
        echo "4. While in recovery, navigate to Factory reset -> Format data/factory reset and confirm to format the device."
        echo "5. When done formatting, go back to the main menu and then navigate to Apply update -> Apply from ADB"
        echo "6. adb sideload rom.zip (replace \"rom\" with actual filename)"
        echo "7. (optional) Reboot to recovery (fully) to sideload any add-ons"
        echo "8. Reboot to system & #KeepEvolving"
      } > "$md_file"

      echo "Instructions created for $device."
    else
      echo -e "${RED}Json for $device not found on OTA.${ENDCOLOR}"
    fi
  else
    echo "Instructions for $device already exists. Skipping..."
  fi
done
