---
name: Image Files
description: Use when resizing, converting, optimizing, or batch-processing images with ImageMagick — especially when the magick command isn't found on PATH on Windows.
---

# Image Files (ImageMagick)

## Windows install location

If `magick` isn't on PATH, it's installed at:

```
C:\Program Files\ImageMagick-7.1.2-Q16-HDRI
```

Call it with the full quoted path.

## Modern vs legacy syntax

Try modern ImageMagick 7 syntax first (`magick input.jpg -resize 800x output.jpg`, `magick identify`); fall back to legacy IM6 commands (`convert`, `identify`, `mogrify`) if `magick` isn't found.

Full option syntax is available via `magick help`.
