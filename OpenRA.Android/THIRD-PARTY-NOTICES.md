# Third-party software in AndroidRA

AndroidRA is based on OpenRA, which is free software released under the GNU General Public License v3 (see `COPYING`).
The Android APK additionally contains the following components, built from unmodified upstream sources
by `packaging/android/build-native.sh` (source URLs and SHA-256 checksums are pinned in that script).

| Component | Version | License | Source |
|---|---|---|---|
| SDL2 | 2.32.10 | zlib | https://github.com/libsdl-org/SDL |
| OpenAL Soft | 1.24.3 | LGPL-2.0-or-later | https://github.com/kcat/openal-soft |
| FreeType | 2.13.3 | FreeType License (FTL) | https://freetype.org |
| Lua | 5.1.5 | MIT | https://www.lua.org |
| .NET runtime and libraries | 10.0 | MIT | https://github.com/dotnet/runtime |
| .NET for Android | 36.1 | MIT | https://github.com/dotnet/android |

## SDL2

The SDL Java glue (`org.libsdl.app`) included in the APK is part of SDL and covered by the same license.

```
Copyright (C) 1997-2025 Sam Lantinga <slouken@libsdl.org>

This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
```

## OpenAL Soft

OpenAL Soft is distributed under the GNU Library General Public License, version 2 or (at your option)
any later version; the full license text is in `COPYING` in the OpenAL Soft source archive.
It is included as a separate shared library (`libsoft_oal.so`) that can be replaced with a rebuilt copy;
the corresponding source code is available from the upstream repository above (tag `1.24.3`).

## FreeType

Portions of this software are copyright © 2024 The FreeType Project (https://freetype.org).
All rights reserved. Used under the terms of the FreeType License.

## Lua

```
Copyright (C) 1994-2012 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

## Game content

The APK does not contain any Command & Conquer game assets. The in-game installer downloads the
freeware Red Alert content released by EA, or copies it from discs or digital installations owned by
the player.
