# スクリーンショット履歴保存機能の修正

## 問題の概要

スクリーンショット機能を有効にしても、スクリーンショットがクリップボード履歴に保存されない問題が発生していました。

## 根本原因

### 1. macOS プライバシー権限の不足 ⚠️ 主要原因

`Info.plist` に必要なプライバシー説明キーが欠落していました。

**macOS 10.14 Mojave 以降の要件**:
- デスクトップフォルダへのアクセスには `NSDesktopFolderUsageDescription` が必要
- AppleEvents（Cmd+Vのペースト送信）には `NSAppleEventsUsageDescription` が必要

### 2. スクリーンショット検出の仕組み

`ScreenShotObserver` は以下の方法でスクリーンショットを検出:
- `NSMetadataQuery` を使用してデスクトップフォルダを監視
- `kMDItemIsScreenCapture = 1` のメタデータを持つファイルを検出
- ファイルパスから `NSImage` を読み込み
- RxSwiftの `rx.addedImage` Observable でストリーム配信

**重要**: この仕組みはデスクトップフォルダへの読み取り権限が必要です。

## 実装した修正

### 1. Info.plist への権限説明追加

[Clipy/Supporting Files/Info.plist](Clipy/Supporting Files/Info.plist#L39-L42)

```xml
<key>NSDesktopFolderUsageDescription</key>
<string>Clipy needs access to your Desktop folder to detect and save screenshots to clipboard history.</string>
<key>NSAppleEventsUsageDescription</key>
<string>Clipy needs to send paste commands to other applications.</string>
```

### 2. 詳細なデバッグログの追加

#### AppDelegate.swift

[AppDelegate.swift:228-261](Clipy/Sources/AppDelegate.swift#L228-L261)

**追加されたログ**:
- スクリーンショット観察設定の変更通知
- オブザーバー起動/停止の確認
- メタデータアイテム検出時の詳細情報（パス、表示名、スクリーンキャプチャフラグ）
- 画像読み込み成功時のサイズと有効状態

```swift
NSLog("[Clipy] Screenshot observer setting changed: \(enabled)")
NSLog("[Clipy] Starting screenshot observer...")
NSLog("[Clipy] Screenshot metadata item detected:")
NSLog("[Clipy]   - Path: \(path)")
NSLog("[Clipy] Screenshot image loaded - Size: \(image.size)")
```

#### ClipService.swift

[ClipService.swift:110-180](Clipy/Sources/Services/ClipService.swift#L110-L180)

**追加されたログ**:
- 画像クリップ作成開始時
- CPYClipData のハッシュ値
- 重複検出による除外
- 無効化されたクリップの検出
- 保存処理の各ステップ（パス、ハッシュ、タイプ）
- サムネイル保存の確認
- Realm保存の成功/失敗

```swift
NSLog("[Clipy] ClipService.create(with image:) called - Image size: \(image.size)")
NSLog("[Clipy] CPYClipData created for screenshot - Hash: \(data.hash)")
NSLog("[Clipy] Saving clip - Hash: \(savedHash), Path: \(savedPath)")
NSLog("[Clipy] Successfully saved clip to Realm database")
NSLog("[Clipy] ERROR: Failed to archive clip data to file")
```

## テスト手順

### 1. ビルドとインストール

```bash
cd /Users/k/Documents/GitHub/Clipy
bundle install --path=vendor/bundle
bundle exec pod install
open Clipy.xcworkspace
```

Xcode でビルドして実行します。

### 2. 権限の付与

アプリ起動時に以下の権限ダイアログが表示されるはずです:

1. **アクセシビリティ権限** - 既存（ペースト機能に必要）
2. **デスクトップフォルダアクセス** - 新規追加（スクリーンショット検出に必要）
3. **AppleEvents送信** - 新規追加（ペースト送信に必要）

手動で確認する場合:
```bash
# システム環境設定を開く
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Desktop"
```

**システム環境設定 > セキュリティとプライバシー > プライバシー** で確認:
- **ファイルとフォルダ** > **デスクトップフォルダ** に Clipy がリストされチェックされている
- **アクセシビリティ** に Clipy がリストされチェックされている
- **Automation** に Clipy がリストされている（場合により）

### 3. スクリーンショット機能の有効化

1. Clipy の環境設定を開く
2. **Beta** タブに移動
3. **Observe Screenshot** にチェックを入れる

### 4. ログの監視

ターミナルで以下のコマンドを実行してログを監視:

```bash
log stream --predicate 'processImagePath contains "Clipy"' --level debug
```

または Console.app を使用:
1. Console.app を開く
2. 検索バーに `[Clipy]` を入力
3. フィルタを適用

### 5. スクリーンショットのテスト

1. `Cmd+Shift+4` または `Cmd+Shift+3` でスクリーンショットを撮影
2. ログ出力を確認

**期待されるログの流れ**:
```
[Clipy] Screenshot observer setting changed: true
[Clipy] Starting screenshot observer...
[Clipy] Screenshot observer started - monitoring Desktop folder
[Clipy] Screenshot metadata item detected:
[Clipy]   - Path: /Users/xxx/Desktop/スクリーンショット 2025-xx-xx x.xx.xx.png
[Clipy]   - Display Name: スクリーンショット 2025-xx-xx x.xx.xx
[Clipy]   - Is Screen Capture: true
[Clipy] Screenshot image loaded - Size: {1920, 1080}, Observer enabled: true
[Clipy] ClipService.create(with image:) called - Image size: {1920, 1080}
[Clipy] CPYClipData created for screenshot - Hash: 123456789
[Clipy] Saving clip - Hash: 123456789, Path: .../Clipy/xxx.data, PrimaryType: NSPasteboardTypeTIFF
[Clipy] Saving thumbnail image to cache - Key: 1735012345
[Clipy] Successfully saved clip to Realm database - Hash: 123456789
```

### 6. クリップボード履歴の確認

1. `Cmd+Shift+V` でクリップボード履歴メニューを開く
2. スクリーンショットのサムネイルが表示されることを確認
3. 選択してペーストできることを確認

## トラブルシューティング

### スクリーンショットが検出されない

**ログに何も出力されない場合**:
1. Betaタブで「Observe Screenshot」が有効か確認
2. デスクトップフォルダへのアクセス権限が付与されているか確認
3. アプリを完全に終了して再起動

**メタデータアイテムは検出されるが画像が読み込めない場合**:
```
[Clipy] Screenshot metadata item detected:
[Clipy]   - Path: /Users/xxx/Desktop/...
# ここで止まる（画像読み込みのログが出ない）
```

原因の可能性:
- ファイルパスが正しくない
- ファイルが移動/削除された
- ファイル読み取り権限がない

**画像は読み込まれるがClipServiceが呼ばれない場合**:
```
[Clipy] Screenshot image loaded - Size: {1920, 1080}
# ここで止まる（ClipService.createのログが出ない）
```

原因の可能性:
- RxSwiftのストリームが切断されている
- disposeBagが解放されている

### 重複検出で保存されない

同じスクリーンショットを連続で撮ると以下のログが出る場合:
```
[Clipy] Clip already exists and copySameHistory is disabled - Hash: 123456789
```

**解決方法**:
1. 環境設定 > 一般 > 「Copy same history」にチェックを入れる
2. または異なる内容のスクリーンショットを撮る

### 保存エラーが発生する

```
[Clipy] ERROR: Failed to archive clip data to file: ...
```

原因の可能性:
- Application Supportフォルダへの書き込み権限がない
- ディスク容量不足
- CPYClipDataのシリアライズに失敗

**解決方法**:
```bash
# Application Supportフォルダの権限確認
ls -la ~/Library/Application\ Support/Clipy

# 手動で作成
mkdir -p ~/Library/Application\ Support/Clipy
chmod 755 ~/Library/Application\ Support/Clipy
```

## データフロー図

```
┌─────────────────────────────────────────────────────────────┐
│  macOS がスクリーンショットを保存                              │
│  デフォルト: ~/Desktop/スクリーンショット YYYY-MM-DD HH.MM.SS.png │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────────────┐
         │  NSMetadataQuery              │
         │  (デスクトップフォルダを監視)    │
         │  kMDItemIsScreenCapture = 1   │
         └───────────┬───────────────────┘
                     │
                     ▼
         ┌───────────────────────────────┐
         │  ScreenShotObserver           │
         │  .rx.addedItem イベント発火    │
         └───────────┬───────────────────┘
                     │
                     ▼
         ┌───────────────────────────────┐
         │  メタデータからパスを取得       │
         │  NSImage(contentsOfFile:)     │
         └───────────┬───────────────────┘
                     │
                     ▼
         ┌───────────────────────────────┐
         │  .rx.addedImage イベント発火   │
         │  AppDelegate が受信            │
         └───────────┬───────────────────┘
                     │
                     ▼
         ┌───────────────────────────────┐
         │  ClipService.create(image:)   │
         │  CPYClipData 作成             │
         └───────────┬───────────────────┘
                     │
                     ▼
         ┌───────────────────────────────┐
         │  ClipService.save(data:)      │
         │  - サムネイル生成              │
         │  - PINCache保存               │
         │  - .data ファイル作成          │
         │  - Realm DB保存               │
         └───────────┬───────────────────┘
                     │
                     ▼
         ┌───────────────────────────────┐
         │  MenuManager がRealmの変更検知 │
         │  メニューを自動更新            │
         └───────────────────────────────┘
```

## まとめ

### 実装した修正

1. ✅ `Info.plist` に `NSDesktopFolderUsageDescription` と `NSAppleEventsUsageDescription` を追加
2. ✅ スクリーンショット検出フローの全段階にデバッグログを追加
3. ✅ ClipService の保存処理にエラーハンドリングとログを追加

### 期待される効果

- macOS がデスクトップフォルダへのアクセス権限をユーザーに要求
- 権限付与後、スクリーンショットが自動的に履歴に保存される
- 詳細なログで問題箇所を即座に特定可能

### 今後の改善案

1. **設定画面の改善**: Beta タブに権限確認ボタンを追加
2. **エラーメッセージの表示**: 権限がない場合にユーザーに通知
3. **スクリーンショットディレクトリのカスタマイズ**: デスクトップ以外の保存先にも対応
4. **パフォーマンス最適化**: 大きな画像のサムネイル生成を非同期化

## 関連ファイル

- [Info.plist](Clipy/Supporting Files/Info.plist) - プライバシー権限の説明
- [AppDelegate.swift](Clipy/Sources/AppDelegate.swift#L222-L263) - スクリーンショット観察の統合
- [ClipService.swift](Clipy/Sources/Services/ClipService.swift#L107-L182) - クリップ作成と保存
- [ScreenShotObserver.swift](Pods/Screeen/Lib/Screeen/ScreenShotObserver.swift) - スクリーンショット検出
- [Screeen+Rx.swift](Pods/RxScreeen/Lib/RxScreeen/Screeen+Rx.swift) - RxSwift ラッパー

## 参考資料

- [Apple: Protecting User Privacy](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)
- [TN3118: Resolving Common Privacy Permission Issues](https://developer.apple.com/documentation/technotes/tn3118-resolving-common-privacy-permission-issues)
- [NSMetadataQuery Documentation](https://developer.apple.com/documentation/foundation/nsmetadataquery)
