"""Copy the Flutter release output into the hosting directory."""
import shutil
from pathlib import Path

root=Path(__file__).resolve().parent.parent
source=root/'build'/'web'
assert (source/'index.html').is_file(), 'Build the Flutter web app first.'
assert (source/'main.dart.js').is_file(), 'Release web entry point is missing.'
shutil.copytree(source,root/'dist',dirs_exist_ok=True)
print('Prepared Flutter release assets for hosting.')
