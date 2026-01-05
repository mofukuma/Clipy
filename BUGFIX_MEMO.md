## クリップボードFIX完了
タイミングの問題　→　３回リトライにしたらなおった
新しい型への対応　→　Apple TTFとか新しい型が発生するので対応

## pythonに対応
スニペット行頭に # python と書くとPythonが実行できる
print("hello world")

これでhello worldと入力される。

lastest_text = clipy.get_clip(0) これで最新のクリップボードがとれる
clipy.add_clip("あたらしい内容") これでクリップボードに入れる

設定からPython環境を指定できるぞ。pip で好きなモジュールをいれて使おう。


## ビルド周り
色々とモジュール周りでエラー吐きまくるので　macOS 13.5以上 としたらなおった。

### 1. Releaseビルド
xcodebuild -workspace Clipy.xcworkspace \
           -scheme Clipy \
           -configuration Release \
           -arch arm64 \
           build

### 2. ビルドをコピー
cp -R /Users/*/Library/Developer/Xcode/DerivedData/Clipy-*/Build/Products/Release/Clipy.app /Applications/Clipy+.app

### 3. アドホック署名
codesign --force --deep --sign - /Applications/Clipy+.app

### 4. 配布用ZIPを作成
cd /Applications
zip -r ~/Desktop/Clipy-Python-Edition.zip Clipy+.app


## TODO
現在、古いDSA署名方式を使用していますが、Sparkle 2.xはセキュリティ上の理由でEdDSA（ed25519）キーが必要らしい。


