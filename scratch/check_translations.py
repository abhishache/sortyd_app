import json

keys_to_check = [
    "Steps", "Cal", "Km", "Regular", "Distance", "Calories",
    "Only one task from step count, calorie count or distance measure is allowed.",
    "Only one step-counting task allowed per list.",
    "Only one calorie-tracking task allowed per list.",
    "Only one distance-tracking task allowed per list.",
    "Due", "Anytime", "Completed"
]

path = "/Users/abhishek/Desktop/sortyd/Sortyd/Localizable.xcstrings"
with open(path, 'r') as f:
    data = json.load(f)

strings = data.get("strings", {})

for key in keys_to_check:
    if key in strings:
        print(f"Key: {key}")
        locs = strings[key].get("localizations", {})
        for lang in ["es", "ar"]:
            val = locs.get(lang, {}).get("stringUnit", {}).get("value", "MISSING")
            print(f"  {lang}: {val}")
    else:
        print(f"Key: {key} - MISSING FROM STRINGS")
