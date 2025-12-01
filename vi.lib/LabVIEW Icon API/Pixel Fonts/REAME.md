## Problem Statement

As a LabVIEW users, I need to be able to edit VI icons on any platform and have them appear the same.  Right now, nearly 99% of LabVIEW users will stick to the default "Small Fonts 8" (Font name Small Fonts, size 8) which is the default for the Icon Editor in LabIVEW on Windows.  There is, however, a problem: this font only exists on Windows, since it is a Microsoft Font.

## Proposed Solution

The proposed solution is create a "pixel font" that is roughly equivalent to (or better than) Small Fonts 8 which can be used as the default for the Icon Editor.

Here's how a very simple system could work:

### Phase 0: Behind-the-scenes Solution for Mac and Linux

On Linux and Mac, any time "Small Fonts 8" is encountered, then the Icon Editor and related functions would automatically use "LabVIEW Pixel Font 8" as a substitute.  This would be transparent to Mac and Linux users -- they would not even know the difference and things would "just work" for editing icons.

### Phase 1: More LabVIEW Pixel Fonts and Options

To support a set of possibly improved fonts (like a compressed pixel font) there could be an option to NOT use the OS Fonts at all, but to use "LabVIEW Pixel Fonts" which would replace the drop-down selector items with a set of different pixel fonts like LabVIEW Small, LabVIEW Small Compressed (not monospaced, since some chars can be 3-wide, instead of 4), etc.

## Implementation Plan for Phase 0

The following are key:

- We need to generate the pixel font on Windows from Small Fonts 8 (and possibly other sizes). This involves using existing libraries to create a constant with the font: 1D array of uppercase chars, 1D array of lowercase chars.  A character is a 2D array of pixels.