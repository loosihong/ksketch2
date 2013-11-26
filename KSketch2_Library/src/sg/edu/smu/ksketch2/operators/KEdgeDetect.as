package sg.edu.smu.ksketch2.operators
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.Shape;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.filters.ColorMatrixFilter;
	import flash.filters.ConvolutionFilter;
	import flash.geom.Point;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.utils.ByteArray;
	
	
	public class KEdgeDetect extends EventDispatcher
	{
		private const ONEEIGHTHPI:Number = Math.PI/8;
		private const THREEEIGHTHPI:Number = 3*ONEEIGHTHPI;
		private const FIVEEIGHTHPI:Number = 5*ONEEIGHTHPI;
		private const SEVENEIGTHPI:Number = 7*ONEEIGHTHPI;		
		private const IMGFILTER:FileFilter = new FileFilter("Image Format: (*.gif, *.jpeg, *.jpg, *.png)",
			"*gif;*.jpg;*.jpeg;*.png;");
		
		private var _imgFileWin:FileReference = null;
		private var _preProBD:BitmapData = null;
		private var _imgWidth:uint = 0;
		private var _imgHeight:uint = 0;
		private var _xGradArr:Array = null;
		private var _yGradArr:Array = null;
		private var _gradArr:Array = null;
		private var _gradBA:ByteArray = null;
		private var _gradBD:BitmapData = null;
		private var _hysteresisBD:BitmapData = null;
		private var _hysteresisImg:Bitmap = null;
		private var _upperThres:uint = 0;
		private var _lowerThres:uint = 0;
		
		private static var _enterFrameDispatcher:Shape = new Shape();
		private const MAXCOUNT:uint = 10000000;
		private var _savedX:uint = 0;
		private var _savedY:uint = 0;
		
		
		public function KEdgeDetect(highThres:uint, lowThres:uint):void
		{
			SetThresholdValue(highThres, lowThres);
		}
		
		public function get HysteresisBitmapData():BitmapData
		{
			return _hysteresisBD;
		}
		
		public function get HysteresisImage():Bitmap
		{
			return _hysteresisImg;
		}
		
		public function get ImageWidth():uint
		{			
			return _imgWidth;
		}
		
		public function get ImageHeight():uint
		{			
			return _imgHeight;
		}
		
		public function get PreProcessBitmapData():BitmapData
		{
			return _preProBD;
		}
		
		
		public function SetThresholdValue(newHigh:uint, newLow:uint):Boolean
		{
			if((newLow > newHigh) || (newHigh > 255))
			{
				return false;
			}
			
			_upperThres = newHigh;
			_lowerThres = newLow;
			
			return true;
		}
		
		
		public function StartDoubleThreshold():void
		{
			_savedX = _savedY = 0;
			_enterFrameDispatcher.addEventListener(Event.ENTER_FRAME, _DoubleThreshold, false, 0, true);
			_hysteresisBD = _gradBD.clone();
			_hysteresisImg = new Bitmap(_hysteresisBD);
			_hysteresisBD.lock();
			_DoubleThreshold(null);
		}
		
		
		public function SelectImageFile():void
		{
			_imgFileWin = new FileReference();
			_imgFileWin.addEventListener(Event.SELECT, _HandleImgSelect);
			_imgFileWin.browse([IMGFILTER]);
		}
		
		
		private function _HandleImgSelect(evt:Event):void
		{
			_imgFileWin.removeEventListener(Event.SELECT, _HandleImgSelect);
			_imgFileWin.addEventListener(Event.COMPLETE, _HandleLoadBinComplete);
			_imgFileWin.load();
		}
		
		
		private function _HandleLoadBinComplete(evt:Event):void
		{
			_imgFileWin.removeEventListener(Event.COMPLETE, _HandleLoadBinComplete);
			
			//Start loading image data
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, _HandleLoadPreImgComplete);
			loader.loadBytes(_imgFileWin.data);
		}
		
		
		
		private function _HandleLoadPreImgComplete(evt:Event):void
		{
			//Retrieve original image
			var loaderInfo:LoaderInfo = (evt.target as LoaderInfo);
			loaderInfo.removeEventListener(Event.COMPLETE, _HandleLoadPreImgComplete);
			_preProBD = Bitmap(loaderInfo.content).bitmapData;
			_imgWidth = _preProBD.rect.width;
			_imgHeight = _preProBD.rect.height;
			_imgFileWin = null;
			this.dispatchEvent(new Event("KEDLoaded"));
			
			//Get gradient map
			_ApplyGrayscaleFilter();
			_ApplyGaussianFilter();
			_CreateGradStorage();
			
			_savedX = 0;
			_savedY = 0;
			_enterFrameDispatcher.addEventListener(Event.ENTER_FRAME, _ApplyGradFilter, false, 0, true);
			_ApplyGradFilter(null);
		}
		
		
		private function _ApplyGrayscaleFilter():void
		{
			var grayScaleMatrix:Array = [0.333, 0.333, 0.333, 0, 0,
				0.333, 0.333, 0.333, 0, 0,
				0.333, 0.333, 0.333, 0, 0,
				0, 0, 0, 1, 0];
			
			_gradBD = _preProBD.clone();
			_gradBD.applyFilter(_gradBD, _gradBD.rect, new Point(), new ColorMatrixFilter(grayScaleMatrix));
		}
		
		
		private function _ApplyGaussianFilter():void
		{
			var gaussianMatrix:Array = [2, 4, 5, 4, 2,
				4, 9, 12, 9, 4,
				5, 12, 15, 12, 5,
				4, 9, 12, 9, 4,
				2, 4, 5, 4, 2];
			
			//Grayscale
			_gradBD.applyFilter(_gradBD, _gradBD.rect, new Point(), new ConvolutionFilter(5, 5, gaussianMatrix, 159));
		}
		
		
		private function _CreateGradStorage():void
		{
			var i:uint
			
			//Create 2D array for horizontal and vertical gradients
			_xGradArr = new Array(_imgWidth);
			_yGradArr = new Array(_imgWidth);
			
			for(i = 0; i < _imgWidth; i++)
			{
				_xGradArr[i] = new Array(_imgHeight);
			}
			
			for(i = 0; i < _imgWidth; i++)
			{
				_yGradArr[i] = new Array(_imgHeight);
			}
			
			//Create 2D array for gradient map			
			_gradArr = new Array(_imgWidth);
			
			for(i = 0; i < _imgWidth; i++)
			{
				_gradArr[i] = new Array(_imgHeight);
			}
			
			_gradBA = new ByteArray();
		}
		
		
		private function _ApplyGradFilter(evt:Event):void
		{
			var i:uint;
			var j:uint;
			var ctr:uint = 0;
			
			//Sobel Filters
			//Loop through all pixels and retrieve only one of the colour channels			
			for(j = _savedY; j < _imgHeight; j++)			
			{
				for(i = _savedX; i < _imgWidth; i++)
				{
					//Separate iterations into multiple frames
					ctr++;
					
					if(ctr > MAXCOUNT)
					{
						_savedX = i;
						_savedY = j;
						return;
					}
					
					//Apply filters
					//-1 0 1
					//-2 0 2
					//-1 0 1
					_xGradArr[i][j] =
						0 - (_gradBD.getPixel(i - 1, j - 1) & 255)
						- 2*(_gradBD.getPixel(i - 1, j) & 255)
						- (_gradBD.getPixel(i - 1, j + 1) & 255)
						+ (_gradBD.getPixel(i + 1, j - 1) & 255)
						+ 2*(_gradBD.getPixel(i + 1, j) & 255)
						+ (_gradBD.getPixel(i + 1, j + 1) & 255);
					
					//1 2 1
					//0 0 0
					//-1 -2 -1
					_yGradArr[i][j] =
						(_gradBD.getPixel(i - 1, j - 1) & 255)
						+ 2*(_gradBD.getPixel(i, j - 1) & 255)
						+ (_gradBD.getPixel(i + 1, j - 1) & 255)
						- (_gradBD.getPixel(i - 1, j + 1) & 255)
						- 2*(_gradBD.getPixel(i, j + 1) & 255)
						- (_gradBD.getPixel(i + 1, j + 1) & 255);
				}				
			}
			
			_enterFrameDispatcher.removeEventListener(Event.ENTER_FRAME, _ApplyGradFilter);
			_savedX = _savedY = 0;
			_enterFrameDispatcher.addEventListener(Event.ENTER_FRAME, _ComputeGrad, false, 0, true);
			_ComputeGrad(null);
		}
		
		
		private function _ComputeGrad(evt:Event):void
		{
			//Compute magnitude
			var xGrad:Number;
			var yGrad:Number;
			var grad:Number;
			var i:uint;
			var j:uint;
			var ctr:uint = 0;
			
			//Loop through all pixels
			for(j = _savedY; j < _imgHeight; j++)
			{
				for(i =_savedX; i < _imgWidth; i++)
				{
					//Separate iterations into multiple frames
					ctr++;
					
					if(ctr > MAXCOUNT)
					{
						_savedX = i;
						_savedY = j;
						return;
					}
					
					//Begin calculation
					xGrad = _xGradArr[i][j];
					yGrad = _yGradArr[i][j];
					grad = Math.sqrt(xGrad*xGrad + yGrad*yGrad);
					_gradArr[i][j] = grad;
					
					//Limit max gradient to 255 which is the value for total white
					if(grad > 255)
					{					
						grad = 255
					}
					
					_gradBA.writeByte(255);
					_gradBA.writeByte(grad);
					_gradBA.writeByte(grad);
					_gradBA.writeByte(grad);
				}
			}
			
			//Graphically display gradient
			_gradBA.position = 0;
			_gradBD.setPixels(_gradBD.rect, _gradBA);
			_SetSidePix(0, _gradBD);
			
			_enterFrameDispatcher.removeEventListener(Event.ENTER_FRAME, _ComputeGrad);
			_gradBA = null;
			_savedX = _savedY = 0;
			_enterFrameDispatcher.addEventListener(Event.ENTER_FRAME, _ComputeGradAngle, false, 0, true);
			_gradBD.lock();
			_ComputeGradAngle(null);
		}
		
		
		private function _SetSidePix(val:uint, bD:BitmapData):void
		{
			var i:uint;
			var j:uint;
			var h:uint = _imgHeight - 1;
			var w:uint = _imgWidth - 1;
			
			for(i = 0; i < _imgWidth; i++)
			{
				bD.setPixel(i, 0, val);
				bD.setPixel(i, h, val);
			}
			
			for(i = 1; i < h; i++)
			{
				bD.setPixel(0, i, val);
				bD.setPixel(w, i, val);
			}
		}
		
		
		private function _ComputeGradAngle(evt:Event):void
		{
			//Compute direction
			var i:uint;
			var j:uint;
			var directionRad:Number;
			var ctr:uint = 0;
			
			//Retrieve data from array
			for(j = _savedY; j < _imgHeight; j++)
			{
				for(i = _savedX; i < _imgWidth; i++)
				{
					//Separate iterations into multiple frames
					ctr++;
					
					if(ctr > MAXCOUNT)
					{
						_savedX = i;
						_savedY = j;
						return;
					}
					
					//Begin calculation
					directionRad = Math.atan2(_yGradArr[i][j], _xGradArr[i][j]);
					
					//Only consider positive semi circle
					if(directionRad < 0)
					{
						directionRad += Math.PI;
					}
					
					//Sort according to direction for suppression
					if((directionRad < ONEEIGHTHPI) || (directionRad >= SEVENEIGTHPI))
					{
						_NonMaxSuppress(i, j, 0);
					}
					else if(directionRad < THREEEIGHTHPI)
					{
						_NonMaxSuppress(i, j, 1);
					}
					else if(directionRad < FIVEEIGHTHPI)
					{
						_NonMaxSuppress(i, j, 2);
					}
					else
					{
						_NonMaxSuppress(i, j, 3);
					}
				}
			}
			
			_gradBD.unlock();
			_enterFrameDispatcher.removeEventListener(Event.ENTER_FRAME, _ComputeGradAngle);
			_xGradArr = null;
			_yGradArr = null;
			_gradArr = null;
			StartDoubleThreshold();
		}
		
		
		private function _NonMaxSuppress(x:uint, y:uint, code:uint):void
		{
			//Pixel values according to code
			var mainPixVal:int = _GetGradArrVal(x, y);
			var firstPixVal:int;
			var secondPixVal:int;
			
			if(code == 0)
			{
				//Code 0 - Retrieve west and east pixel value
				firstPixVal = _GetGradArrVal(x - 1, y);
				secondPixVal = _GetGradArrVal(x + 1, y);
			}
			else if(code == 1)
			{
				//Code 1 - Retrieve northeast and southwest pixel value
				firstPixVal = _GetGradArrVal(x + 1, y - 1);
				secondPixVal = _GetGradArrVal(x - 1, y + 1);
			}
			else if(code == 2)
			{
				//Code 2 - Retrieve north and south pixel value
				firstPixVal = _GetGradArrVal(x, y + 1);
				secondPixVal = _GetGradArrVal(x, y - 1);
			}
			else if(code == 3)
			{
				//Code 3 - Retrieve northwest and southeast pixel value
				firstPixVal = _GetGradArrVal(x - 1, y - 1);
				secondPixVal = _GetGradArrVal(x + 1, y + 1);
			}
			
			//Suppress pixel value if not local maximum
			if((firstPixVal > mainPixVal) || (secondPixVal > mainPixVal))
			{
				_gradBD.setPixel(x, y, 0);
			}
		}
		
		
		private function _GetGradArrVal(x:uint, y:uint):int
		{
			if((x >= _imgWidth) || (y >= _imgHeight))
			{
				return 0;
			}
			
			return _gradArr[x][y];
		}
		
		
		private function _DoubleThreshold(evt:Event):void
		{			
			var intensity:uint;
			var i:uint;
			var j:uint;
			var ctr:uint = 0;
			
			for(j = _savedY; j < _imgHeight; j++)
			{
				for(i = _savedX; i < _imgWidth; i++)
				{
					//Separate iterations into multiple frames
					ctr++;
					
					if(ctr > MAXCOUNT)
					{
						_savedX = i;
						_savedY = j;
						return;
					}
					
					//Classify edges
					intensity = _hysteresisBD.getPixel(i, j) & 255;
					
					if(intensity > _upperThres)
					{
						_hysteresisBD.setPixel(i, j, 0xFFFFFF);
					}
					else if(intensity > _lowerThres)
					{
						_hysteresisBD.setPixel(i, j, 0x0000FF);
					}
					else
					{
						_hysteresisBD.setPixel(i, j, 0);
					}
				}
			}
			
			_enterFrameDispatcher.removeEventListener(Event.ENTER_FRAME, _DoubleThreshold);
			_savedX = _savedY = 0;
			_enterFrameDispatcher.addEventListener(Event.ENTER_FRAME, _Hysteresis, false, 0, true);
			_Hysteresis(null);
		}
		
		
		private function _Hysteresis(evt:Event):void
		{
			var i:uint;
			var j:uint;
			var repeat:Boolean = true;
			var ctr:uint = 0;
			
			while(repeat)
			{
				repeat = false;
				
				//Loop through all pixels
				for(j = _savedY; j < _imgHeight; j++)
				{
					for(i = _savedX; i < _imgWidth; i++)
					{
						//Separate iterations into multiple frames
						ctr++;
						
						if(ctr > MAXCOUNT)
						{
							_savedX = i;
							_savedY = j;
							return;
						}
						
						//Found weak edge
						if(_hysteresisBD.getPixel(i, j) == 0x0000FF)
						{
							//Connnected to a strong edge
							if((_hysteresisBD.getPixel((i - 1), (j - 1)) == 0xFFFFFF) ||
								(_hysteresisBD.getPixel(i, (j - 1)) == 0xFFFFFF) ||
								(_hysteresisBD.getPixel((i + 1), (j - 1)) == 0xFFFFFF) ||
								(_hysteresisBD.getPixel((i - 1), j) == 0xFFFFFF) ||
								(_hysteresisBD.getPixel((i + 1), j ) == 0xFFFFFF) ||
								(_hysteresisBD.getPixel((i - 1), (j + 1)) == 0xFFFFFF) ||
								(_hysteresisBD.getPixel(i, (j + 1)) == 0xFFFFFF) ||
								(_hysteresisBD.getPixel((i + 1), (j + 1)) == 0xFFFFFF))
							{
								//Set as edge
								_hysteresisBD.setPixel(i, j, 0xFFFFFF);
								repeat = true;
							}
						}
					}
				}
			}
			
			_enterFrameDispatcher.removeEventListener(Event.ENTER_FRAME, _Hysteresis);
			_savedX = _savedY = 0;
			_enterFrameDispatcher.addEventListener(Event.ENTER_FRAME, _ClearWeakEdge, false, 0, true);
			_ClearWeakEdge(null);
		}
		
		private function _ClearWeakEdge(evt:Event):void
		{
			var i:uint;
			var j:uint;
			var ctr:uint = 0;
			
			for(j = _savedY; j < _imgHeight; j++)
			{
				for(i = _savedX; i < _imgWidth; i++)
				{
					//Separate iterations into multiple frames
					ctr++;
					
					if(ctr > MAXCOUNT)
					{
						_savedX = i;
						_savedY = j;
						return;
					}
					
					//Found weak edge
					if(_hysteresisBD.getPixel(i, j) == 0x0000FF)
					{
						//Remove
						_hysteresisBD.setPixel(i, j, 0);
					}
				}
			}
			
			_enterFrameDispatcher.removeEventListener(Event.ENTER_FRAME, _ClearWeakEdge);
			_SetSidePix(0xFFFFFF, _hysteresisBD);
			_hysteresisBD.unlock();
			this.dispatchEvent(new Event("KEDHysteresis"));
		}
	}
}