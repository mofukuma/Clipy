
ClipyAI is an AI-powered clipboard extension featuring clipboard history and AI-driven automation.

---

__Requirement__: macOS 10.13 or higher, Apple Silicon (M1 higher)


## Features

- **Clipboard History Management**: Store and access your clipboard history
- **Snippets**: Create and manage text snippets for quick access
- **Python Scripting**: Execute Python scripts that can interact with clipboard history
- **Multi-format Support**: Handle text, images, files, and URLs
- **Customizable Shortcuts**: Configure keyboard shortcuts for quick access

### Development Environment
* macOS 26.1 Tahoe
* Xcode 26.2
* Swift 5.3

## Python Scripting

Clipy supports executing Python scripts from snippets, allowing you to automate clipboard operations and integrate with external services.

### Setup

1. Open Preferences
2. Go to the "Python" tab
3. Select your Python environment from the dropdown
4. Click "Test" to verify the Python environment is working

### Creating Python Snippets

Create a snippet starting with `# python` to mark it as executable Python code:

```python
# python
# Get the most recent clipboard item and print it in uppercase
text = clipy.get_clip(0)
print(text.upper())
```

When you select this snippet, it will execute the Python code and paste the result.

### Clipy API

Python scripts can interact with clipboard history using the `clipy` object:

#### Available Methods

Clipboard history:

- **`clipy.get_clip(index)`**: Get clipboard text at history position (0 = most recent)
- **`clipy.get_clip_data(index)`**: Get detailed clipboard data including type, size and metadata
- **`clipy.add_clip(text)`**: Add new text to clipboard history
- **`clipy.get_clip_count()`**: Get total number of clipboard items

Images:

- **`clipy.has_image(index)`**: Whether the clip at that position carries an image
- **`clipy.find_image_clip()`**: Position of the most recent clip carrying an image (`None` if there is none)
- **`clipy.get_clip_image(index=None, format="png")`**: Image of a clip as raw `bytes`. `index=None` picks the most recent clip that has an image
- **`clipy.save_clip_image(index=None, path=None, format="png")`**: Write the image of a clip to disk and return the path. `path=None` saves into the folder the Finder is showing (the desktop when the Finder cannot be asked), an existing folder gets an automatic file name, an existing file is never overwritten. Formats: `png`, `jpg`, `tiff`, `bmp`, `gif`

Finder:

- **`clipy.get_finder_path()`**: Folder the Finder is showing right now. A single selected folder wins over the front window, the desktop is used when no window is open
- **`clipy.get_finder_selection()`**: Paths selected in the Finder
- **`clipy.reveal(path)`**: Show and select files in the Finder

Finder access asks for the automation permission the first time
(System Settings > Privacy & Security > Automation).

A snippet that prints nothing pastes nothing, which is what scripts that only
write files or push data into the history want.

#### Example: Save the copied image as PNG

Saves whatever image you copied last into the folder you are looking at in the
Finder, remembers the path in the history and selects the new file.

```python
# python
index = clipy.find_image_clip()
if index is None:
    raise Exception("クリップボード履歴に画像がありません")

path = clipy.save_clip_image(index)

clipy.add_clip(path)
clipy.reveal(path)
```

#### Example: Translation with ChatGPT

```python
# python
# Translate the most recent clipboard item to English using ChatGPT
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
```

#### Example: Date Today

```python
# python

from datetime import datetime

print(datetime.today().strftime("%Y/%m/%d"))
```

### Limitations
- Maximum execution time: 30 seconds (`defaults write com.progsha.ClipyAI com.clipy-app.Clipy.pythonExecutionTimeout -int 60` to change it)
- `clipy.get_clip_image` transfers at most 24MB, bigger images have to go through `clipy.save_clip_image`

## Office Content

Excel, Word, PowerPoint, Numbers, Pages and Keynote put the very same selection
on the clipboard several times: as their own native format, as RTF and HTML, as
plain text and as a rendered picture of the copied cells or paragraphs.

Clipy keeps all of them:

- The native formats are stored as well, so a copied cell range pastes back into
  Excel as cells with formulas instead of as a picture of cells
- HTML is stored next to RTF, which keeps tables alive when pasting into a browser or mail
- The rendered picture is kept, but it is offered *after* the real content, so
  applications stop pasting a screenshot of your spreadsheet

If you never want the rendered picture when text is available:

```
defaults write com.progsha.ClipyAI kCPYPrefDropRenderedMediaOnRichText -bool true
```

### How to Build
0. Move to the project root directory
1. `bundle install --path=vendor/bundle && bundle exec pod install`
2. Open `Clipy.xcworkspace` on Xcode.
3. build.

### Localization Contributors
Clipy is looking for localization contributors.  
If you can contribute, please see [CONTRIBUTING.md](https://github.com/Clipy/Clipy/blob/master/.github/CONTRIBUTING.md)

### Distribution
If you distribute derived work, especially in the Mac App Store, I ask you to follow two rules:

1. Don't use `Clipy` and `ClipMenu` as your product name.
2. Follow the MIT license terms.

Thank you for your cooperation.

### Licence
Clipy is available under the MIT license. See the LICENSE file for more info.

Icons are copyrighted by their respective authors.

### Special Thanks
__Thank you for [@Econa77](https://github.com/Econa77), [@naotaka](https://github.com/naotaka)  who have published [Clipy](https://github.com/Econa77/Clipy), [ClipMenu](https://github.com/naotaka/ClipMenu) as OSS.__
