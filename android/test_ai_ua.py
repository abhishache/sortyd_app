import urllib.request
import json
import time
import hmac
import hashlib

API_URL = "https://sortyd-proxy.abhishek918.workers.dev/api/ai"
HMAC_SALT = "com.sortyd.sortyd|Sortyd|v1"
MODEL = "llama3.1-8b"

prompt = """
{
  "emoji": "🏃",
  "listName": "Get Fit",
  "tasks": ["Run", "Swim"]
}
"""

body = {
    "model": MODEL,
    "messages": [{"role": "user", "content": prompt}],
    "max_tokens": 700,
    "temperature": 0.7
}
body_string = json.dumps(body, separators=(',', ':'))

timestamp = str(int(time.time()))
message = timestamp + "." + body_string
signature = hmac.new(HMAC_SALT.encode(), message.encode(), hashlib.sha256).hexdigest()

req = urllib.request.Request(API_URL, data=body_string.encode('utf-8'))
req.add_header('Content-Type', 'application/json')
req.add_header('x-sortyd-ts', timestamp)
req.add_header('x-sortyd-sig', signature)
req.add_header('User-Agent', 'Sortyd/1.0 (Android)')

try:
    with urllib.request.urlopen(req) as response:
        print("Status:", response.status)
        print("Body:", response.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print("HTTPError:", e.code)
    print("Error Body:", e.read().decode('utf-8'))
except Exception as e:
    print("Exception:", e)
