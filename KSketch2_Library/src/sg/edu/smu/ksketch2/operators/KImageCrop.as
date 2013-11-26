package sg.edu.smu.ksketch2.operators
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import spark.core.SpriteVisualElement;

	public class KImageCrop
	{
		private var _imgSpace:SpriteVisualElement = null;
		private var _imgBD:BitmapData = null;
		private var _imgSprite:Sprite = null;
		private var _imgWidth:uint = 0;
		private var _imgHeight:uint = 0;
		private var _edgeBD:BitmapData = null;
		private var _cropMode:uint = 0;
		private var _prevCropBD:BitmapData = null;
		private var _cropBD:BitmapData = null;
		private var _cropImg:Bitmap = null;
		
		private var _snapSprite:Sprite = null;
		private var _snapBD:BitmapData = null;
		private var _snapStrength:uint = 0;
		private var _snapPtArr:Array = null;
		private var _endSnapX:uint = 0;
		private var _endSnapY:uint = 0;
		private var _ignoreStart:Boolean = false;
		
		private var _edgeTraceBD:BitmapData = null;
		
		private static var _enterFrameDispatcher:Shape = new Shape();
		private const MAXCOUNT:uint = 10000000;
		private var _savedX:uint = 0;
		private var _savedY:uint = 0;
		private var _savedMov:uint = 0;
		
		public function KImageCrop(space:SpriteVisualElement):void
		{
			_imgSpace = space;
		}
		
		public function get CropImage():Bitmap
		{
			return _cropImg;
		}
		
		public function set CropMode(value:uint):void
		{
			if(_imgSprite != null)
			{
				switch(_cropMode)
				{
				case 0:
					EndSnapCrop();
					break;
				case 1:
					_imgSprite.removeEventListener(MouseEvent.CLICK, _HandleEdgeTraceCrop);
					_edgeTraceBD = null;
					break;
				case 2:
					_imgSprite.removeEventListener(MouseEvent.MOUSE_MOVE, _HandleVerSprCrop);
					_imgSprite.removeEventListener(MouseEvent.MOUSE_DOWN, _HandleSprSave);
					_HandleSprSave(null);
					break;
				case 3:
					_imgSprite.removeEventListener(MouseEvent.MOUSE_MOVE, _HandleHorSprCrop);
					_imgSprite.removeEventListener(MouseEvent.MOUSE_DOWN, _HandleSprSave);
					_HandleSprSave(null);
					break;
				}
				
				switch(value)
				{
					case 0:
						NewSnapCrop();
						break;
					case 1:
						_imgSprite.addEventListener(MouseEvent.CLICK, _HandleEdgeTraceCrop);
						break;
					case 2:
						_imgSprite.addEventListener(MouseEvent.MOUSE_MOVE, _HandleVerSprCrop);
						_imgSprite.addEventListener(MouseEvent.MOUSE_DOWN, _HandleSprSave);
						_HandleSprSave(null);
						break;
					case 3:
						_imgSprite.addEventListener(MouseEvent.MOUSE_MOVE, _HandleHorSprCrop);
						_imgSprite.addEventListener(MouseEvent.MOUSE_DOWN, _HandleSprSave);
						_HandleSprSave(null);
						break;
				}
			}
			
			if(value < 4)
			{
				_cropMode = value;
			}
		}
		
		public function set EdgeBitmapData(value:BitmapData):void
		{
			_edgeBD = value;
		}
		
		public function set ImageBitmapData(value:BitmapData):void
		{
			_imgBD = value;
			
			//Remove previous sprites
			if(_imgSprite != null)
			{
				_imgSpace.removeChild(_imgSprite);
			}
			
			//Add primary sprite
			if(_imgBD != null)
			{
				_imgWidth = _imgBD.rect.width;
				_imgHeight = _imgBD.rect.height;
				_prevCropBD = _cropBD = new BitmapData(_imgWidth, _imgHeight, true, 0);
				_cropImg = new Bitmap(_cropBD);
				
				_imgSprite = new Sprite();
				_imgSprite.addChild(new Bitmap(_imgBD));
				_imgSpace.addChild(_imgSprite);
				_imgSpace.width = _imgWidth
				_imgSpace.height = _imgHeight		
			}
			else
			{
				_imgWidth = 0;
				_imgHeight = 0;
				_prevCropBD = _cropBD = null;
				_cropImg = null;
				_imgSprite = null;
			}
		}
		
		public function set SnapStrength(value:uint):void
		{
			_snapStrength = value;
		}
		
		public function NewSnapCrop():void
		{
			_snapSprite = new Sprite();
			_snapSprite.graphics.beginFill(0, 0);
			_snapSprite.graphics.drawRect(0, 0, _imgWidth, _imgHeight);
			_snapSprite.graphics.endFill();
			_snapSprite.graphics.lineStyle(0, 0x00FF00, 1);
			_imgSpace.addChild(_snapSprite);
			_snapSprite.addEventListener(MouseEvent.MOUSE_DOWN, _ContSnapCrop);
		}
		
		
		public function ActivateSnapCrop():void
		{
			_snapSprite.removeEventListener(MouseEvent.MOUSE_DOWN, _ContSnapCrop);
			
			if(_snapPtArr.length > 2)
			{
				var i:uint;
				var j:uint;
				
				_snapSprite.graphics.lineTo(_snapPtArr[0].x, _snapPtArr[0].y);
				_snapBD = new BitmapData(_imgWidth, _imgHeight);
				_snapBD.draw(_snapSprite);
				
				for(i = 0; i < _imgWidth; i++)
				{
					for(j = 0; j < _imgHeight; j++)
					{
						if(_snapBD.getPixel(i, j) == 0xFFFFFF)
						{
							_snapBD.setPixel32(i, j, 0xFF000000);
						}
						else
						{
							_snapBD.setPixel32(i, j, 0xFFFFFFFF);
						}
					}
				}
				
				//Get leftmost point
				var x:uint = _snapPtArr[0].x;
				var y:uint;
				j = 0;
				
				for(i = 1; i < _snapPtArr.length; i++)
				{
					if(_snapPtArr[i].x < x)
					{
						x = _snapPtArr[i].x;
						j = i;
					}
				}
				
				if((j > 0) && (j < (_snapPtArr.length - 1)))
				{
					x = (_snapPtArr[j-1].x + _snapPtArr[j+1].x + _snapPtArr[j].x)/3;
					y = (_snapPtArr[j-1].y + _snapPtArr[j+1].y + _snapPtArr[j].y)/3;
				}
				else if(j == 0)
				{
					x = (_snapPtArr[_snapPtArr.length-1].x + _snapPtArr[1].x + _snapPtArr[0].x)/3;
					y = (_snapPtArr[_snapPtArr.length-1].y + _snapPtArr[1].y + _snapPtArr[0].y)/3;
				}
				else
				{
					x = (_snapPtArr[_snapPtArr.length-2].x + _snapPtArr[0].x + _snapPtArr[_snapPtArr.length-1].x)/3;
					y = (_snapPtArr[_snapPtArr.length-2].y + _snapPtArr[0].y + _snapPtArr[_snapPtArr.length-1].y)/3;
				}
				
				//Set side pixel become edge
				var h:uint = _imgHeight - 1;
				var w:uint = _imgWidth - 1;
				
				for(i = 0; i < _imgWidth; i++)
				{
					_snapBD.setPixel(i, 0, 0xFFFFFF);
					_snapBD.setPixel(i, h, 0xFFFFFF);
				}
				
				for(i = 1; i < h; i++)
				{
					_snapBD.setPixel(0, i, 0xFFFFFF);
					_snapBD.setPixel(w, i, 0xFFFFFF);
				}
				
				_SaveCropImg();
				_cropBD.lock();
				_PreSnapCrop(x, y);
				_cropBD.unlock();
			}
		}
		
		
		public function EndSnapCrop():void
		{
			if(_snapSprite != null)
			{
				_imgSpace.removeChild(_snapSprite);
				_snapSprite = null;
				_snapBD = null;
				_snapPtArr = null;
			}
		}
		
		
		public function Undo():void
		{
			//Do deep copy of prevCropBD
			if(_prevCropBD != null)
			{
				_cropBD.copyPixels(_prevCropBD, _prevCropBD.rect, new Point(0, 0));
			}
		}
		
		
		public function GetFinalImageData():BitmapData
		{
			//Trim final crop image
			if(_cropBD == null)
			{
				return null;
			}
			
			return _TrimImage();
		}
		
		
		private function _SaveCropImg():void
		{
			//Store previous image
			_prevCropBD = _cropBD.clone();
			
			//Create new image when first started
			if(_cropBD == null)
			{
				_cropBD = new BitmapData(_imgWidth, _imgHeight, true, 0);
			}
		}
		
		
		private function _HandleEdgeTraceCrop(evt:MouseEvent):void
		{
			var x:uint = evt.localX;
			var y:uint = evt.localY;
			
			//Go to leftmost edge of the point
			while(_edgeBD.getPixel(x, y) != 0xFFFFFF)
			{
				x--;
			}
			
			//Start cropping
			_edgeTraceBD = _edgeBD.clone();				
			_SaveCropImg();
			_cropBD.lock();
			_EdgeCrop(x, y, 4);
			_cropBD.unlock();
		}
		
		
		private function _EdgeCrop(startX:uint, startY:uint, direction:uint):void
		{
			//Record starting point
			var x:uint = startX;
			var y:uint = startY;
			var prevX:uint = startX;
			var prevY:uint = startY;
			var sidePixel:uint;
			var prevMov:uint = direction;
			var nxtMov:uint = 8;
			var endMov:uint;
			var endX:uint;
			var endY:uint;
			var edgeArr:Array = new Array();
			var singleEdge:Boolean = false;
			
			//Determine end conditions
			//Hit from left
			if(direction == 0)
			{
				if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
				{
					x--;
					y++;
					endMov = 5;
				}
				else if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
				{
					y++;
					endMov = 6;
				}
				else if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
				{
					x++;
					y++;
					endMov = 7;
				}
				else if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
				{
					x++;
					endMov = 0;
				}
				else if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
				{
					x++;
					y--;
					endMov = 1;
				}
				else if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
				{
					y--;
					endMov = 2;
				}
				else if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
				{
					x--;
					y--;
					endMov = 3;
				}
				else if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
				{
					x--;
					endMov = 4;
				}
				else
				{
					singleEdge = true;
				}
			}
			//Hit from right
			else if(direction == 4)
			{
				if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
				{
					x++;
					y--;
					endMov = 1;
				}
				else if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
				{
					y--;
					endMov = 2;
				}
				else if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
				{
					x--;
					y--;
					endMov = 3;
				}
				else if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
				{
					x--;
					endMov = 4;
				}
				else if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
				{
					x--;
					y++;
					endMov = 5;
				}
				else if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
				{
					y++;
					endMov = 6;
				}
				else if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
				{
					x++;
					y++;
					endMov = 7;
				}
				else if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
				{
					x++;
					endMov = 0;
				}
				else
				{
					singleEdge = true;
				}
			}
			
			endX = x;
			endY = y;
			prevMov = endMov;
			
			//Deal with single edge not connected to other edge
			if(singleEdge)
			{
				_cropBD.setPixel32(startX, startY, _imgBD.getPixel32(startX, startY));
				_edgeTraceBD.setPixel(startX, startY, 0);
				sidePixel = startX + 1;
				
				//Only print if it is not printed yet
				if(_cropBD.getPixel32(sidePixel, startY) == 0)
				{
					//Do not print pixel at the right edge
					while(_edgeBD.getPixel(sidePixel, startY) != 0xFFFFFF)
					{
						_cropBD.setPixel32(sidePixel, startY, _imgBD.getPixel32(sidePixel, startY));
						sidePixel++;
					}
					
					//Store unvisited right edge for analysis later
					if(_edgeTraceBD.getPixel(sidePixel, startY) == 0xFFFFFF)
					{
						edgeArr.push(sidePixel);
						edgeArr.push(startY);
					}
				}
			}
			//Deal with edges connected to at least one other edge
			else
			{				
				//Check every continuous edge until back to original position
				while((x != endX) || (y != endY) || (nxtMov != endMov))
				{
					//Print current edge
					prevX = x;
					prevY = y;
					
					_cropBD.setPixel32(x, y, _imgBD.getPixel32(x, y));
					_edgeTraceBD.setPixel(x, y, 0);
					
					//Determine next edge direction
					//Default direction is pointing E
					//Scan anti-alockwise
					switch(prevMov)
					{
						//From West
						case 0:
							if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
							{
								x--;
								y++;
								nxtMov = 5;
							}
							else if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
							{
								y++;
								nxtMov = 6;
							}
							else if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
							{
								x++;
								y++;
								nxtMov = 7;
							}
							else if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
							{
								x++;
								nxtMov = 0;
							}
							else if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
							{
								x++;
								y--;
								nxtMov = 1;
							}
							else if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
							{
								y--;
								nxtMov = 2;
							}
							else if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
							{
								x--;
								y--;
								nxtMov = 3;
							}
							else if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
							{
								x--;
								nxtMov = 4;
							}
							break;
						
						//From SouthWest
						case 1:
							if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
							{
								y++;
								nxtMov = 6;
							}
							else if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
							{
								x++;
								y++;
								nxtMov = 7;
							}
							else if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
							{
								x++;
								nxtMov = 0;
							}
							else if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
							{
								x++;
								y--;
								nxtMov = 1;
							}
							else if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
							{
								y--;
								nxtMov = 2;
							}
							else if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
							{
								x--;
								y--;
								nxtMov = 3;
							}
							else if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
							{
								x--;
								nxtMov = 4;
							}
							else if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
							{
								x--;
								y++;
								nxtMov = 5;
							}
							break;
						
						//From South
						case 2:
							if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
							{
								x++;
								y++;
								nxtMov = 7;
							}
							else if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
							{
								x++;
								nxtMov = 0;
							}
							else if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
							{
								x++;
								y--;
								nxtMov = 1;
							}
							else if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
							{
								y--;
								nxtMov = 2;
							}
							else if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
							{
								x--;
								y--;
								nxtMov = 3;
							}
							else if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
							{
								x--;
								nxtMov = 4;
							}
							else if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
							{
								x--;
								y++;
								nxtMov = 5;
							}
							else if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
							{
								y++;
								nxtMov = 6;
							}
							break;
						
						//From SouthEast
						case 3:
							if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
							{
								x++;
								nxtMov = 0;
							}
							else if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
							{
								x++;
								y--;
								nxtMov = 1;
							}
							else if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
							{
								y--;
								nxtMov = 2;
							}
							else if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
							{
								x--;
								y--;
								nxtMov = 3;
							}
							else if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
							{
								x--;
								nxtMov = 4;
							}
							else if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
							{
								x--;
								y++;
								nxtMov = 5;
							}
							else if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
							{
								y++;
								nxtMov = 6;
							}
							else if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
							{
								x++;
								y++;
								nxtMov = 7;
							}
							break;
						
						//From East
						case 4:
							if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
							{
								x++;
								y--;
								nxtMov = 1;
							}
							else if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
							{
								y--;
								nxtMov = 2;
							}
							else if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
							{
								x--;
								y--;
								nxtMov = 3;
							}
							else if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
							{
								x--;
								nxtMov = 4;
							}
							else if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
							{
								x--;
								y++;
								nxtMov = 5;
							}
							else if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
							{
								y++;
								nxtMov = 6;
							}
							else if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
							{
								x++;
								y++;
								nxtMov = 7;
							}
							else if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
							{
								x++;
								nxtMov = 0;
							}
							break;
						
						//From NorthEast
						case 5:
							if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
							{
								y--;
								nxtMov = 2;
							}
							else if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
							{
								x--;
								y--;
								nxtMov = 3;
							}
							else if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
							{
								x--;
								nxtMov = 4;
							}
							else if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
							{
								x--;
								y++;
								nxtMov = 5;
							}
							else if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
							{
								y++;
								nxtMov = 6;
							}
							else if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
							{
								x++;
								y++;
								nxtMov = 7;
							}
							else if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
							{
								x++;
								nxtMov = 0;
							}
							else if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
							{
								x++;
								y--;
								nxtMov = 1;
							}
							break;
						
						//From North
						case 6:
							if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
							{
								x--;
								y--;
								nxtMov = 3;
							}
							else if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
							{
								x--;
								nxtMov = 4;
							}
							else if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
							{
								x--;
								y++;
								nxtMov = 5;
							}
							else if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
							{
								y++;
								nxtMov = 6;
							}
							else if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
							{
								x++;
								y++;
								nxtMov = 7;
							}
							else if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
							{
								x++;
								nxtMov = 0;
							}
							else if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
							{
								x++;
								y--;
								nxtMov = 1;
							}
							else if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
							{
								y--;
								nxtMov = 2;
							}
							break;
						
						//From NorthWest
						default:
							if(_edgeBD.getPixel(x-1, y) == 0xFFFFFF)
							{
								x--;
								nxtMov = 4;
							}
							else if(_edgeBD.getPixel(x-1, y+1) == 0xFFFFFF)
							{
								x--;
								y++;
								nxtMov = 5;
							}
							else if(_edgeBD.getPixel(x, y+1) == 0xFFFFFF)
							{
								y++;
								nxtMov = 6;
							}
							else if(_edgeBD.getPixel(x+1, y+1) == 0xFFFFFF)
							{
								x++;
								y++;
								nxtMov = 7;
							}
							else if(_edgeBD.getPixel(x+1, y) == 0xFFFFFF)
							{
								x++;
								nxtMov = 0;
							}
							else if(_edgeBD.getPixel(x+1, y-1) == 0xFFFFFF)
							{
								x++;
								y--;
								nxtMov = 1;
							}
							else if(_edgeBD.getPixel(x, y-1) == 0xFFFFFF)
							{
								y--;
								nxtMov = 2;
							}
							else if(_edgeBD.getPixel(x-1, y-1) == 0xFFFFFF)
							{
								x--;
								y--;
								nxtMov = 3;
							}
							break;
					}
					
					//Determine whether to print right pixels or left pixels
					//Consider printing right when moving up
					if(((nxtMov > 0) && (nxtMov < 4) && (prevMov != 4) && (prevMov != 5)) ||
						((nxtMov > 3) && (nxtMov < 7) && (prevMov > 0) && (prevMov < 4)) ||
						((nxtMov - prevMov) == 4) || ((prevMov - nxtMov) == 4))
					{
						sidePixel = prevX + 1;
						
						//Do not print pixel at the right edge
						while(_edgeBD.getPixel(sidePixel, prevY) != 0xFFFFFF)
						{
							_cropBD.setPixel32(sidePixel, prevY, _imgBD.getPixel32(sidePixel, prevY));
							sidePixel++;
						}
						
						//Store unvisited right edge for analysis later
						if(_edgeTraceBD.getPixel(sidePixel, prevY) == 0xFFFFFF)
						{
							edgeArr.push(sidePixel);
							edgeArr.push(prevY);
						}
					}
					
					//Move onto next edge
					prevMov = nxtMov;
				}
			}
			
			//Loop through all previously hit edge
			while(edgeArr.length > 0)
			{				
				var untouchEdgeArr:Array = new Array();
				
				//Remove edges that have already visited before
				for(var i:uint = 0; i < edgeArr.length; i += 2)
				{
					if(_edgeTraceBD.getPixel(edgeArr[i], edgeArr[i + 1]) == 0xFFFFFF)
					{
						untouchEdgeArr.push(edgeArr[i]);
						untouchEdgeArr.push(edgeArr[i + 1]);
					}
				}
				
				edgeArr = untouchEdgeArr;
				
				//Work on first edge on array
				if(edgeArr.length > 0)
				{
					_EdgeCrop(edgeArr[0], edgeArr[1], 0);
				}
			}
		}
		
		
		private function _HandleVerSprCrop(evt:MouseEvent):void
		{
			if(evt.buttonDown)
			{
				_cropBD.lock();
				_VerSpreadCrop(evt.localX, evt.localY);
				_cropBD.unlock();
			}
		}
		
		
		private function _HandleSprSave(evt:MouseEvent):void
		{
			_SaveCropImg();
		}
		
		
		private function _VerSpreadCrop(x:uint, y:uint):void
		{
			var i:uint;
			var j:uint;
			
			//Spread if not edge
			if(_edgeBD.getPixel32(x, y) != 0xFFFFFFFF)
			{
				//Spread top
				j = y;
				
				while(_edgeBD.getPixel32(x, j) != 0xFFFFFFFF)
				{
					_cropBD.setPixel32(x, j, _imgBD.getPixel32(x, j));
					
					//Spread left
					i = x - 1;
					
					while(_edgeBD.getPixel32(i, j) != 0xFFFFFFFF)
					{
						_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
						i--;
					}
					
					_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
					
					//Spread right
					i = x + 1;
					
					while(_edgeBD.getPixel32(i, j) != 0xFFFFFFFF)
					{
						_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
						i++;
					}
					
					_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));					
					j--;
				}
				
				//Spread bottom
				j = y + 1;
				
				while(_edgeBD.getPixel32(x, j) != 0xFFFFFFFF)
				{
					_cropBD.setPixel32(x, j, _imgBD.getPixel32(x, j));
					
					//Spread left
					i = x - 1;
					
					while(_edgeBD.getPixel32(i, j) != 0xFFFFFFFF)
					{
						_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
						i--;
					}
					
					_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
					
					//Spread right
					i = x + 1;
					
					while(_edgeBD.getPixel32(i, j) != 0xFFFFFFFF)
					{
						_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
						i++;
					}
					
					_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
					j++;
				}
			}
		}
		
		
		private function _HandleHorSprCrop(evt:MouseEvent):void
		{
			if(evt.buttonDown)
			{
				_cropBD.lock();
				_HorSpreadCrop(evt.localX, evt.localY);
				_cropBD.unlock();
			}
		}
		
		
		private function _HorSpreadCrop(x:uint, y:uint):void
		{
			var i:uint;
			var j:uint;
			
			//Spread if not edge
			if(_edgeBD.getPixel32(x, y) != 0xFFFFFFFF)
			{
				//Spread left
				i = x;
				
				while(_edgeBD.getPixel32(i, y) != 0xFFFFFFFF)
				{
					_cropBD.setPixel32(i, y, _imgBD.getPixel32(i, y));
					
					//Spread top
					j = y - 1;
					
					while(_edgeBD.getPixel32(i, j) != 0xFFFFFFFF)
					{
						_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
						j--;
					}
					
					_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
					
					//Spread bottom
					j = y + 1;
					
					while(_edgeBD.getPixel32(i, j) != 0xFFFFFFFF)
					{
						_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
						j++;
					}
					
					_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
					i--;
				}
				
				//Spread right
				i = x + 1;
				
				while(_edgeBD.getPixel32(i, y) != 0xFFFFFFFF)
				{
					_cropBD.setPixel32(i, y, _imgBD.getPixel32(i, y));
					
					//Spread top
					j = y - 1;
					
					while(_edgeBD.getPixel32(i, j) != 0xFFFFFFFF)
					{
						_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
						j--;
					}
					
					_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
					
					//Spread bottom
					j = y + 1;
					
					while(_edgeBD.getPixel32(i, j) != 0xFFFFFFFF)
					{
						_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
						j++;
					}
					
					_cropBD.setPixel32(i, j, _imgBD.getPixel32(i, j));
					i++;
				}
			}
		}
		
		
		
		
		
		private function _ContSnapCrop(evt:MouseEvent):void
		{
			if(_snapPtArr == null)
			{
				_snapPtArr = new Array();	
				_snapSprite.graphics.moveTo(evt.localX, evt.localY);
				_snapPtArr.push(new Point(evt.localX, evt.localY));
			}
			else
			{
				_AddSnapPoint(new MouseEvent(MouseEvent.MOUSE_DOWN, true, false,
					evt.localX, evt.localY, null,false, false, false, true));
			}
			
			_snapSprite.addEventListener(MouseEvent.MOUSE_MOVE, _AddSnapPoint);
			_snapSprite.addEventListener(MouseEvent.MOUSE_UP, _StopSnapCrop);
		}
		
		
		private function _AddSnapPoint(evt:MouseEvent):void
		{
			if(evt.buttonDown)
			{
				var x:uint = evt.localX;
				var y:uint = evt.localY;
				var i:int;
				var found:Boolean = false;
				var spr:uint = 0;
				var limit:int;
				
				while(spr <= _snapStrength)
				{
					//Top
					limit = x + spr;
					
					for(i = x - spr; i <= limit; i++)
					{
						if(_edgeBD.getPixel(i, y - spr) == 0xFFFFFF)
						{
							x = i;
							y -= spr;
							found = true;
							break;
						}
					}
					
					if(found == true)
					{
						break;
					}
					
					//Bottom
					limit = x + spr;
					
					for(i = x - spr; i <= limit; i++)
					{
						if(_edgeBD.getPixel(i, y + spr) == 0xFFFFFF)
						{
							x = i;
							y += spr;
							found = true;
							break;
						}
					}
					
					if(found == true)
					{
						break;
					}
					
					//Left
					limit = y + spr;
					
					for(i = y - spr; i <= limit; i++)
					{
						if(_edgeBD.getPixel(x - spr, i) == 0xFFFFFF)
						{
							x -= spr;
							y = i;
							found = true;
							break;
						}
					}
					
					if(found == true)
					{
						break;
					}
					
					//Right
					limit = y + spr;
					
					for(i = y - spr; i <= limit; i++)
					{
						if(_edgeBD.getPixel(x + spr, i) == 0xFFFFFF)
						{
							x += spr;
							y = i;
							found = true;
							break;
						}
					}
					
					if(found == true)
					{
						break;
					}
					
					spr++;
				}
				
				_snapSprite.graphics.lineTo(x, y);
				_snapPtArr.push(new Point(x, y));
			}
			else
			{
				_StopSnapCrop(null);
			}
		}
		
		
		private function _StopSnapCrop(evt:MouseEvent):void
		{
			_snapSprite.removeEventListener(MouseEvent.MOUSE_MOVE, _AddSnapPoint);
			_snapSprite.removeEventListener(MouseEvent.MOUSE_UP, _StopSnapCrop);
		}
		
		
		private function _PreSnapCrop(x:uint, y:uint):void
		{
			//Go to leftmost edge of the point
			while(_snapBD.getPixel(x, y) != 0xFFFFFF)
			{
				x--;
			}
			
			//Scan for first next move
			if(_snapBD.getPixel(x+1, y-1) == 0xFFFFFF)
			{
				x++;
				y--;
				_savedMov = 1;
			}
			else if(_snapBD.getPixel(x, y-1) == 0xFFFFFF)
			{
				y--;
				_savedMov = 2;
			}
			else if(_snapBD.getPixel(x-1, y-1) == 0xFFFFFF)
			{
				x--;
				y--;
				_savedMov = 3;
			}
			else if(_snapBD.getPixel(x-1, y) == 0xFFFFFF)
			{
				x--;
				_savedMov = 4;
			}
			else if(_snapBD.getPixel(x-1, y+1) == 0xFFFFFF)
			{
				x--;
				y++;
				_savedMov = 5;
			}
			else if(_snapBD.getPixel(x, y+1) == 0xFFFFFF)
			{
				y++;
				_savedMov = 6;
			}
			else if(_snapBD.getPixel(x+1, y+1) == 0xFFFFFF)
			{
				x++;
				y++;
				_savedMov = 7;
			}
			else if(_snapBD.getPixel(x+1, y) == 0xFFFFFF)
			{
				x++;
				_savedMov = 0;
			}
			else
			{
				return;
			}
			
			
			_endSnapX = _savedX = x;
			_endSnapY = _savedY = y;
			_ignoreStart = true;
			_enterFrameDispatcher.addEventListener(Event.ENTER_FRAME, _SnapCrop, false, 0, true);
			_SnapCrop(null);
		}
		
		
		private function _SnapCrop(evt:Event):void
		{
			//Record starting point
			var x:uint = _savedX;
			var y:uint = _savedY;
			var prevX:uint;
			var prevY:uint;
			var sidePixel:uint;
			var prevMov:uint = _savedMov;
			var nxtMov:uint;
			var ctr:uint = 0;
			
			//Check every continuous edge until back to original position
			while((x != _endSnapX) || (y != _endSnapY) || _ignoreStart)
			{
				//Separate iterations into multiple frames
				if(ctr > MAXCOUNT)
				{
					_savedX = x;
					_savedY = y;
					_savedMov = prevMov;
					return;
				}
				
				
				//Print current edge
				_ignoreStart = false;
				prevX = x;
				prevY = y;
				
				_cropBD.setPixel32(x, y, _imgBD.getPixel32(x, y));
				
				//Determine next edge direction
				//Default direction is pointing E
				//Scan anti-alockwise
				switch(prevMov)
				{
					//From West
					case 0:
						if(_snapBD.getPixel(x-1, y+1) == 0xFFFFFF)
						{
							x--;
							y++;
							nxtMov = 5;
						}
						else if(_snapBD.getPixel(x, y+1) == 0xFFFFFF)
						{
							y++;
							nxtMov = 6;
						}
						else if(_snapBD.getPixel(x+1, y+1) == 0xFFFFFF)
						{
							x++;
							y++;
							nxtMov = 7;
						}
						else if(_snapBD.getPixel(x+1, y) == 0xFFFFFF)
						{
							x++;
							nxtMov = 0;
						}
						else if(_snapBD.getPixel(x+1, y-1) == 0xFFFFFF)
						{
							x++;
							y--;
							nxtMov = 1;
						}
						else if(_snapBD.getPixel(x, y-1) == 0xFFFFFF)
						{
							y--;
							nxtMov = 2;
						}
						else if(_snapBD.getPixel(x-1, y-1) == 0xFFFFFF)
						{
							x--;
							y--;
							nxtMov = 3;
						}
						else if(_snapBD.getPixel(x-1, y) == 0xFFFFFF)
						{
							x--;
							nxtMov = 4;
						}
						break;
					
					//From SouthWest
					case 1:
						if(_snapBD.getPixel(x, y+1) == 0xFFFFFF)
						{
							y++;
							nxtMov = 6;
						}
						else if(_snapBD.getPixel(x+1, y+1) == 0xFFFFFF)
						{
							x++;
							y++;
							nxtMov = 7;
						}
						else if(_snapBD.getPixel(x+1, y) == 0xFFFFFF)
						{
							x++;
							nxtMov = 0;
						}
						else if(_snapBD.getPixel(x+1, y-1) == 0xFFFFFF)
						{
							x++;
							y--;
							nxtMov = 1;
						}
						else if(_snapBD.getPixel(x, y-1) == 0xFFFFFF)
						{
							y--;
							nxtMov = 2;
						}
						else if(_snapBD.getPixel(x-1, y-1) == 0xFFFFFF)
						{
							x--;
							y--;
							nxtMov = 3;
						}
						else if(_snapBD.getPixel(x-1, y) == 0xFFFFFF)
						{
							x--;
							nxtMov = 4;
						}
						else if(_snapBD.getPixel(x-1, y+1) == 0xFFFFFF)
						{
							x--;
							y++;
							nxtMov = 5;
						}
						break;
					
					//From South
					case 2:
						if(_snapBD.getPixel(x+1, y+1) == 0xFFFFFF)
						{
							x++;
							y++;
							nxtMov = 7;
						}
						else if(_snapBD.getPixel(x+1, y) == 0xFFFFFF)
						{
							x++;
							nxtMov = 0;
						}
						else if(_snapBD.getPixel(x+1, y-1) == 0xFFFFFF)
						{
							x++;
							y--;
							nxtMov = 1;
						}
						else if(_snapBD.getPixel(x, y-1) == 0xFFFFFF)
						{
							y--;
							nxtMov = 2;
						}
						else if(_snapBD.getPixel(x-1, y-1) == 0xFFFFFF)
						{
							x--;
							y--;
							nxtMov = 3;
						}
						else if(_snapBD.getPixel(x-1, y) == 0xFFFFFF)
						{
							x--;
							nxtMov = 4;
						}
						else if(_snapBD.getPixel(x-1, y+1) == 0xFFFFFF)
						{
							x--;
							y++;
							nxtMov = 5;
						}
						else if(_snapBD.getPixel(x, y+1) == 0xFFFFFF)
						{
							y++;
							nxtMov = 6;
						}
						break;
					
					//From SouthEast
					case 3:
						if(_snapBD.getPixel(x+1, y) == 0xFFFFFF)
						{
							x++;
							nxtMov = 0;
						}
						else if(_snapBD.getPixel(x+1, y-1) == 0xFFFFFF)
						{
							x++;
							y--;
							nxtMov = 1;
						}
						else if(_snapBD.getPixel(x, y-1) == 0xFFFFFF)
						{
							y--;
							nxtMov = 2;
						}
						else if(_snapBD.getPixel(x-1, y-1) == 0xFFFFFF)
						{
							x--;
							y--;
							nxtMov = 3;
						}
						else if(_snapBD.getPixel(x-1, y) == 0xFFFFFF)
						{
							x--;
							nxtMov = 4;
						}
						else if(_snapBD.getPixel(x-1, y+1) == 0xFFFFFF)
						{
							x--;
							y++;
							nxtMov = 5;
						}
						else if(_snapBD.getPixel(x, y+1) == 0xFFFFFF)
						{
							y++;
							nxtMov = 6;
						}
						else if(_snapBD.getPixel(x+1, y+1) == 0xFFFFFF)
						{
							x++;
							y++;
							nxtMov = 7;
						}
						break;
					
					//From East
					case 4:
						if(_snapBD.getPixel(x+1, y-1) == 0xFFFFFF)
						{
							x++;
							y--;
							nxtMov = 1;
						}
						else if(_snapBD.getPixel(x, y-1) == 0xFFFFFF)
						{
							y--;
							nxtMov = 2;
						}
						else if(_snapBD.getPixel(x-1, y-1) == 0xFFFFFF)
						{
							x--;
							y--;
							nxtMov = 3;
						}
						else if(_snapBD.getPixel(x-1, y) == 0xFFFFFF)
						{
							x--;
							nxtMov = 4;
						}
						else if(_snapBD.getPixel(x-1, y+1) == 0xFFFFFF)
						{
							x--;
							y++;
							nxtMov = 5;
						}
						else if(_snapBD.getPixel(x, y+1) == 0xFFFFFF)
						{
							y++;
							nxtMov = 6;
						}
						else if(_snapBD.getPixel(x+1, y+1) == 0xFFFFFF)
						{
							x++;
							y++;
							nxtMov = 7;
						}
						else if(_snapBD.getPixel(x+1, y) == 0xFFFFFF)
						{
							x++;
							nxtMov = 0;
						}
						break;
					
					//From NorthEast
					case 5:
						if(_snapBD.getPixel(x, y-1) == 0xFFFFFF)
						{
							y--;
							nxtMov = 2;
						}
						else if(_snapBD.getPixel(x-1, y-1) == 0xFFFFFF)
						{
							x--;
							y--;
							nxtMov = 3;
						}
						else if(_snapBD.getPixel(x-1, y) == 0xFFFFFF)
						{
							x--;
							nxtMov = 4;
						}
						else if(_snapBD.getPixel(x-1, y+1) == 0xFFFFFF)
						{
							x--;
							y++;
							nxtMov = 5;
						}
						else if(_snapBD.getPixel(x, y+1) == 0xFFFFFF)
						{
							y++;
							nxtMov = 6;
						}
						else if(_snapBD.getPixel(x+1, y+1) == 0xFFFFFF)
						{
							x++;
							y++;
							nxtMov = 7;
						}
						else if(_snapBD.getPixel(x+1, y) == 0xFFFFFF)
						{
							x++;
							nxtMov = 0;
						}
						else if(_snapBD.getPixel(x+1, y-1) == 0xFFFFFF)
						{
							x++;
							y--;
							nxtMov = 1;
						}
						break;
					
					//From North
					case 6:
						if(_snapBD.getPixel(x-1, y-1) == 0xFFFFFF)
						{
							x--;
							y--;
							nxtMov = 3;
						}
						else if(_snapBD.getPixel(x-1, y) == 0xFFFFFF)
						{
							x--;
							nxtMov = 4;
						}
						else if(_snapBD.getPixel(x-1, y+1) == 0xFFFFFF)
						{
							x--;
							y++;
							nxtMov = 5;
						}
						else if(_snapBD.getPixel(x, y+1) == 0xFFFFFF)
						{
							y++;
							nxtMov = 6;
						}
						else if(_snapBD.getPixel(x+1, y+1) == 0xFFFFFF)
						{
							x++;
							y++;
							nxtMov = 7;
						}
						else if(_snapBD.getPixel(x+1, y) == 0xFFFFFF)
						{
							x++;
							nxtMov = 0;
						}
						else if(_snapBD.getPixel(x+1, y-1) == 0xFFFFFF)
						{
							x++;
							y--;
							nxtMov = 1;
						}
						else if(_snapBD.getPixel(x, y-1) == 0xFFFFFF)
						{
							y--;
							nxtMov = 2;
						}
						break;
					
					//From NorthWest
					default:
						if(_snapBD.getPixel(x-1, y) == 0xFFFFFF)
						{
							x--;
							nxtMov = 4;
						}
						else if(_snapBD.getPixel(x-1, y+1) == 0xFFFFFF)
						{
							x--;
							y++;
							nxtMov = 5;
						}
						else if(_snapBD.getPixel(x, y+1) == 0xFFFFFF)
						{
							y++;
							nxtMov = 6;
						}
						else if(_snapBD.getPixel(x+1, y+1) == 0xFFFFFF)
						{
							x++;
							y++;
							nxtMov = 7;
						}
						else if(_snapBD.getPixel(x+1, y) == 0xFFFFFF)
						{
							x++;
							nxtMov = 0;
						}
						else if(_snapBD.getPixel(x+1, y-1) == 0xFFFFFF)
						{
							x++;
							y--;
							nxtMov = 1;
						}
						else if(_snapBD.getPixel(x, y-1) == 0xFFFFFF)
						{
							y--;
							nxtMov = 2;
						}
						else if(_snapBD.getPixel(x-1, y-1) == 0xFFFFFF)
						{
							x--;
							y--;
							nxtMov = 3;
						}
						break;
				}
				
				//Determine whether to print right pixels or left pixels
				//Consider printing right when moving up
				if(((nxtMov > 0) && (nxtMov < 4) && (prevMov != 4) && (prevMov != 5)) ||
					((nxtMov > 3) && (nxtMov < 7) && (prevMov > 0) && (prevMov < 4)) ||
					((nxtMov - prevMov) == 4) || ((prevMov - nxtMov) == 4))
				{					
					sidePixel = prevX + 1;
					
					//Do not print pixel at the right edge
					while(_snapBD.getPixel(sidePixel, prevY) != 0xFFFFFF)
					{
						_cropBD.setPixel32(sidePixel, prevY, _imgBD.getPixel32(sidePixel, prevY));
						sidePixel++;
						ctr++;
					}
				}
				
				//Move onto next edge
				prevMov = nxtMov;
			}
			
			_enterFrameDispatcher.removeEventListener(Event.ENTER_FRAME, _SnapCrop);
		}
		
		
		private function _TrimImage():BitmapData
		{
			var top:uint;
			var bottom:uint;
			var left:uint = 0;
			var right:uint = _imgWidth;
			var i:uint;
			var j:uint;
			var end:Boolean = false;
			var trimBD:BitmapData;
			
			//Trim top
			for(j = 0; j < _imgHeight; j++)
			{
				for(i = 0; i < _imgWidth; i++)
				{
					if(_cropBD.getPixel32(i, j) > 0)
					{
						end = true;
						
						break;
					}
				}
				
				if(end)
				{
					break;
				}
			}
			
			top = j
			
			//Trim bottom
			end = false;
			
			for(j = _imgHeight - 1; j > top; j--)
			{
				for(i = 0; i < _imgWidth; i++)
				{
					if(_cropBD.getPixel32(i, j) > 0)
					{
						end = true;
						
						break;
					}
				}
				
				if(end)
				{
					break;
				}
			}
			
			bottom = j;
			
			//Trim left
			end = false;
			
			for(i = 0; i < _imgWidth; i++)
			{
				for(j = top; j <= bottom; j++)
				{
					if(_cropBD.getPixel32(i, j) > 0)
					{
						end = true;
						
						break;
					}
				}
				
				if(end)
				{
					break;
				}
			}
			
			left = i;
			
			//Trim right
			end = false;
			
			for(i = _imgWidth - 1; i > left; i--)
			{
				for(j = top; j <= bottom; j++)
				{
					if(_cropBD.getPixel32(i, j) > 0)
					{
						end = true;
						
						break;
					}
				}
				
				if(end)
				{
					break;
				}
			}
			
			right = i;
			
			//Get trimmed image			
			trimBD = new BitmapData((right - left + 1), (bottom - top + 1));			
			trimBD.copyPixels(_cropBD, new Rectangle(left, top, (right + 1), (bottom + 1)), new Point(0, 0));
			
			return trimBD;
		}
	}
}