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
cp -R /Users/*/Library/Developer/Xcode/DerivedData/Clipy-*/Build/Products/Release/Clipy.app ./release_dmg/ClipyAI.app

### 3. Applicationsスタティックリンク
ln -s /Applications ./release_dmg/Applications

### 4. アドホック署名
codesign --force --deep --sign - ./release_dmg/ClipyAI.app


### 5. 配布用ZIPを作成
hdiutil create -volname "ClipyAI_1.0.1" -srcfolder ./release_dmg -ov -format UDZO ClipyAI_1.0.1.dmg && ls -lh ClipyAI_1.0.1.dmg 

## TODO
現在、古いDSA署名方式を使用、Sparkle 2.xはセキュリティ上の理由でEdDSA（ed25519）キーが必要らしい。


