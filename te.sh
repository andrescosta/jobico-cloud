mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
echo "$mac-$1"
echo "$mac"

echo "$mac"
echo "aaaa'${mac}'"
