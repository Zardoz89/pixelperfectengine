module PixelPerfectEngine.graphics.layers.spritelayer;

public import PixelPerfectEngine.graphics.layers.base;

import collections.treemap;
import collections.sortedlist;
import std.bitmanip : bitfields;

/**
 * General-purpose sprite controller and renderer.
 */
public class SpriteLayer : Layer, ISpriteLayer {
	/**
	 * Helps to determine the displaying properties and order of sprites.
	 */
	public struct DisplayListItem {
		Box		position;			/// Stores the position relative to the origin point. Actual display position is determined by the scroll positions.
		Box		slice;				/// To compensate for the lack of scanline interrupt capabilities, this enables chopping off parts of a sprite.
		void*	pixelData;			/// Points to the pixel data.
		/**
		 * From version 0.10.0 onwards, each sprites can have their own rendering function set up to
		 * allow different effect on a single layer.
		 * If not specified otherwise, the layer's main rendering function will be used instead.
		 * Custom rendering functions can be written by the user, it requires knowledge of writing
		 * pixel shader-like functions using fixed-point arithmetics. Use of vector optimizatons
		 * techniques (SSE2, AVX, NEON, etc) are needed for optimal performance.
		 */
		@nogc pure nothrow void function(uint* src, uint* dest, size_t length, ubyte value) renderFunc;
		int		width;				/// Width of the sprite
		int		height;				/// Height of the sprite
		int		scaleHoriz;			/// Horizontal scaling
		int		scaleVert;			/// Vertical scaling
		int		priority;			/// Used for automatic sorting and identification.
		/**
		 * Selects the palette of the sprite.
		 * Amount of accessable color depends on the palette access shifting value. A value of 8 enables 
		 * 256 * 256 color palettes, and a value of 4 enables 4096 * 16 color palettes.
		 * `paletteSh` can be set lower than what the bitmap is capable of storing at its maximum, this
		 * can enable the packing of more palettes within the main one, e.g. a `paletteSh` value of 7
		 * means 512 * 128 color palettes, while the bitmaps are still stored in the 8 bit "chunky" mode
		 * instead of 7 bit planar that would require way more processing power. However this doesn't 
		 * limit the bitmap's ability to access 256 colors, and this can result in memory leakage if
		 * the end developer isn't careful enough.
		 */
		ushort	paletteSel;
		//ubyte	flags;				/// Flags packed into a single byte (bitmapType, paletteSh)
		mixin(bitfields!(
			ubyte, "paletteSh", 4,
			ubyte, "bmpType", 4,
		));
		ubyte	masterAlpha = ubyte.max;/// Sets the master alpha value of the sprite, e.g. opacity
		//ubyte wordLength;			/// Determines the word length of a sprite in a much quicker way than getting classinfo.
		//ubyte paletteSh;			/// Palette shifting value. 8 is default for 8 bit, and 4 for 4 bit bitmaps. (see paletteSel for more info)
		//static enum ubyte	PALETTESH_MASK = 0x0F;	/// Mask for paletteSh
		//static enum ubyte	BMPTYPE_MASK = 0x80;	/// Mask for bmpType
		/**
		 * Creates a display list item with palette selector.
		 */
		this(Coordinate position, ABitmap sprite, int priority, ushort paletteSel = 0, int scaleHoriz = 1024,
				int scaleVert = 1024) pure @trusted nothrow {
			this.position = position;
			this.width = sprite.width;
			this.height = sprite.height;
			this.priority = priority;
			this.paletteSel = paletteSel;
			this.scaleVert = scaleVert;
			this.scaleHoriz = scaleHoriz;
			slice = Coordinate(0,0,sprite.width,sprite.height);
			if (typeid(sprite) is typeid(Bitmap4Bit)) {
				bmpType = BitmapTypes.Bmp4Bit;
				paletteSh = 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap8Bit)) {
				bmpType = BitmapTypes.Bmp8Bit;
				paletteSh = 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap16Bit)) {
				bmpType = BitmapTypes.Bmp16Bit;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap32Bit)) {
				bmpType = BitmapTypes.Bmp32Bit;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		/**
		 * Creates a display list item without palette selector.
		 */
		this(Coordinate position, Coordinate slice, ABitmap sprite, int priority, int scaleHoriz = 1024,
				int scaleVert = 1024) pure @trusted nothrow {
			if(slice.top < 0)
				slice.top = 0;
			if(slice.left < 0)
				slice.left = 0;
			if(slice.right >= sprite.width)
				slice.right = sprite.width - 1;
			if(slice.bottom >= sprite.height)
				slice.bottom = sprite.height - 1;
			this.slice = slice;
			this(position, sprite, priority, paletteSel, scaleHoriz, scaleVert);
		}
		/+
		/// Palette shifting value. 8 is default for 8 bit, and 4 for 4 bit bitmaps. (see paletteSel for more info)
		@property ubyte paletteSh() @safe @nogc pure nothrow const {
			return cast(ubyte)flags & PALETTESH_MASK;
		}
		/// Palette shifting value. 8 is default for 8 bit, and 4 for 4 bit bitmaps. (see paletteSel for more info)
		@property ubyte paletteSh(ubyte val) @safe @nogc pure nothrow {
			flags &= ~PALETTESH_MASK;
			flags |= val;
			return cast(ubyte)flags & PALETTESH_MASK;
		}
		/// Defines the type of bitmap the sprite is using. This method is much faster and simpler than checking the class type of the bitmap.
		@property BitmapTypes bmpType() @safe @nogc pure nothrow const {
			return cast(BitmapTypes)((flags & BMPTYPE_MASK) >>> 4);
		}
		/// Defines the type of bitmap the sprite is using. This method is much faster and simpler than checking the class type of the bitmap.
		@property BitmapTypes bmpType(BitmapTypes val) @safe @nogc pure nothrow {
			flags &= ~BMPTYPE_MASK;
			flags |= cast(ubyte)val << 4;
			return bmpType;
		}+/
		/**
		 * Resets the slice to its original position.
		 */
		void resetSlice() pure @nogc @safe nothrow {
			slice.left = 0;
			slice.top = 0;
			slice.right = position.width - 1;
			slice.bottom = position.height - 1;
		}
		/**
		 * Replaces the sprite with a new one.
		 * If the sizes are mismatching, the top-left coordinates are left as is, but the slicing is reset.
		 */
		void replaceSprite(ABitmap sprite) @trusted pure nothrow {
			//this.sprite = sprite;
			//palette = sprite.getPalettePtr();
			if(this.width != sprite.width || this.height != sprite.height){
				this.width = sprite.width;
				this.height = sprite.height;
				position.right = position.left + cast(int)scaleNearestLength(width, scaleHoriz);
				position.bottom = position.top + cast(int)scaleNearestLength(height, scaleVert);
				resetSlice();
			}
			if (typeid(sprite) is typeid(Bitmap4Bit)) {
				bmpType = BitmapTypes.Bmp4Bit;
				paletteSh = 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap8Bit)) {
				bmpType = BitmapTypes.Bmp8Bit;
				paletteSh = 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap16Bit)) {
				bmpType = BitmapTypes.Bmp16Bit;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap32Bit)) {
				bmpType = BitmapTypes.Bmp32Bit;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		@nogc int opCmp(in DisplayListItem d) const pure @safe nothrow {
			return priority - d.priority;
		}
		@nogc bool opEquals(in DisplayListItem d) const pure @safe nothrow {
			return priority == d.priority;
		}
		@nogc int opCmp(in int pri) const pure @safe nothrow {
			return priority - pri;
		}
		@nogc bool opEquals(in int pri) const pure @safe nothrow {
			return priority == pri;
		}
		
		string toString() const {
			import std.conv : to;
			return "{Position: " ~ position.toString ~ ";\nDisplayed portion: " ~ slice.toString ~";\nPriority: " ~
				to!string(priority) ~ "; PixelData: " ~ to!string(pixelData) ~ 
				"; PaletteSel: " ~ to!string(paletteSel) ~ "; bmpType: " ~ to!string(bmpType) ~ "}";
		}
	}
	alias DisplayList = TreeMap!(int, DisplayListItem);
	alias OnScreenList = SortedList!(int, "a < b", false);
	//protected DisplayListItem[] displayList;	///Stores the display data
	protected DisplayList		allSprites;			///All sprites of this layer
	protected OnScreenList		displayedSprites;	///Sprites that are being displayed
	protected Color[2048]		src;				///Local buffer for scaling
	//size_t[8] prevSize;
	///Default ctor
	public this(RenderingMode renderMode = RenderingMode.AlphaBlend) @nogc nothrow @safe {
		setRenderingMode(renderMode);
		//src[0].length = 1024;
	}
	/**
	 * Checks all sprites for whether they're on screen or not.
	 * Called every time the layer is being scrolled.
	 */
	public void checkAllSprites() @safe pure nothrow {
		foreach (key; allSprites) {
			checkSprite(key);
		}
	}
	/**
	 * Checks whether a sprite would be displayed on the screen, then updates the display list.
	 * Returns true if it's on screen.
	 */
	public bool checkSprite(int n) @safe pure nothrow {
		return checkSprite(allSprites[n]);
	}
	///Ditto.
	protected bool checkSprite(DisplayListItem sprt) @safe pure nothrow {
		//assert(sprt.bmpType != BitmapTypes.Undefined && sprt.pixelData, "DisplayList error!");
		if(sprt.slice.width && sprt.slice.height 
				&& (sprt.position.right > sX && sprt.position.bottom > sY && 
				sprt.position.left < sX + rasterX && sprt.position.top < sY + rasterY)) {
			displayedSprites.put(sprt.priority);
			return true;
		} else {
			displayedSprites.removeByElem(sprt.priority);
			return false;
		}
	}
	/**
	 * Searches the DisplayListItem by priority and returns it.
	 * Can be used for external use without any safety issues.
	 */
	public DisplayListItem getDisplayListItem(int n) @nogc pure @safe nothrow {
		return allSprites[n];
	}
	/**
	 * Searches the DisplayListItem by priority and returns it.
	 * Intended for internal use, as it returns it as a reference value.
	 */
	protected DisplayListItem* getDisplayListItem_internal(int n) @nogc pure @safe nothrow {
		return allSprites.ptrOf(n);
	}
	override public void setRasterizer(int rX,int rY) {
		super.setRasterizer(rX,rY);
	}
	///Returns the displayed portion of the sprite.
	public Coordinate getSlice(int n) @nogc pure @safe nothrow {
		return getDisplayListItem(n).slice;
	}
	///Writes the displayed portion of the sprite.
	///Returns the new slice, if invalid (greater than the bitmap, etc.) returns Coordinate.init.
	public Coordinate setSlice(int n, Coordinate slice) @safe pure nothrow {
		DisplayListItem* sprt = allSprites.ptrOf(n);
		if(sprt) {
			sprt.slice = slice;
			checkSprite(*sprt);
			return sprt.slice;
		} else {
			return Coordinate.init;
		}
	}
	///Returns the selected paletteID of the sprite.
	public ushort getPaletteID(int n) @nogc pure @safe nothrow {
		return getDisplayListItem(n).paletteSel;
	}
	///Sets the paletteID of the sprite. Returns the new ID, which is truncated to the possible values with a simple binary and operation
	///Palette must exist in the parent Raster, otherwise AccessError might happen
	public ushort setPaletteID(int n, ushort paletteID) @nogc pure @safe nothrow {
		return getDisplayListItem_internal(n).paletteSel = paletteID;
	}
	/**
	 * Adds a sprite to the layer.
	 */
	public void addSprite(ABitmap s, int n, Box c, ushort paletteSel = 0, int scaleHoriz = 1024, 
				int scaleVert = 1024) @safe nothrow {
		DisplayListItem d = DisplayListItem(c, s, n, paletteSel, scaleHoriz, scaleVert);
		d.renderFunc = mainRenderingFunction;
		synchronized
			allSprites[n] = d;
		checkSprite(d);
	}
	///Ditto
	public void addSprite(ABitmap s, int n, int x, int y, ushort paletteSel = 0, int scaleHoriz = 1024, 
				int scaleVert = 1024) @safe nothrow {
		DisplayListItem d = DisplayListItem(Box(x, y, s.width + x, s.height + y), s, n, paletteSel, scaleHoriz, scaleVert);
		d.renderFunc = mainRenderingFunction;
		synchronized
			allSprites[n] = d;
		checkSprite(d);
	}
	/**
	 * Replaces the bitmap of the given sprite.
	 */
	public void replaceSprite(ABitmap s, int n) @safe nothrow {
		DisplayListItem* sprt = getDisplayListItem_internal(n);
		sprt.replaceSprite(s);
		checkSprite(*sprt);
	}
	///Ditto with move
	public void replaceSprite(ABitmap s, int n, int x, int y) @safe nothrow {
		DisplayListItem* sprt = getDisplayListItem_internal(n);
		sprt.replaceSprite(s);
		sprt.position.move(x, y);
		checkSprite(*sprt);
	}
	///Ditto with move
	public void replaceSprite(ABitmap s, int n, Coordinate c) @safe nothrow {
		DisplayListItem* sprt = allSprites.ptrOf(n);
		sprt.replaceSprite(s);
		sprt.position = c;
		checkSprite(*sprt);
	}
	/**
	 * Removes a sprite from both displaylists by priority.
	 */
	public void removeSprite(int n) @safe nothrow {
		synchronized {
			displayedSprites.removeByElem(n);
			allSprites.remove(n);
		}
	}
	///Clears all sprite from the layer.
	public void clear() @safe nothrow {
		displayedSprites = OnScreenList.init;
		allSprites = DisplayList.init;
	}
	/**
	 * Moves a sprite to the given position.
	 */
	public void moveSprite(int n, int x, int y) @safe nothrow {
		DisplayListItem* sprt = allSprites.ptrOf(n);
		sprt.position.move(x, y);
		checkSprite(*sprt);
	}
	/**
	 * Moves a sprite by the given amount.
	 */
	public void relMoveSprite(int n, int x, int y) @safe nothrow {
		DisplayListItem* sprt = allSprites.ptrOf(n);
		sprt.position.relMove(x, y);
		checkSprite(*sprt);
	}
	///Sets the rendering function for the sprite (defaults to the layer's rendering function)
	public void setSpriteRenderingMode(int n, RenderingMode mode) @safe nothrow {
		DisplayListItem* sprt = allSprites.ptrOf(n);
		sprt.renderFunc = getRenderingFunc(mode);
	}
	public @nogc Coordinate getSpriteCoordinate(int n) @safe nothrow {
		return allSprites[n].position;
	}
	///Scales sprite horizontally. Returns the new size, or -1 if the scaling value is invalid, or -2 if spriteID not found.
	public int scaleSpriteHoriz(int n, int hScl) @trusted nothrow { 
		DisplayListItem* sprt = allSprites.ptrOf(n);
		if(!sprt) return -2;
		else if(!hScl) return -1;
		else {
			sprt.scaleHoriz = hScl;
			const int newWidth = cast(int)scaleNearestLength(sprt.width, hScl);
			sprt.slice.right = newWidth;
			sprt.position.right = sprt.position.left + newWidth;
			checkSprite(*sprt);
			return newWidth;
		}
	}
	///Scales sprite vertically. Returns the new size, or -1 if the scaling value is invalid, or -2 if spriteID not found.
	public int scaleSpriteVert(int n, int vScl) @trusted nothrow {
		DisplayListItem* sprt = allSprites.ptrOf(n);
		if(!sprt) return -2;
		else if(!vScl) return -1;
		else {
			sprt.scaleVert = vScl;
			const int newHeight = cast(int)scaleNearestLength(sprt.height, vScl);
			sprt.slice.bottom = newHeight;
			sprt.position.bottom = sprt.position.top + newHeight;
			checkSprite(*sprt);
			return newHeight;
		}
		/+if (!vScl) return -1;
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].scaleVert = vScl;
				const int newHeight = cast(int)scaleNearestLength(displayList[i].height, vScl);
				displayList[i].slice.bottom = newHeight;
				return displayList[i].position.bottom = displayList[i].position.top + newHeight;
			}
		}
		return -2;+/
	}
	///Gets the sprite's current horizontal scale value
	public int getScaleSpriteHoriz(int n) @nogc @trusted nothrow {
		return allSprites[n].scaleHoriz;
	}
	///Gets the sprite's current vertical scale value
	public int getScaleSpriteVert(int n) @nogc @trusted nothrow {
		return allSprites[n].scaleVert;
	}
	public override @nogc void updateRaster(void* workpad, int pitch, Color* palette) {
		/*
		 * BUG 1: If sprite is wider than 2048 pixels, it'll cause issues (mostly memory leaks) due to a hack.
		 * BUG 2: Obscuring the top part of a sprite when scaleVert is not 1024 will cause glitches.
		 */
		foreach (priority ; displayedSprites) {
		//foreach(i ; displayList){
			DisplayListItem i = allSprites[priority];
			const int left = i.position.left + i.slice.left;
			const int top = i.position.top + i.slice.top;
			const int right = i.position.left + i.slice.right;
			const int bottom = i.position.top + i.slice.bottom;
			/+if((i.position.right > sX && i.position.bottom > sY) && (i.position.left < sX + rasterX && i.position.top < sY +
					rasterY)){+/
			//if((right > sX && left < sX + rasterX) && (bottom > sY && top < sY + rasterY) && i.slice.width && i.slice.height){
			int offsetXA = sX > left ? sX - left : 0;//Left hand side offset, zero if not obscured
			const int offsetXB = sX + rasterX < right ? right - (sX + rasterX) : 0; //Right hand side offset, zero if not obscured
			const int offsetYA = sY > top ? sY - top : 0;		//top offset of sprite, zero if not obscured
			const int offsetYB = sY + rasterY < bottom ? bottom - (sY + rasterY) + 1 : 1;	//bottom offset of sprite, zero if not obscured
			//const int offsetYB0 = cast(int)scaleNearestLength(offsetYB, i.scaleVert);
			const int sizeX = i.slice.width();		//total displayed width
			const int offsetX = left - sX;
			const int length = sizeX - offsetXA - offsetXB - 1;
			//int lengthY = i.slice.height - offsetYA - offsetYB;
			//const int lfour = length * 4;
			const int offsetY = sY < top ? (top-sY)*pitch : 0;	//used if top portion of the sprite is off-screen
			//offset = i.scaleVert % 1024;
			const int scaleVertAbs = i.scaleVert * (i.scaleVert < 0 ? -1 : 1);	//absolute value of vertical scaling, used in various calculations
			//int offset, prevOffset;
			const int offsetAmount = scaleVertAbs <= 1024 ? 1024 : scaleVertAbs;	//used to limit the amount of re-rendering every line
			//offset = offsetYA<<10;
			const int offsetYA0 = cast(int)(cast(double)offsetYA / (1024.0 / cast(double)scaleVertAbs));	//amount of skipped lines (I think) TODO: remove floating-point arithmetic
			const int sizeXOffset = i.width * (i.scaleVert < 0 ? -1 : 1);
			int prevOffset = offsetYA0 * offsetAmount;		//
			int offset = offsetYA0 * scaleVertAbs;
			const size_t p0offset = (i.scaleHoriz > 0 ? offsetXA : offsetXB); //determines offset based on mirroring
			// HACK: as I couldn't figure out a better method yet I decided to scale a whole line, which has a lot of problems
			const int scalelength = i.position.width < 2048 ? i.width : 2048;	//limit width to 2048, the minimum required for this scaling method to work
			void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
			final switch (i.bmpType) with (BitmapTypes) {
				case Bmp4Bit:
					ubyte* p0 = cast(ubyte*)i.pixelData + i.width * ((i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0)>>1);
					for(int y = offsetYA ; y < i.slice.height - offsetYB ; ){
						horizontalScaleNearest4BitAndCLU(p0, src.ptr, palette + (i.paletteSel<<i.paletteSh), scalelength, offsetXA & 1,
								i.scaleHoriz);
						prevOffset += offsetAmount;
						for(; offset < prevOffset; offset += scaleVertAbs){
							y++;
							i.renderFunc(cast(uint*)src.ptr + p0offset, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset >> 1;
					}
					//}
					break;
				case Bmp8Bit:
					ubyte* p0 = cast(ubyte*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
					for(int y = offsetYA ; y < i.slice.height - offsetYB ; ){
						horizontalScaleNearestAndCLU(p0, src.ptr, palette + (i.paletteSel<<i.paletteSh), scalelength, i.scaleHoriz);
						prevOffset += 1024;
						for(; offset < prevOffset; offset += scaleVertAbs){
							y++;
							i.renderFunc(cast(uint*)src.ptr + p0offset, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset;
					}
					break;
				case Bmp16Bit:
					ushort* p0 = cast(ushort*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
					for(int y = offsetYA ; y < i.slice.height - offsetYB ; ){
						horizontalScaleNearestAndCLU(p0, src.ptr, palette, scalelength, i.scaleHoriz);
						prevOffset += 1024;
						for(; offset < prevOffset; offset += scaleVertAbs){
							y++;
							i.renderFunc(cast(uint*)src.ptr + p0offset, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset;
					}
					break;
				case Bmp32Bit:
					Color* p0 = cast(Color*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
					for(int y = offsetYA ; y < i.slice.height - offsetYB ; ){
						horizontalScaleNearest(p0, src.ptr, scalelength, i.scaleHoriz);
						prevOffset += 1024;
						for(; offset < prevOffset; offset += scaleVertAbs){
							y++;
							i.renderFunc(cast(uint*)src.ptr + p0offset, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset;
					}
					//}
					break;
				case Undefined, Bmp1Bit, Bmp2Bit, Planar:
					break;
			}

			//}
		}
		//foreach(int threadOffset; threads.parallel)
			//free(src[threadOffset]);
	}
	///Absolute scrolling.
	public override void scroll(int x, int y) @safe pure nothrow {
		sX = x;
		sY = y;
		checkAllSprites;
	}
	///Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
	public override void relScroll(int x, int y) @safe pure nothrow {
		sX += x;
		sY += y;
		checkAllSprites;
	}
}