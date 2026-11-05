import re

with open("/Users/abhishek/Desktop/Logos/Appicon.svg", "r") as f:
    content = f.read()

# Find the background rect
# <rect x="0" y="0" width="160" height="160" rx="36" fill="url(#bgIcon)"/>
bg_match = re.search(r'<rect x="0" y="0" width="160" height="160" [^>]+/>', content)
bg_rect = bg_match.group(0) if bg_match else ""

# Scale factor (0.6 is safe for most launchers)
scale = 0.65
offset = (160 - (160 * scale)) / 2

# Extract everything else
body = content.replace(bg_rect, "").replace('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160" width="160" height="160">', "").replace("</svg>", "")

new_content = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160" width="160" height="160">
  {bg_rect}
  <g transform="translate({offset}, {offset}) scale({scale})">
    {body}
  </g>
</svg>"""

with open("Appicon_padded.svg", "w") as f:
    f.write(new_content)
