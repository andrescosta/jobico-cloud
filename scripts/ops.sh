#!/bin/bash

# Default values
DEFAULT_USER_NAME="default_user"
DEFAULT_GUEST_NAME="default_guest"
DEFAULT_PRESEED_FILE="default_preseed"
DEFAULT_MAC="default_mac"

# Function to display help message
function display_help {
    echo "Usage: $0 [-u user_name] [-g guest_name] [-p preseed_file] [-m mac]"
    echo "Options:"
    echo "  -u user_name    Specify the user name (default: $DEFAULT_USER_NAME)"
    echo "  -g guest_name   Specify the guest name (default: $DEFAULT_GUEST_NAME)"
    echo "  -p preseed_file Specify the preseed file (default: $DEFAULT_PRESEED_FILE)"
    echo "  -m mac          Specify the MAC address (default: $DEFAULT_MAC)"
    exit 1
}

# Parse command-line options
while getopts ":u:g:p:m:h" opt; do
  case $opt in
    u)
      user_name=$OPTARG
      ;;
    g)
      guest_name=$OPTARG
      ;;
    p)
      preseed_file=$OPTARG
      ;;
    m)
      mac=$OPTARG
      ;;
    h)
      display_help
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      display_help
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      display_help
      ;;
  esac
done

# Set default values if not provided
user_name=${user_name:-$DEFAULT_USER_NAME}
guest_name=${guest_name:-$DEFAULT_GUEST_NAME}
preseed_file=${preseed_file:-$DEFAULT_PRESEED_FILE}
mac=${mac:-$DEFAULT_MAC}

# Output the values
echo "User Name: $user_name"
echo "Guest Name: $guest_name"
echo "Preseed File: $preseed_file"
echo "MAC: $mac"

