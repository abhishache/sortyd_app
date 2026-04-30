import json
import os

path = "/Users/abhishek/Desktop/sortyd/Sortyd/Localizable.xcstrings"

with open(path, 'r') as f:
    data = json.load(f)

new_strings = {
    "Lists": {
        "ar": "القوائم",
        "es": "Listas"
    },
    "Active list would be default across widgets and the analysis.": {
        "ar": "ستكون القائمة النشطة هي الافتراضية عبر الأدوات والتحليل.",
        "es": "La lista activa será la predeterminada en los widgets y el análisis."
    },
    "ARCHIVED": {
        "ar": "المؤرشفة",
        "es": "ARCHIVADO"
    },
    "Your canvas is empty": {
        "ar": "لوحتك فارغة",
        "es": "Tu lienzo está vacío"
    },
    "Let AI build your first list,\nor create one yourself.": {
        "ar": "دع الذكاء الاصطناعي يبني قائمتك الأولى،\nأو أنشئ واحدة بنفسك.",
        "es": "Deja que la IA cree tu primera lista,\no crea una tú mismo."
    },
    "Generate with AI": {
        "ar": "إنشاء باستخدام الذكاء الاصطناعي",
        "es": "Generar con IA"
    },
    "Describe your goal, AI builds it": {
        "ar": "صف هدفك، والذكاء الاصطناعي سيبنيه",
        "es": "Describe tu objetivo, la IA lo creará"
    },
    "or": {
        "ar": "أو",
        "es": "o"
    },
    "Create manually": {
        "ar": "إنشاء يدوياً",
        "es": "Crear manualmente"
    },
    "ACTIVE": {
        "ar": "نشط",
        "es": "ACTIVO"
    },
    "no tasks": {
        "ar": "لا توجد مهام",
        "es": "sin tareas"
    },
    "list": {
        "ar": "قائمة",
        "es": "lista"
    }
}

for key, translations in new_strings.items():
    if key not in data["strings"]:
        data["strings"][key] = {"localizations": {}}
    
    if "localizations" not in data["strings"][key]:
        data["strings"][key]["localizations"] = {}
        
    for lang, val in translations.items():
        data["strings"][key]["localizations"][lang] = {
            "stringUnit": {
                "state": "translated",
                "value": val
            }
        }

with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("Successfully updated Localizable.xcstrings with ListManagement strings")
