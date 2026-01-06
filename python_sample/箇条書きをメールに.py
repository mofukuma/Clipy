# python

import os, json, urllib.request

api_key = os.getenv("ANTHROPIC_API_KEY", "your api key")
text = clipy.get_clip(0)

req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=json.dumps({
        "model": "claude-sonnet-4-20250514",
        "max_tokens": 4096,
        "messages": [
            {"role": "user", "content": f"あなたはビジネスメールを書く専門家です。以下の要点のみ書かれた内容から、簡潔でわかりやすいビジネスメールを書いてください。:\n\n{text}"}
        ]
    }).encode(),
    headers={
        "Content-Type": "application/json",
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01"
    }
)

print(json.loads(urllib.request.urlopen(req).read())["content"][0]["text"])
