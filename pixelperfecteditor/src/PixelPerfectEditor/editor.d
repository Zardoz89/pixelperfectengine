﻿/*
 * Copyright (C) 2016-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Editor, graphics.outputScreen module
 */

module editor;

import std.conv;

import PixelPerfectEngine.graphics.outputScreen;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.extbmp.extbmp;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.draw;
//import collision;
import PixelPerfectEngine.system.inputHandler;
import PixelPerfectEngine.system.file;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.config;
import PixelPerfectEngine.system.systemUtility;
import std.stdio;
import std.conv;
import derelict.sdl2.sdl;
import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.map.mapload;

import converterdialog;
import tileLayer;
import newLayerDialog;
import about;

public interface IEditor{
	public void onExit();
	public void newDocument();
	public void newLayer();
	public void xmpToolkit();
	public void passActionEvent(Event e);
	public void createNewDocument(wstring name, int rX, int rY, int pal);
	public void createNewLayer(string name, int type, int tX, int tY, int mX, int mY, int priority);
}

public class NewDocumentDialog : Window, ActionListener{
	public IEditor ie;
	private TextBox[] textBoxes;
	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public this(InputHandler inputhandler){
		this(Coordinate(10,10,220,150),"New Document");
		
		Button[] buttons;
		Label[] labels;
		buttons ~= new Button("Ok", "ok", Coordinate(150,110,200,130));

		labels ~= new Label("Name:","",Coordinate(5,20,80,39));
		labels ~= new Label("RasterX:","",Coordinate(5,40,80,59));
		labels ~= new Label("RasterY:","",Coordinate(5,60,80,79));
		labels ~= new Label("N. of colors:","",Coordinate(5,80,120,99));
		textBoxes ~= new TextBox("","name",Coordinate(81,20,200,39));
		textBoxes ~= new TextBox("","rX",Coordinate(121,40,200,59));
		textBoxes ~= new TextBox("","rY",Coordinate(121,60,200,79));
		textBoxes ~= new TextBox("","pal",Coordinate(121,80,200,99));
		addElement(buttons[0], EventProperties.MOUSE);
		foreach(WindowElement we; labels){
			addElement(we, EventProperties.MOUSE);
		}
		foreach(TextBox we; textBoxes){
			//we.addTextInputHandler(inputhandler);
			addElement(we, EventProperties.MOUSE);
		}
		buttons[0].al ~= this;
	}

	public void actionEvent(Event event){
		if(event.source == "ok"){
			ie.createNewDocument(textBoxes[0].getText(), to!int(textBoxes[1].getText()), to!int(textBoxes[2].getText()), to!int(textBoxes[3].getText()));
			
			parent.closeWindow(this);
		}
	}
}

