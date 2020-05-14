# Image-Viewer-Plus

A Feh like image viewer for Windows

Currently under development

# Prerequisites

Build the libwebp dynamic link library (see `lib/delphi-webp/BUILDING.md`) and move the `libwebp.dll` file to `Win32/Debug` and `Win32/Release`

# Building

Build the project (`ivp.dproj`) using the Delphi IDE. Tested in Delphi 10.3.

# Usage

## Supported image types

- Bitmap
- TIFF
- JPEG
- PNG
- GIF
- WebP

## Loading images

### Using the CLI to load images:

Add the directory to the built binaries to the system path environment variable.

Run the program from the terminal using

```
ivp [...FILE PATHS / DIRECORY PATHS / HTTP(S) URLS]
```

### Using the GUI to load images:

Drag images or directory into the GUI to add the images to the list.

## Controls

Left & right arrows for navigation.

Up & down arrows for zoom.

Mouse for panning.

# Libraries used
- Windows GDI+
- Win32 API
- libwebp