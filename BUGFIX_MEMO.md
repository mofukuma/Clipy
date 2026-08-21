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


## Office（Excel等）の画像くっつき対策
Excelでコピーすると、テキスト・RTF・HTML・セルの画像（TIFF）が同時にクリップボードに乗る。
今までは画像だけを書き戻していたので、貼り付けると画像になってしまっていた。

- 保存していた全表現を、元の順番のまま復元するようにした
- 画像・PDFは「レンダリング結果」なので、テキストがある場合は必ず後ろに回す
- Excel/Word/Numbers等のネイティブ形式（com.microsoft.* など）もそのまま保存・復元
  → Excelに貼り戻すと画像ではなくセルとして貼れる
- HTMLも保存対象に追加（RTFの設定と連動）

画像が絶対に要らない人向けの隠し設定:
defaults write com.progsha.ClipyAI kCPYPrefDropRenderedMediaOnRichText -bool true

## クリップボード画像をPNG保存
python_sample/クリップボード画像をPNG保存.py

clipy.save_clip_image() でFinderで開いている（選択している）フォルダにPNG保存できる。
その他 clipy.get_clip_image / find_image_clip / has_image /
get_finder_path / get_finder_selection / reveal を追加。

初回はFinder操作のオートメーション許可ダイアログが出る。
（システム設定 > プライバシーとセキュリティ > オートメーション）

Pythonスニペットは、printしなければ貼り付けもされないようにした。
タイムアウトは10秒→30秒。

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


