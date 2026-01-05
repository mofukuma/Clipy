import os, json, urllib.request

api_key = os.getenv("OPENAI_API_KEY", "your api key")
text = clipy.get_clip(0)

req = urllib.request.Request(
    "https://api.openai.com/v1/chat/completions",
    data=json.dumps({
        "model": "gpt-5.2",
        "messages": [
            {"role": "system", "content": "You are a translator who translates text into English."},
            {"role": "user", "content": f"Please translate the following text into English: {text}"}
        ]
    }).encode(),
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
)

print(json.loads(urllib.request.urlopen(req).read())["choices"][0]["message"]["content"])
