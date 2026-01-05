<div align="center">
  <img src="./Resources/clipy_logo.png" width="400">
</div>

<br>

![CI](https://github.com/Clipy/Clipy/workflows/CI/badge.svg)
[![Release version](https://img.shields.io/github/release/Clipy/Clipy.svg)](https://github.com/Clipy/Clipy/releases/latest)
[![OpenCollective](https://opencollective.com/clipy/backers/badge.svg)](#backers)
[![OpenCollective](https://opencollective.com/clipy/sponsors/badge.svg)](#sponsors)

Clipy+ is a Clipboard extension app for macOS with Python scripting automation.

---

__Requirement__: macOS 10.13 or higher

__Distribution Site__ : <https://clipy-app.com>

<img src="http://clipy-app.com/img/screenshot1.png" width="400">

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

1. Open Clipy Preferences (⌘,)
2. Go to the "Python" tab
3. Select your Python environment from the dropdown:
   - System Python
   - Homebrew (Intel/Apple Silicon)
   - Anaconda/Miniconda/Miniforge (base or virtual environments)
   - pyenv
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

- **`clipy.get_clip(index)`**: Get clipboard text at history position (0 = most recent)
- **`clipy.get_clip_data(index)`**: Get detailed clipboard data including type and metadata
- **`clipy.add_clip(text)`**: Add new text to clipboard history
- **`clipy.get_clip_count()`**: Get total number of clipboard items

#### Example: Translation with ChatGPT

```python
# python
# Translate the most recent clipboard item from Japanese to English using ChatGPT
import os
from openai import OpenAI

# Get API key from environment variable
api_key = os.getenv("OPENAI_API_KEY", "your-api-key-here")
client = OpenAI(api_key=api_key)

# Get the most recent clipboard item
text = clipy.get_clip(0)

# Call ChatGPT API
response = client.chat.completions.create(
    model="gpt-5.2",
    messages=[
        {"role": "system", "content": "Translate the following Japanese text to English:"},
        {"role": "user", "content": text}
    ]
)

# Output the translated text (will be pasted)
print(response.choices[0].message.content)
```

#### Example: Data Processing

```python
# python
# Extract email addresses from the most recent clipboard item
import re

text = clipy.get_clip(0)
emails = re.findall(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', text)

if emails:
    print('\n'.join(emails))
else:
    print("No email addresses found")
```

### Limitations

- Maximum execution time: 10 seconds
- Python scripts run in a sandboxed environment
- Standard output is captured and pasted as the result
- Errors are displayed in an alert dialog

### How to Build
0. Move to the project root directory
1. `bundle install --path=vendor/bundle && bundle exec pod install`
2. Open `Clipy.xcworkspace` on Xcode.
3. build.

### Contributing
1. Fork it ( https://github.com/Clipy/Clipy/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Localization Contributors
Clipy is looking for localization contributors.  
If you can contribute, please see [CONTRIBUTING.md](https://github.com/Clipy/Clipy/blob/master/.github/CONTRIBUTING.md)

### Distribution
If you distribute derived work, especially in the Mac App Store, I ask you to follow two rules:

1. Don't use `Clipy` and `ClipMenu` as your product name.
2. Follow the MIT license terms.

Thank you for your cooperation.

### Backers

Support us with a monthly donation and help us continue our activities. [[Become a backer](https://opencollective.com/clipy#backer)]

<a href="https://opencollective.com/clipy/backer/0/website" target="_blank"><img src="https://opencollective.com/clipy/backer/0/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/1/website" target="_blank"><img src="https://opencollective.com/clipy/backer/1/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/2/website" target="_blank"><img src="https://opencollective.com/clipy/backer/2/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/3/website" target="_blank"><img src="https://opencollective.com/clipy/backer/3/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/4/website" target="_blank"><img src="https://opencollective.com/clipy/backer/4/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/5/website" target="_blank"><img src="https://opencollective.com/clipy/backer/5/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/6/website" target="_blank"><img src="https://opencollective.com/clipy/backer/6/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/7/website" target="_blank"><img src="https://opencollective.com/clipy/backer/7/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/8/website" target="_blank"><img src="https://opencollective.com/clipy/backer/8/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/9/website" target="_blank"><img src="https://opencollective.com/clipy/backer/9/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/10/website" target="_blank"><img src="https://opencollective.com/clipy/backer/10/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/11/website" target="_blank"><img src="https://opencollective.com/clipy/backer/11/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/12/website" target="_blank"><img src="https://opencollective.com/clipy/backer/12/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/13/website" target="_blank"><img src="https://opencollective.com/clipy/backer/13/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/14/website" target="_blank"><img src="https://opencollective.com/clipy/backer/14/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/15/website" target="_blank"><img src="https://opencollective.com/clipy/backer/15/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/16/website" target="_blank"><img src="https://opencollective.com/clipy/backer/16/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/17/website" target="_blank"><img src="https://opencollective.com/clipy/backer/17/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/18/website" target="_blank"><img src="https://opencollective.com/clipy/backer/18/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/19/website" target="_blank"><img src="https://opencollective.com/clipy/backer/19/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/20/website" target="_blank"><img src="https://opencollective.com/clipy/backer/20/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/21/website" target="_blank"><img src="https://opencollective.com/clipy/backer/21/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/22/website" target="_blank"><img src="https://opencollective.com/clipy/backer/22/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/23/website" target="_blank"><img src="https://opencollective.com/clipy/backer/23/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/24/website" target="_blank"><img src="https://opencollective.com/clipy/backer/24/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/25/website" target="_blank"><img src="https://opencollective.com/clipy/backer/25/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/26/website" target="_blank"><img src="https://opencollective.com/clipy/backer/26/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/27/website" target="_blank"><img src="https://opencollective.com/clipy/backer/27/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/28/website" target="_blank"><img src="https://opencollective.com/clipy/backer/28/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/29/website" target="_blank"><img src="https://opencollective.com/clipy/backer/29/avatar.svg"></a>

### Sponsors

Become a sponsor and get your logo on our README on Github with a link to your site. [[Become a sponsor](https://opencollective.com/clipy#sponsor)]

<a href="https://opencollective.com/clipy/sponsor/0/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/1/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/2/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/3/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/4/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/5/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/6/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/7/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/8/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/9/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/9/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/10/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/10/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/11/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/11/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/12/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/12/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/13/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/13/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/14/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/14/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/15/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/15/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/16/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/16/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/17/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/17/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/18/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/18/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/19/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/19/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/20/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/20/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/21/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/21/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/22/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/22/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/23/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/23/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/24/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/24/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/25/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/25/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/26/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/26/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/27/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/27/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/28/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/28/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/29/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/29/avatar.svg"></a>

### Licence
Clipy is available under the MIT license. See the LICENSE file for more info.

Icons are copyrighted by their respective authors.

### Special Thanks
__Thank you for [@naotaka](https://github.com/naotaka) who have published [ClipMenu](https://github.com/naotaka/ClipMenu) as OSS.__