/+public class NewLayerDialog : Window, ActionListener{
	public IEditor ie;
	private TextBox[] textBoxes;
	private RadioButtonGroup layerType;
	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public this(IEditor ie){
		this(Coordinate(10,10,220,310),"New Layer");
		this.ie = ie;
		Label[] labels;
		labels ~= new Label("Name:","",Coordinate(5,20,80,39));
		labels ~= new Label("TileX:","",Coordinate(5,40,80,59));
		labels ~= new Label("TileY:","",Coordinate(5,60,80,79));
		labels ~= new Label("MapX:","",Coordinate(5,80,80,99));
		labels ~= new Label("MapY:","",Coordinate(5,100,80,119));
		labels ~= new Label("Priority:","",Coordinate(5,120,80,139));
		textBoxes ~= new TextBox("","name",Coordinate(81,20,200,39));
		textBoxes ~= new TextBox("","tX",Coordinate(81,40,200,59));
		textBoxes ~= new TextBox("","tY",Coordinate(81,60,200,79));
		textBoxes ~= new TextBox("","mX",Coordinate(81,80,200,99));
		textBoxes ~= new TextBox("","mY",Coordinate(81,100,200,119));
		textBoxes ~= new TextBox("","pri",Coordinate(81,120,200,139));
		layerType = new RadioButtonGroup("Layertype:","layertype",Coordinate(5,150,200,270),["Dummy","Tile(8Bit)","Tile(16Bit)","Tile(32Bit)","Sprite(8Bit)","Sprite(16Bit)","Sprite(32Bit)"],16,1);
		Button b = new Button("Ok","ok",Coordinate(150,275,215,295));
		b.al ~= this;
		addElement(b, EventProperties.MOUSE);
		foreach(WindowElement we; labels){
			addElement(we, EventProperties.MOUSE);
		}
		foreach(TextBox we; textBoxes){
			//we.addTextInputHandler(this);
			addElement(we, EventProperties.MOUSE);
		}
		addElement(layerType, EventProperties.MOUSE);
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(string source, int type, int value, wstring message){}
	public void actionEvent(Event event){
		if(event.source == "ok"){

			switch(layerType.getValue){
				case 1, 2, 3:
					ie.createNewLayer(to!string(textBoxes[0].getText), layerType.getValue, to!int(textBoxes[1].getText), to!int(textBoxes[2].getText), to!int(textBoxes[3].getText),
							to!int(textBoxes[4].getText), to!int(textBoxes[5].getText));
					break;
				case 4, 5, 6:
					ie.createNewLayer(to!string(textBoxes[0].getText), layerType.getValue, 0, 0, 0, 0, to!int(textBoxes[5].getText));
					break;
				default: break;
			}
			parent.closeWindow(this);
		}
	}
}+/

public class EditorWindowHandler : WindowHandler, ElementContainer, ActionListener{
	private WindowElement[] elements, mouseC, keyboardC, scrollC;
	private ListBox layerList, prop;
	//private ListBoxColumn[] propTL, propSL, propSLE;
	//private ListBoxColumn[] layerListE;
	public Label[] labels;
	private int[] propTLW, propSLW, propSLEW;
	public IEditor ie;

	//public InputHandler ih;

	private BitmapDrawer output;
	public this(int sx, int sy, int rx, int ry,ISpriteLayer sl){
		super(sx,sy,rx,ry,sl);
		output = new BitmapDrawer(rx, ry);
		addBackground(output.output);
		propTLW = [40, 320];
		propSLW = [160, 320, 48, 64];
		propSLEW = [160, 320, 40, 56];
		WindowElement.popUpHandler = this;
	}

	public void initGUI(){
		output.drawFilledRectangle(0, rasterX, 0, rasterY, 0x0005);
		/*layerListE ~= ListBoxColumn("Num", [""]);
		layerListE ~= ListBoxColumn("Name", [""]);
		layerListE ~= ListBoxColumn("Type", [""]);
		layerList = new ListBox("layerList", Coordinate(5,7,205,98), layerListE, [30,160,64],15);
		propTL ~= ListBoxColumn("ID", [""]);
		propTL ~= ListBoxColumn("Name", [""]);
		propSL ~= ListBoxColumn("Type", [""]);
		propSL ~= ListBoxColumn("Name", [""]);
		propSL ~= ListBoxColumn("SizeX", [""]);
		propSL ~= ListBoxColumn("SizeY", [""]);
		propSLE ~= ListBoxColumn("Type", [""]);
		propSLE ~= ListBoxColumn("Name", [""]);
		propSLE ~= ListBoxColumn("PosX", [""]);
		propSLE ~= ListBoxColumn("PosY", [""]);
		prop = new ListBox("prop", Coordinate(5,105,460,391), propSL, propSLW,15);
		addElement(layerList, EventProperties.MOUSE | EventProperties.SCROLL);
		addElement(prop, EventProperties.MOUSE | EventProperties.SCROLL);
		/*addElement(new Button("New","new",Coordinate(210,5,290,25)), EventProperties.MOUSE);
		addElement(new Button("Load","load",Coordinate(295,5,375,25)), EventProperties.MOUSE);
		addElement(new Button("Save","save",Coordinate(380,5,460,25)), EventProperties.MOUSE);
		addElement(new Button("Save As","saveas",Coordinate(465,5,545,25)), EventProperties.MOUSE);
		addElement(new Button("Help","help",Coordinate(550,5,630,25)), EventProperties.MOUSE);
		addElement(new Button("New Layer","newL",Coordinate(210,30,290,50)), EventProperties.MOUSE);
		addElement(new Button("Del Layer","delL",Coordinate(295,30,375,50)), EventProperties.MOUSE);
		addElement(new Button("Imp Layer","impL",Coordinate(380,30,460,50)), EventProperties.MOUSE);
		addElement(new Button("Imp TileD","impTD",Coordinate(465,30,545,50)), EventProperties.MOUSE);
		addElement(new Button("Imp ObjD","impOD",Coordinate(550,30,630,50)), EventProperties.MOUSE);
		addElement(new Button("Imp Map","impM",Coordinate(210,55,290,75)), EventProperties.MOUSE);
		addElement(new Button("Imp Img","impI",Coordinate(295,55,375,75)), EventProperties.MOUSE);
		addElement(new Button("XMP Edit","xmp",Coordinate(380,55,460,75)), EventProperties.MOUSE);
		addElement(new Button("Palette","pal",Coordinate(465,55,545,75)), EventProperties.MOUSE);
		addElement(new Button("Settings","setup",Coordinate(550,55,630,75)), EventProperties.MOUSE);
		addElement(new Button("Doc Prop","docP",Coordinate(210,80,290,100)), EventProperties.MOUSE);
		addElement(new Button("Export","exp",Coordinate(295,80,375,100)), EventProperties.MOUSE);*/
		//addElement(new Button("Save","save",Coordinate(380,80,460,100)), EventProperties.MOUSE);
		//addElement(new Button("Save As","saveas",Coordinate(465,80,545,100)), EventProperties.MOUSE);
		//wstring[] menuNames = ["FILE", "EDIT", "VIEW", "LAYERS", "TOOLS", "HELP"];
		PopUpMenuElement[] menuElements;
		menuElements ~= new PopUpMenuElement("file", "FILE");

		menuElements[0].setLength(7);
		menuElements[0][0] = new PopUpMenuElement("new", "New PPE map", "Ctrl + N");
		menuElements[0][1] = new PopUpMenuElement("newTemp", "New PPE map from template", "Ctrl + Shift + N");
		menuElements[0][2] = new PopUpMenuElement("load", "Load PPE map", "Ctrl + L");
		menuElements[0][3] = new PopUpMenuElement("save", "Save PPE map", "Ctrl + S");
		menuElements[0][4] = new PopUpMenuElement("saveAs", "Save PPE map as", "Ctrl + Shift + S");
		menuElements[0][5] = new PopUpMenuElement("saveTemp", "Save PPE map as template", "Ctrl + Shift + T");
		menuElements[0][6] = new PopUpMenuElement("exit", "Exit application", "Alt + F4");

		menuElements ~= new PopUpMenuElement("edit", "EDIT");
		
		menuElements[1].setLength(7);
		menuElements[1][0] = new PopUpMenuElement("undo", "Undo", "Ctrl + Z");
		menuElements[1][1] = new PopUpMenuElement("redo", "Redo", "Ctrl + Shift + Z");
		menuElements[1][2] = new PopUpMenuElement("copy", "Copy", "Ctrl + C");
		menuElements[1][3] = new PopUpMenuElement("cut", "Cut", "Ctrl + X");
		menuElements[1][4] = new PopUpMenuElement("paste", "Paste", "Ctrl + V");
		menuElements[1][5] = new PopUpMenuElement("editorSetup", "Editor Settings");
		menuElements[1][6] = new PopUpMenuElement("docSetup", "Document Settings");

		menuElements ~= new PopUpMenuElement("view", "VIEW");

		menuElements[2].setLength(2);
		menuElements[2][0] = new PopUpMenuElement("layerList", "Layer list", "Alt + L");
		menuElements[2][1] = new PopUpMenuElement("layerTools", "Layer tools", "Alt + T");

		menuElements ~= new PopUpMenuElement("layers", "LAYERS");

		menuElements[3].setLength(4);
		menuElements[3][0] = new PopUpMenuElement("newLayer", "New layer", "Alt + N");
		menuElements[3][1] = new PopUpMenuElement("delLayer", "Delete layer", "Alt + Del");
		menuElements[3][2] = new PopUpMenuElement("impLayer", "Import layer", "Alt + Shift + I");
		menuElements[3][3] = new PopUpMenuElement("layerSrc", "Layer resources", "Alt + R");

		menuElements ~= new PopUpMenuElement("tools", "TOOLS");

		menuElements[4].setLength(2);
		menuElements[4][0] = new PopUpMenuElement("xmpTool", "XMP Toolkit", "Alt + X");
		menuElements[4][1] = new PopUpMenuElement("mapXMLEdit", "Edit map as XML", "Ctrl + Alt + X");
		//menuElements[4][0] = new PopUpMenuElement("", "", "");

		menuElements ~= new PopUpMenuElement("help", "HELP");

		menuElements[5].setLength(2);
		menuElements[5][0] = new PopUpMenuElement("helpFile", "Content", "F1");
		menuElements[5][1] = new PopUpMenuElement("about", "About");
		
		//addElement(new Button("Exit","exit",Coordinate(550,80,630,100)), EventProperties.MOUSE);
		/*labels ~= new Label("Layer info:","null",Coordinate(5,395,101,415));
		labels ~= new Label("ScrollX:","null",Coordinate(5,415,70,435));
		labels ~= new Label("0","sx",Coordinate(71,415,140,435));
		labels ~= new Label("ScrollY:","null",Coordinate(145,415,210,435));
		labels ~= new Label("0","sy",Coordinate(211,415,280,435));
		labels ~= new Label("ScrollRateX:","null",Coordinate(281,415,378,435));
		labels ~= new Label("0","srx",Coordinate(379,415,420,435));
		labels ~= new Label("ScrollRateY:","null",Coordinate(421,415,518,435));
		labels ~= new Label("0","sry",Coordinate(519,415,560,435));
		labels ~= new Label("MapX:","null",Coordinate(5,435,45,455));
		labels ~= new Label("0","mx",Coordinate(46,435,100,455));
		labels ~= new Label("MapY:","null",Coordinate(105,435,145,455));
		labels ~= new Label("0","my",Coordinate(146,435,200,455));
		labels ~= new Label("TileX:","null",Coordinate(205,435,255,455));
		labels ~= new Label("0","tx",Coordinate(256,435,310,455));
		labels ~= new Label("TileY:","null",Coordinate(315,435,365,455));
		labels ~= new Label("0","ty",Coordinate(366,435,420,455));*/
		addElement(new MenuBar("menubar",Coordinate(0,0,640,16),menuElements), EventProperties.MOUSE);
		foreach(WindowElement we; labels){
			addElement(we, 0);
		}
		foreach(WindowElement we; elements){
			we.draw();
		}
	}

	public override StyleSheet getStyleSheet(){
		return defaultStyle;
	}

	public void addElement(WindowElement we, int eventProperties){
		elements ~= we;
		we.elementContainer = this;
		we.al ~= this;
		if((eventProperties & EventProperties.KEYBOARD) == EventProperties.KEYBOARD){
			keyboardC ~= we;
		}
		if((eventProperties & EventProperties.MOUSE) == EventProperties.MOUSE){
			mouseC ~= we;
		}
		if((eventProperties & EventProperties.SCROLL) == EventProperties.SCROLL){
			scrollC ~= we;
		}
	}

	
	public void actionEvent(Event event){
		switch(event.source){
			case "exit":
				ie.onExit;
				break;
			case "new":
				ie.newDocument;
				break;
			case "newL":
				ie.newLayer;
				break;
			case "xmpTool":
				ie.xmpToolkit();
				break;
			case "about":
				Window w = new AboutWindow();
				addWindow(w);
				w.relMove(30,30);
				break;
			default:
				ie.passActionEvent(event);
				break;
		}
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	/*public Bitmap16Bit[wchar] getFontSet(int style){
		switch(style){
			case 0: return basicFont;
			case 1: return altFont;
			case 3: return alarmFont;
			default: break;
		}
		return basicFont;
		
	}*/
	/*public Bitmap16Bit getStyleBrush(int style){
		return styleBrush[style];
	}*/
	public override void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}
	
	override public void passMouseEvent(int x,int y,int state,ubyte button) {
		foreach(WindowElement e; mouseC){
			if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
				e.onClick(x - e.getPosition().left, y - e.getPosition().top, state, button);
				return;
			}
		}
	}
	public override void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; scrollC){
			if(e.getPosition().left < wX && e.getPosition().right > wX && e.getPosition().top < wX && e.getPosition().bottom > wY){
				
				e.onScroll(y, x, wX, wY);

				return;
			}
		}
	}
	public Coordinate getAbsolutePosition(WindowElement sender){
		return sender.position;
	}
}

