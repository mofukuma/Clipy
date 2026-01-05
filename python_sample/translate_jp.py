# python
import requestsÇ
import json, os

# OpenAI API設定
api_key = os.getenv("OPENAI_API_KEY", "your api key")
api_url = "https://api.openai.com/v1/chat/completions"

headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {api_key}"
}

data = {
    "model": "gpt-5.2",
    "messages": [
        {"role": "system", "content": "あなたは文章を英語に翻訳する翻訳者です。"},
        {"role": "user", "content": f"次の文章を英語に翻訳してください: {text}"}
    ]
}

try:
    response = requests.post(api_url, headers=headers, json=data, timeout=30)
    response.raise_for_status()
    
    result = response.json()
    translation = result["choices"][0]["message"]["content"]
    
    # 翻訳結果を出力
    print(translation)
    
    # オプション: 翻訳結果をClipyの履歴に追加
    # clipy.add_clip(translation)
    
except Exception as e:
    print(f"翻訳エラー: {str(e)}")

    