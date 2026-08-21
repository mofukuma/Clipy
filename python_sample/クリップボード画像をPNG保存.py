# python
#
# コピーした画像を、Finderで開いている（選択している）フォルダにPNGで保存する。
#
#  - Finderでフォルダを1つ選んでいれば、そのフォルダの中に保存
#  - フォルダを選んでいなければ、最前面のFinderウインドウの場所に保存
#  - Finderのウインドウが無ければデスクトップに保存
#
# 保存したパスはクリップボード履歴に追加され、Finderで選択状態になる。

index = clipy.find_image_clip()
if index is None:
    raise Exception("クリップボード履歴に画像がありません")

path = clipy.save_clip_image(index)

clipy.add_clip(path)
clipy.reveal(path)

# 出力すると貼り付けられてしまうので、何も print しない