public class Editor : InputListener, MouseListener, IEditor, ActionListener, SystemEventListener, NewLayerDialogListener{
	public OutputScreen[] ow;
	public Raster[] rasters;
	public InputHandler input;
	public TileLayer[int] backgroundLayers;
	//public TileLayer8Bit[int] backgroundLayers8;
	//public TileLayer32Bit[int] backgroundLayers32;
	public Layer[int] layers;
	public wchar selectedTile;
	public int selectedLayer;
	public SpriteLayer windowing;
	public SpriteLayer bitmapPreview;
	public bool onexit, exitDialog, newLayerDialog, mouseState;
	public WindowElement[] elements;
	public Window test;
	public EditorWindowHandler wh;
	public ExtendibleMap document;
	public EffectLayer selectionLayer;
	//public ForceFeedbackHandler ffb;
	private uint[5] framecounter;
	public char[40] windowTitle;
	public ConfigurationProfile configFile;
	private int mouseX, mouseY, activeLayer;
	private Coordinate selection, selectedTiles;

	public void mouseButtonEvent(Uint32 which, Uint32 timestamp, Uint32 windowID, Uint8 button, Uint8 state, Uint8 clicks, Sint32 x, Sint32 y){
		//writeln(windowID);
		x /= 2;
		y /= 2;
		if(windowID == 2){
			if(button == MouseButton.LEFT){
				if(state == ButtonState.PRESSED && !mouseState){
					mouseX = x;
					mouseY = y;
					mouseState = true;
				}else if(mouseState){
					if(mouseX == x && mouseY == y){//placement
					
					}else{		//select
					
					}
				}
			}
		}
	}
	public void mouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y, int wX, int wY){}
	public void mouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){}
	public void keyPressed(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){
		switch(ID){
			case "nextLayer":
				break;
			case "prevLayer":
				break;
			case "scrollUp":
				break;
			case "scrollDown":
				break;
			case "scrollLeft":
				break;
			case "scrollRight":
				break;
			case "quit":
				break;
			case "xmpTool":
				break;
			case "load":
				break;
			case "save":
				break;
			case "saveAs":
				break;
			default:
				break;
		}
	}
	public void keyReleased(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){}
	public void passActionEvent(Event e){
		switch(e.source){
			case "saveas": 
				FileDialog fd = new FileDialog("Save document as","docSave",this,[FileDialog.FileAssociationDescriptor("PPE map file", ["*.map"])],".\\",true);
				wh.addWindow(fd);
				break;
			case "load":
				FileDialog fd = new FileDialog("Load document","docLoad",this,[FileDialog.FileAssociationDescriptor("PPE map file", ["*.map"])],".\\",false);
				wh.addWindow(fd);
				break;
			default: break;
		}
	}
	/*public void actionEvent(string source, int type, int value, wstring message){
		writeln(source);

		if(source == "file"){
			writeln(message);
		}
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){
		switch(subSource){
			case "exitdialog":
				if(source == "Yes"){
					onexit = true;
				}
				break;
			default: break;
		}
	}*/
	public void actionEvent(Event event){
		//writeln(event.subsource);
		switch(event.subsource){
			case "exitdialog":
				if(event.source == "ok"){
					onexit = true;
				}
				break;
			case FileDialog.subsourceID:
				switch(event.source){
					case "docSave":
						break;
					case "docLoad":
						string path = event.path;
						path ~= event.filename;
						document = new ExtendibleMap(path);
						break;
					default: break;
				}
				break;
			default:
				break;
		}
	}
	public void onQuit(){onexit = !onexit;}
	public void controllerRemoved(uint ID){}
	public void controllerAdded(uint ID){}
	public void xmpToolkit(){
		wh.addWindow(new ConverterDialog(input,bitmapPreview));
	}
	public void placeObject(int x, int y){
		if(backgroundLayers.get(selectedLayer, null) !is null){
			int sX = backgroundLayers[selectedLayer].getSX(), sY = backgroundLayers[selectedLayer].getSY();
			sX += x;
			sY += y;
			sX /= backgroundLayers[selectedLayer].getTileWidth();
			sY /= backgroundLayers[selectedLayer].getTileHeight();
			if(sX >= 0 && sY >= 0){
				backgroundLayers[selectedLayer].writeMapping(sX, sY, selectedTile);
			}
		}
	}
	public this(string[] args){
		ConfigurationProfile.setVaultPath("ZILtoid1991","PixelPerfectEditor");
		configFile = new ConfigurationProfile();

		windowing = new SpriteLayer(LayerRenderingMode.ALPHA_BLENDING);
		bitmapPreview = new SpriteLayer();

		wh = new EditorWindowHandler(1280,960,640,480,windowing);
		wh.ie = this;

		//Initialize the Concrete framework
		INIT_CONCRETE(wh);
		

		wh.initGUI();

		input = new InputHandler();
		input.ml ~= this;
		input.ml ~= wh;
		input.il ~= this;
		input.sel ~= this;
		input.kb ~= KeyBinding(0, SDL_SCANCODE_ESCAPE, 0, "sysesc", Devicetype.KEYBOARD);
		WindowElement.inputHandler = input;
		//wh.ih = input;
		//ffb = new ForceFeedbackHandler(input);

		//OutputWindow.setScalingQuality("2");
		//OutputWindow.setDriver("software");
		ow ~= new OutputScreen("Pixel Perfect Editor", 1280, 960);

		rasters ~= new Raster(640, 480, ow[0]);
		ow[0].setMainRaster(rasters[0]);
		rasters[0].addLayer(windowing, 0);
		rasters[0].addLayer(bitmapPreview, 1);
		//rasters[0].setupPalette(512);
		//loadPaletteFromFile("VDPeditUI0.pal", guiR);
		//load24bitPaletteFromFile("VDPeditUI0.pal", rasters[0]);
		//loadPaletteFromXMP(ssOrigin, "default", rasters[0]);
		//foreach(c ; StyleSheet.defaultpaletteforGUI)
		rasters[0].palette ~= [Color(0x00,0x00,0x00,0x00),Color(0xFF,0xFF,0xFF,0xFF),Color(0xFF,0x34,0x9e,0xff),Color(0xff,0xa2,0xd7,0xff),	
		Color(0xff,0x00,0x2c,0x59),Color(0xff,0x00,0x75,0xe7),Color(0xff,0xff,0x00,0x00),Color(0xFF,0x7F,0x00,0x00),
		Color(0xFF,0x00,0xFF,0x00),Color(0xFF,0x00,0x7F,0x00),Color(0xFF,0x00,0x00,0xFF),Color(0xFF,0x00,0x00,0x7F),
		Color(0xFF,0xFF,0xFF,0x00),Color(0xFF,0xFF,0x7F,0x00),Color(0xFF,0x7F,0x7F,0x7F),Color(0xFF,0x00,0x00,0x00)];// StyleSheet.defaultpaletteforGUI;
		//writeln(rasters[0].palette);
		//rasters[0].addRefreshListener(ow[0],0);

	}
	

	

	public void whereTheMagicHappens(){
		while(!onexit){
			input.test();

			rasters[0].refresh();
			if(rasters.length == 2){
				rasters[1].refresh();
			}
			//rudamentaryFrameCounter();
			//onexit = true;
		}
		configFile.store();
	}
	public void onExit(){

		exitDialog=true;
		DefaultDialog dd = new DefaultDialog(Coordinate(10,10,220,75), "exitdialog","Exit application", ["Are you sure?"],["Yes","No","Pls save"],["ok","close","save"]);

		dd.al ~= this;
		wh.addWindow(dd);

	}
	public void newDocument(){
		NewDocumentDialog ndd = new NewDocumentDialog(input);
		ndd.ie = this;
		wh.addWindow(ndd);
	}
	public void createNewDocument(wstring name, int rX, int rY, int pal){
		ow ~= new OutputScreen("Edit window", to!ushort(rX*2),to!ushort(rY*2));
		rasters ~= new Raster(to!ushort(rX), to!ushort(rY), ow[1]);
		rasters[1].setupPalette(pal);
		ow[1].setMainRaster(rasters[1]);
		selectionLayer = new EffectLayer();
		rasters[1].addLayer(selectionLayer, 65536);
		document = new ExtendibleMap();
		document.metaData["name"] = to!string(name);
		document.metaData["rX"] = to!string(rX);
		document.metaData["rY"] = to!string(rY);
		document.metaData["pal"] = to!string(pal);
	}
	public void createNewLayer(string name, int type, int tX, int tY, int mX, int mY, int priority){
		switch(type){
			case 1:
				TileLayerData md = new TileLayerData(tX,tY,mX,mY,1,1,document.getNumOfLayers(), name);
				document.addTileLayer(md);
				TileLayer t = new TileLayer(tX, tY);
				t.loadMapping(mX,mY,md.mapping.getCharMapping(),md.mapping.getAttribMapping());
				backgroundLayers[priority] = t;
				rasters[1].addLayer(t, priority);
				break;
			
			default: break;
		}
	}
	public void newLayer(){
		if(document !is null){
			NewLayerDialog ndd = new NewLayerDialog(this);
			wh.addWindow(ndd);
		}
	}
	private void updateLayerList(){

	}
	public void newTileLayerEvent(string name, string file, bool embed, bool preexisting, int tX, int tY, int mX, int mY){
		TileLayer tl = new TileLayer(tX, tY, LayerRenderingMode.ALPHA_BLENDING);
		int pri = activeLayer;
		TileLayerData tld;
		if(layers.get(activeLayer, null)){
			pri++;
		}
		if(preexisting){
			
		}else{
			tld = new TileLayerData(tX, tY, mX, mY, 1.0, 1.0, pri, name);
		}
		tld.isEmbedded = embed;
		tl.loadMapping(mX,mY,tld.mapping.getCharMapping(),tld.mapping.getAttribMapping());
		layers[pri] = tl;
	}
	public void newSpriteLayerEvent(string name){
	
	}
	public void importTileLayerSymbolData(string file){
	
	}
}