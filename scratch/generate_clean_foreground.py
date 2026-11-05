import re

with open("/Users/abhishek/Desktop/Logos/Appicon.svg", "r") as f:
    content = f.read()

# 1. Remove background rect
content = re.sub(r'<rect x="0" y="0" width="160" height="160" rx="36" fill="url\(#bgIcon\)"\s?/>', '', content)

# 2. Extract elements (defs + everything else)
# Ensure we keep defs for gradients
# We want the output to be a 160x160 SVG with just the logo elements centered.
# The logo is already centered in the 160x160 SVG.
# For adaptive foreground, the 108dp icon has a safe zone.
# Standard 108dp icon: logo should be ~72dp.
# So we scale by 72/108 = 0.66.

scale = 0.66
offset = (160 - (160 * scale)) / 2

# Find defs
defs_match = re.search(r'<defs>.*?</defs>', content, re.DOTALL)
defs = defs_match.group(0) if defs_match else ""

# Remove defs and svg tags to get body
body = content.replace(defs, "").replace('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160" width="160" height="160">', "").replace("</svg>", "").strip()

new_content = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160" width="160" height="160">
  {defs}
  <g transform="translate({offset}, {offset}) scale({scale})">
    {body}
  </g>
</svg>"""

with open("ic_launcher_foreground.svg", "w") as f:
    f.write(new_content)
