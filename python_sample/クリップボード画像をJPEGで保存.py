# python
#
# コピーした画像を、指定フォルダにJPEGで保存する応用例。
# 保存先やファイル名を自分で決めたいときのサンプル。

import os
from datetime import datetime

folder = clipy.get_finder_path()          # Finderで見ているフォルダ
name = datetime.now().strftime("capture_%Y%m%d_%H%M%S.jpg")

path = clipy.save_clip_image(path=os.path.join(folder, name), format="jpg")
clipy.reveal(path)
