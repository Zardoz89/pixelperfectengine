/*
 * rasterWindow.d
 *
 * Outputs layers to a window with the capability of temporarily removing them
 */
import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.layers;
import CPUblit.composing;
import CPUblit.draw;
import CPUblit.colorlookup;

import document;

/**
 * Implements a subraster using a window. Has the capability of skipping over individual layers.
 */
public class RasterWindow : Window {
	protected Bitmap32Bit trueOutput, rasterOutput;
	protected Color[] paletteLocal;
	protected Color* paletteShared;
	protected Layer[int] layers;
	protected int[] layerList, mutedLayers;
	protected int rasterX, rasterY;
	protected dstring documentName;
	protected MapDocument document;

	public this(int x, int y, Color* paletteShared, dstring documentName, MapDocument document){
		trueOutput = new Bitmap32Bit(x,y);
		rasterOutput = new Bitmap32Bit(x + 2, y + 18);
		super(Coordinate(0, 0, x + 2, y + 18), documentName, ["settingsButtonA", "rightArrowA", "leftArrowA",
				"downArrowA", "upArrowA",]);
		this.paletteShared = paletteShared;
		this.documentName = documentName;
		this.document = document;
	}
	public override @property ABitmap getOutput(){
		return trueOutput;
	}
	public @property Color[] palette(Color[] val) inout {
		return paletteLocal = val;
	}
	public override void passMouseEvent(int x, int y, int state, ubyte button){
		StyleSheet ss = getStyleSheet;
		if(y >= ss.drawParameters["WindowHeaderHeight"] && y < trueOutput.height - 1 && x > 0 && x < trueOutput.width){
			y -= ss.drawParameters["WindowHeaderHeight"];
			x--;
			//left : placement ; right : menu ; middle : delete ; other buttons : user defined
		}else
			super.passMouseEvent(x, y, state, button);
	}
	public override void draw(bool drawHeaderOnly = false){
		if(output.output.width != position.width || output.output.height != position.height){
			output = new BitmapDrawer(position.width(), position.height());
			trueOutput = new Bitmap32Bit(position.width(), position.height());
			rasterOutput = new Bitmap32Bit(position.width() - 2, position.height() - 18);
		}

		drawHeader();
		for(int y ; y < 16 ; y++){
			colorLookup(output.output.getPtr + y * position.width, trueOutput.getPtr + y * position.width, paletteShared,
					position.width);
		}
		/*if(drawHeaderOnly)
			return;*/
		//draw the borders. we do not need fills or drawing elements
		uint* ptr = cast(uint*)trueOutput.getPtr;
		StyleSheet ss = getStyleSheet;
		drawLine!uint(0, 16, 0, position.height, paletteShared[ss.getColor("windowascent")].raw, ptr, trueOutput.width);
		drawLine!uint(0, 16, position.width, 16, paletteShared[ss.getColor("windowascent")].raw, ptr, trueOutput.width);
		drawLine!uint(position.width, 16, position.width, position.height, paletteShared[ss.getColor("windowdescent")].raw,
				ptr, trueOutput.width);
		drawLine!uint(0, position.height, position.width, position.height, paletteShared[ss.getColor("windowdescent")].raw,
				ptr, trueOutput.width);
	}
	/**
	 * Updates the raster of the window.
	 */
	public void updateRaster(){
		//update each layer individually
		for(int i ; i < layerList.length ; i++){
			layers[layerList[i]].updateRaster(rasterOutput.getPtr, rasterX * 4, paletteLocal.ptr);
		}
		//copy the raster output to the target
		Color* p0 = rasterOutput.getPtr, p1 = trueOutput.getPtr + (17 * trueOutput.width);
		const int x = rasterOutput.width;
		p1++;
		for(int y ; y < rasterY; y++){
			helperFunc(p0, p1, x);
			p0 += x;
			p1 += trueOutput.width;
		}
	}
	/**
	 * Copies and sets all alpha values to 255 to avoid transparency issues
	 */
	protected @nogc void helperFunc(void* src, void* dest, size_t length) pure{
		import PixelPerfectEngine.system.platform;
		static if(USE_INTEL_INTRINSICS){
			import inteli.emmintrin;
			immutable ubyte[16] ALPHA_255_VEC = [255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0];
			while(length > 4){
				_mm_storeu_si128(cast(__m128i*)dest, _mm_loadu_si128(cast(__m128i*)src) |
						_mm_loadu_si128(cast(__m128i*)(cast(void*)ALPHA_255_VEC.ptr)));
				src += 16;
				dest += 16;
				length -= 4;
			}
			while(length){
				*cast(uint*)dest = *cast(uint*)src | 0xFF_00_00_00;
				src += 4;
				dest += 4;
				length--;
			}
		}else{
			while(length){
				*cast(uint*)dest = *cast(uint*)src | 0xFF_00_00_00;
				src += 4;
				dest += 4;
				length--;
			}
		}
	}

}
