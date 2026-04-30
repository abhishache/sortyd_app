import json
import os

path = "/Users/abhishek/Desktop/sortyd/Sortyd/Localizable.xcstrings"

with open(path, 'r') as f:
    data = json.load(f)

new_strings = {
    "AI insights use habit titles only — processed securely, never sold.": {
        "ar": "تستخدم رؤى الذكاء الاصطناعي عناوين العادات فقط - تتم معالجتها بأمان، ولا يتم بيعها أبداً.",
        "es": "Los conocimientos de IA solo utilizan los títulos de los hábitos: se procesan de forma segura y nunca se venden."
    },
    "Uses Apple HealthKit": {
        "ar": "يستخدم Apple HealthKit",
        "es": "Utiliza Apple HealthKit"
    },
    "Reads steps & active calories to track fitness habits": {
        "ar": "يقرأ الخطوات والسعرات الحرارية النشطة لتتبع عادات اللياقة البدنية",
        "es": "Lee los pasos y las calorías activas para realizar un seguimiento de los hábitos de fitness"
    },
    "Get Started": {
        "ar": "ابدأ الآن",
        "es": "Empezar"
    },
    "Continue": {
        "ar": "استمرار",
        "es": "Continuar"
    },
    "Fitness": {
        "ar": "اللياقة البدنية",
        "es": "Aptitud física"
    },
    "Learning": {
        "ar": "التعلم",
        "es": "Aprendizaje"
    },
    "Mindfulness": {
        "ar": "اليقظة الذهنية",
        "es": "Atención plena"
    },
    "Free forever": {
        "ar": "مجاني للأبد",
        "es": "Gratis para siempre"
    },
    "Morning Routine": {
        "ar": "الروتين الصباحي",
        "es": "Rutina matutina"
    },
    "TODAY": {
        "ar": "اليوم",
        "es": "HOY"
    },
    "Morning meditation": {
        "ar": "تأمل الصباح",
        "es": "Meditación matutina"
    },
    "Workout 30 min": {
        "ar": "تمرين لمدة 30 دقيقة",
        "es": "Entrenamiento 30 min"
    },
    "Read 20 pages": {
        "ar": "قراءة 20 صفحة",
        "es": "Leer 20 páginas"
    },
    "Journal entry": {
        "ar": "كتابة اليوميات",
        "es": "Entrada de diario"
    },
    "Cold shower": {
        "ar": "دش بارد",
        "es": "Ducha fría"
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

print("Successfully updated Localizable.xcstrings with Onboarding strings")
