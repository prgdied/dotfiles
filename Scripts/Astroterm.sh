# Get location from IP geolocation
location=$(curl -s "https://ipapi.co/json/")
lat=$(echo "$location" | jq -r '.latitude')
lon=$(echo "$location" | jq -r '.longitude')

# Fallback to home location if lookup fails
if [ -z "$lat" ] || [ "$lat" = "null" ]; then
    lat="40.7128"  # New York
    lon="-74.0060"
fi

kitty astroterm -m --color --constellations --fps 64 --latitude "$lat" --longitude "$lon" --speed 1
