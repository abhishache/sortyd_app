import re

with open("/Users/abhishek/Desktop/Logos/Appicon.svg", "r") as f:
    content = f.read()

# Change background to white
content = re.sub(r'fill="url\(#bgIcon\)"', 'fill="#FFFFFF"', content)

# Change dots to dark
content = content.replace('fill="#FFFFFF" opacity="0.04"', 'fill="#000000" opacity="0.06"')

# Change empty bar backgrounds to a lighter grey
content = content.replace('fill="#1C1E30"', 'fill="#F0F0F0"')

# Change text to dark
content = content.replace('fill="#FFFFFF" opacity="0.35"', 'fill="#13141F" opacity="0.6"')

with open("Appicon_light.svg", "w") as f:
    f.write(content)
