# PixelPerfectEngine ver 0.10-beta

A retro engine for 2D and pseudo-3D games written in D by László Szerémi.

Started out as a project for college, and continued as a hobby to learn game and software development. Has its own GUI subsystem, 
which is influenced by the looks of old graphical operating systems' (Amiga Workbench, old MacOS, etc.).

# Why use PixelPerfectEngine over the competition?

## Authentic pixel graphics

When I was looking for a project idea to present something for Object-Oriented Programming exams, that whould be doable by a 
single person, yet fun enough to keep me occupied to work on it. While I underestimated the complexity and the work that should
go into an engine (especially as a rookie), I noticed a few odd things about 2D retro games. As modern engines often use 3D
polygons for sprites, there can be many errors:

* Rounding errors from floating-point coordinates.
* Unauthentic scaling and rotation effects due to direct rendering on high-resolution framebuffers.
* Ability of use of sprites and textures with baked-in big pixels, which lead to misaligned pixels.

In order to mitigate these issues, the engine uses CPU or GPU (coming in the future) blitter, like some old systems did back
in the days, such as the Amiga. However the engine also can do some of the tricks of later 2D machines like per-index 
transparency, and you can create various effects like light, fog, and reflections, by using custom layers or even the 
`EffectLayer` (coming in the future). You also don't need any trickery for palette-swap effects.

## Small footprint and lightweight

Some other, popular engines used for 2D retro games are 3D engines that are made to display 2D graphics instead. This often
adds additional bulk onto an otherwise small game.

This lightweight nature of the engine will soon enable to be compiled for low-powered ARMv8 devices, which will allow to
be run on many smartphones and even single-board computers.

## Open-source without the hassle

This engine is licensed under the Boost Software License 1.0, which means it can be used without attribution and even in
commercial applications. Be aware that many components are on different licenses, such as SDL2 and ZLib.

# Features

* Pixel-accurate retro graphics.
* Either hard-transparency using blitter, or soft-transparency using alpha-blending.
* Various effects with other composing functions.
* A tile layer that is capable of displaying uniform tiles from a map, and has per-line scrolling via a delegate.
* A transformable tile layer capable of Mode7 type effects at the cost of power-of-two only tile and map sizes.
* A sprite layer with sprite scaling, simple slicing, and individual composing functions for each sprite.
* GUI
* Configuration file handling
* Collision detection
* Handling of multiple inputs
* ...and many more

# Known issues:

* The engine doesn't clear the framebuffer to spare some CPU time. This can result in rapid flickering if the bottom layer is scrolled
out. To avoid it at all cost, you can use a warp mode on that layer.
* There's also some speed issues as SDL2 writes the framebuffer back to the main memory. This will probably end up in the slow 
replacement of SDL2's graphical side with something faster.
* WindowMakerForConcrete and PixelPerfectEditor are currently unfinished. The former will be soon working fully with extra features 
(such as undo/redo, snapping to grid and components), then the latter can be developed without an issue.
* Error handling isn't fully realized, so a lot of errors might happen. You can help me by reporting errors, testing on various 
systems.
* Upscaled sprites have a rather jerky, odd behavior when they're being partly obscured. This will be fixed, do not plan with it on
the long run for a wacky effect.
* Upscaled sprites wider than 2048 pixels will cause some serious memory leakage issues.
* Sometimes sprites don't appear with the new system when placed in a well viewable place. Currently it can be fixed with a simple `s.relmove(nOfSprite, 0, 0)`.

# Future plans:

* Hardware acceleration, possibly through OpenCL since GLSL lacks the ability of reading textures as integers in older versions.
* Adding support for scripting languages (QScript, Lua, Python, BASIC, etc).
* Compressed data file handling.