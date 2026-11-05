import re

with open("/Users/abhishek/Desktop/Logos/Appicon.svg", "r") as f:
    content = f.read()

# Remove the background rect
content = re.sub(r'<rect x="0" y="0" width="160" height="160" rx="36" fill="url\(#bgIcon\)"\s?/>', '', content)

# Wrap the rest in a group and scale it down to ~70% and center it
# Original is 160x160. We want it to be ~110x110 inside a 160x160 frame.
# Scale = 110/160 = 0.6875
# Offset = (160 - 110) / 2 = 25
scale = 0.65
offset = (160 - (160 * scale)) / 2

# Find the end of defs
defs_end = content.find("</defs>") + 7
header = content[:defs_end]
body = content[defs_end:].strip()
body = body.replace("</svg>", "")

new_content = f"""{header}
  <g transform="translate({offset}, {offset}) scale({scale})">
    {body}
  </g>
</svg>"""

with open("Appicon_foreground.svg", "w") as f:
    f.write(new_content)
