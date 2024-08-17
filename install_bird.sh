#!/bin/bash

# Set variables
conf_file="bird.conf"

# Update package list
echo "Updating package list..."
apt update
echo "Package list updated."

# Upgrade the system
echo "Upgrading system packages..."
apt upgrade -y
echo "System Packages have been upgraded."

# Install BIRD dependencies (Ubuntu 22.04)
echo "Installing dependencies..."
apt install software-properties-common curl libnl-3-dev libnl-genl-3-dev libelf-dev -y
echo "Dependencies installed."

# Add repository for Bird version from
echo 'deb http://download.opensuse.org/repositories/home:/linuxgemini:/bird-latest-debian/xUbuntu_22.04/ /' | sudo tee /etc/apt/sources.list.d/bird-latest-debian.list
curl -fsSL https://download.opensuse.org/repositories/home:linuxgemini:bird-latest-debian/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_linuxgemini_bird-latest-debian.gpg > /dev/null
echo "Adding repository for Bird from https://download.opensuse.org/repositories/home:/linuxgemini:/bird-latest-debian/xUbuntu_22.04"
echo "Repository added."

# Update package list again after repository addition
echo "Updating package list again..."
apt update
echo "Package list updated."

# Install Bird from the specified version and source
echo "Installing BIRD from https://download.opensuse.org/repositories/home:/linuxgemini:/bird-latest-debian/xUbuntu_22.04/amd64/bird2_2.15.1-cznic.1_amd64.deb..."
apt install bird2=2.15.1-cznic.1 -y
echo "BIRD installed from specified version and source."

# Function to discover interfaces from netplan
discover_interfaces_netplan() {
  interface_list=()
  for file in /etc/netplan/*.yaml; do
    if ! grep -qEi "^[ \t]*network:\{.*" "$file"; then
      continue
    fi
    while IFS= read -r line; do
      match=$(grep -oEi "^[ \t]*.*[0-9]+:" <<< "$line")
      if [ ! -z "${match}" ]; then
        interface=${match##*:}
        interface_list+=("$interface")
      fi
    done < "$file"
  done
}

# Function to discover interfaces from /etc/network/interfaces
discover_interfaces_old() {
  network_interfaces=$(grep -oEi "(eth|wlan)[0-9]+.*" "/etc/network/interfaces")
  echo "${network_interfaces}"
}

# Discover network interfaces
echo "Discovering network interfaces..."
if [ -d "/etc/netplan" ]; then
    interface_list=($(discover_interfaces_netplan))
else
    network_interfaces=$(discover_interfaces_old)
fi

# Generate BGP neighbors file based on discovered data
echo "Generating BGP neighbors file..."
cat <<EOF > /tmp/neighbors.txt
$(ip addr show dev "$interface_list")
EOF
echo "BGP neighbors file generated."

# Generate configuration file based on discovered data and BGP neighbors
echo "Generating BIRD configuration..."
cat <<EOF > "$conf_file"
protocol kernel {
  scan all;
}

protocol bgp $INTERFACE_LIST {
  neighbor /tmp/neighbors.txt weight 100;
}
EOF
echo "Configuration generated and saved to $conf_file"

# Print the generated configuration file
echo "Configuration:"
cat "$conf_file"

# Backup existing BIRD configuration
if [ -f "/etc/bird/bird.conf" ]; then
    echo "Backing up existing BIRD configuration..."
    cp /etc/bird/bird.conf "${conf_file}.bak"
fi

# Move generated configuration to final location
echo "Moving generated configuration to /etc/bird/bird.conf..."
mv "$conf_file" "/etc/bird/bird.conf"

echo "Automatic BIRD setup complete!"
