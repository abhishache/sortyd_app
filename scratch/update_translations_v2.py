import json

path = "/Users/abhishek/Desktop/sortyd/Sortyd/Localizable.xcstrings"
with open(path, 'r') as f:
    data = json.load(f)

strings = data.get("strings", {})

updates = {
    "Km": {
        "es": "Km",
        "ar": "كم"
    },
    "Regular": {
        "es": "Regular",
        "ar": "عادي"
    },
    "Distance": {
        "es": "Distancia",
        "ar": "مسافة"
    },
    "Calories": {
        "es": "Calorías",
        "ar": "سعرات حرارية"
    },
    "Only one task from step count, calorie count or distance measure is allowed.": {
        "es": "Solo se permite una tarea de pasos, calorías o distancia.",
        "ar": "يُسمح بمهمة واحدة فقط من عد الخطوات أو السعرات أو المسافة."
    },
    "Only one step-counting task allowed per list.": {
        "es": "Solo se permite una tarea de conteo de pasos por lista.",
        "ar": "يُسمح بمهمة واحدة فقط لعد الخطوات في كل قائمة."
    },
    "Only one calorie-tracking task allowed per list.": {
        "es": "Solo se permite una tarea de seguimiento de calorías por lista.",
        "ar": "يُسمح بمهمة واحدة فقط لتتبع السعرات الحرارية في كل قائمة."
    },
    "Only one distance-tracking task allowed per list.": {
        "es": "Solo se permite una tarea de seguimiento de distancia por lista.",
        "ar": "يُسمح بمهمة واحدة فقط لتتبع المسافة في كل قائمة."
    },
    "Anytime": {
        "es": "En cualquier momento",
        "ar": "في أي وقت"
    },
    "Completed": {
        "es": "Completado",
        "ar": "مكتمل"
    },
    "Due %@": {
        "es": "Vence %@",
        "ar": "موعد %@"
    }
}

for key, translations in updates.items():
    if key not in strings:
        strings[key] = {}
    
    if "localizations" not in strings[key]:
        strings[key]["localizations"] = {}
    
    for lang, val in translations.items():
        if lang not in strings[key]["localizations"]:
            strings[key]["localizations"][lang] = {"stringUnit": {"state": "translated", "value": val}}
        else:
            # If stringUnit exists, update it
            if "stringUnit" not in strings[key]["localizations"][lang]:
                 strings[key]["localizations"][lang]["stringUnit"] = {"state": "translated", "value": val}
            else:
                 strings[key]["localizations"][lang]["stringUnit"]["value"] = val
                 strings[key]["localizations"][lang]["stringUnit"]["state"] = "translated"

data["strings"] = strings

with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("Updated Localizable.xcstrings")
