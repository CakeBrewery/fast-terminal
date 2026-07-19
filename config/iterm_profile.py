"""Print the "Fast Terminal" iTerm2 dynamic profile as JSON.

Downloads the Snazzy palette from sindresorhus/iterm2-snazzy and overrides
the background to #1b1b1b (Vine Black).
"""
import plistlib
import json
import urllib.request
import sys

url = "https://raw.githubusercontent.com/sindresorhus/iterm2-snazzy/main/Snazzy.itermcolors"
try:
    req = urllib.request.urlopen(url, timeout=10)
    colors = plistlib.loads(req.read())
except Exception as e:
    print(f"Failed to download Snazzy theme: {e}", file=sys.stderr)
    sys.exit(1)

# Set custom background color to #1b1b1b (Vine Black)
colors["Background Color"] = {
    "Alpha Component": 1.0,
    "Red Component": 27/255.0,
    "Green Component": 27/255.0,
    "Blue Component": 27/255.0,
    "Color Space": "sRGB"
}

profile = {
    "Name": "Fast Terminal",
    "Guid": "Fast-Terminal-Profile",
    "Cursor Type": 1,  # Vertical bar
    "Normal Font": "Menlo-Regular 12",
    "Use Separate Colors for Light and Dark Mode": False,
}
# Merge colors into profile
profile.update(colors)

print(json.dumps({"Profiles": [profile]}, indent=2))
