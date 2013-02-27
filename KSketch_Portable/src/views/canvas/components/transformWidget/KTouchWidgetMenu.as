package views.canvas.components.transformWidget
{
	import flash.display.DisplayObjectContainer;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.system.Capabilities;
	
	import mx.events.FlexMouseEvent;
	
	import spark.components.Button;
	import spark.components.SkinnablePopUpContainer;
	
	import sg.edu.smu.ksketch2.KSketch2;
	
	import views.canvas.interactioncontrol.KMobileInteractionControl;
	import views.canvas.interactors.widget.KWidgetInteractorManager;
	import views.document.previewer.KTouchPreviewerButtonSkin;
	import views.document.scrollerColumn.KTouchDocumentScrollerButtonSkin;
	
	public class KTouchWidgetMenu extends SkinnablePopUpContainer
	{		
		public const MAX_WIDGET_WIDTH:Number = 600;
		public const MAX_WIDGET_HEIGHT:Number = 600;
		public const MAX_WIDGET_RADIUS:Number = 300;

		private var _KSketch:KSketch2;
		private var _interactionControl:KMobileInteractionControl;
		private var _transitionHelper:KWidgetInteractorManager;
		private var _widget:KTouchWidgetBase;
		
		private var button1:Button;
		private var button2:Button;
		private var button3:Button;
		private var blocker:Button;
		
		//Need to find a way to display this radially
		public function KTouchWidgetMenu(KSketchInstance:KSketch2,
										 interactionControl:KMobileInteractionControl,
										 widget:KTouchWidgetBase, transitionHelper:KWidgetInteractorManager)
		{
			_KSketch = KSketchInstance;
			_interactionControl = interactionControl;
			_transitionHelper = transitionHelper;
			_widget = widget;
			
			super();
			setStyle("skinClass", KWidgetMenuSkin);
			
			blocker = new Button();
			blocker.setStyle("skinClass", Class(KTouchPreviewerButtonSkin));
			blocker.width = Capabilities.screenResolutionX > Capabilities.screenResolutionY?Capabilities.screenResolutionX:Capabilities.screenResolutionY;
			blocker.height= Capabilities.screenResolutionX > Capabilities.screenResolutionY?Capabilities.screenResolutionY:Capabilities.screenResolutionX;
			blocker.addEventListener(MouseEvent.CLICK , _handleClose);
			blocker.alpha = 0;
			
			button1 = new Button();
			button2 = new Button();
			button3 = new Button();
			
			button1.width = 50;
			button1.height = 50;
			
			button2.width = 50;
			button2.height = 50;
			
			button3.width = 50;
			button3.height = 50;
			
			button1.label = "1";
			button2.label = "2";
			button3.label = "3";
			
			addElement(blocker);
			addElement(button1);
			addElement(button2);
			addElement(button3);
		}
		
		/**
		 * Displays the context menu about xPos and yPos
		 * xPos abd yPos should be global coordinates
		 */
		public function showMenu(owner:DisplayObjectContainer, modal:Boolean=false,
									  xPos:Number = 0, yPos:Number = 0):void
		{
			x = xPos;
			y = yPos;
			
			blocker.x = -x;
			blocker.y = -y;
			super.open(owner, modal);

			_layoutButtons();
		}
		
		private function _layoutButtons():void
		{
			_widget.boundary.graphics.clear();
			_widget.boundary.graphics.beginFill(0x000000);
			_widget.boundary.graphics.drawCircle(-25,-25,MAX_WIDGET_RADIUS);
			_widget.boundary.graphics.endFill();
			
			var bounds:Rectangle = _widget.getRect(stage);
			
			_widget.boundary.graphics.clear();
			
			var maxX:Number = Capabilities.screenResolutionX;
			var maxY:Number = Capabilities.screenResolutionY;
			
			var allowedX:Number = maxX - bounds.right;
			var allowedY:Number = maxY - bounds.bottom;
			var point:Point;
			
			//Right
			if(bounds.left  < allowedX)
			{
				//Bottom
				if(bounds.top < allowedY)
				{
					point = Point.polar(275, 25/180*Math.PI);
					button1.x = point.x;
					button1.y = point.y;
					
					point = Point.polar(275, 40/180*Math.PI);
					button2.x = point.x;
					button2.y = point.y;
					
					point = Point.polar(275, 55/180*Math.PI);
					button3.x = point.x;
					button3.y = point.y;
				}
				else
				{
					point = Point.polar(275, -70/180*Math.PI);
					button1.x = point.x;
					button1.y = point.y;
					
					point = Point.polar(275, -55/180*Math.PI);
					button2.x = point.x;
					button2.y = point.y;
					
					point = Point.polar(275, -40/180*Math.PI);
					button3.x = point.x;
					button3.y = point.y;
				}
				
			}
			else//Left
			{
				//Bottom
				if(bounds.top < allowedY)
				{
					point = Point.polar(275, 165/180*Math.PI);
					button1.x = point.x;
					button1.y = point.y;
					
					point = Point.polar(275, 150/180*Math.PI);
					button2.x = point.x;
					button2.y = point.y;
					
					point = Point.polar(275, 135/180*Math.PI);
					button3.x = point.x;
					button3.y = point.y;
				}
				else
				{
					//top
					point = Point.polar(275, -120/180*Math.PI);
					button1.x = point.x;
					button1.y = point.y;
					
					point = Point.polar(275, -135/180*Math.PI);
					button2.x = point.x;
					button2.y = point.y;
					
					point = Point.polar(275, -150/180*Math.PI);
					button3.x = point.x;
					button3.y = point.y;
				}
			}			
		}
		
		private function _handleClose(event:MouseEvent):void
		{
			close();
		}
	}
}