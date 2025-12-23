echo "Starting swaybg at $(date)" >> /tmp/swaybg-debug.log
swaybg -o '*' -i /home/payton/Pictures/Wallpapers/blackandwhiteearth.jpg >> /tmp/swaybg-debug.log 2>&1 &
echo "swaybg PID: $!" >> /tmp/swaybg-debug.log
