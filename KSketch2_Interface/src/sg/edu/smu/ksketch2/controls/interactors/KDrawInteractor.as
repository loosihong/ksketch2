/**
 * Copyright 2010-2012 Singapore Management University
 * Developed under a grant from the Singapore-MIT GAMBIT Game Lab
 * This Source Code Form is subject to the terms of the
 * Mozilla Public License, v. 2.0. If a copy of the MPL was
 * not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/.
 */
package sg.edu.smu.ksketch2.controls.interactors
{
	import flash.geom.Point;
	
	import spark.core.SpriteVisualElement;
	
	import sg.edu.smu.ksketch2.KSketch2;
	import sg.edu.smu.ksketch2.controls.interactioncontrol.IInteractionControl;
	import sg.edu.smu.ksketch2.model.data_structures.KModelObjectList;
	import sg.edu.smu.ksketch2.model.objects.KStroke;
	import sg.edu.smu.ksketch2.operators.operations.KCompositeOperation;
	import sg.edu.smu.ksketch2.utils.KSelection;
	import sg.edu.smu.ksketch2.view.KStrokeView;
	
	public class KDrawInteractor extends KInteractor
	{
		public static var penColor:uint = 0X000000;
		public static var penThickness:Number = 3.5;
		private var _temporaryStroke:KStrokeView;
		private var _points:Vector.<Point>;
		protected var _interactorDisplay:SpriteVisualElement;
		
		public function KDrawInteractor(KSKetchInstance:KSketch2, interactorDisplay:SpriteVisualElement, interactionControl:IInteractionControl)
		{
			_interactorDisplay = interactorDisplay;
			super(KSKetchInstance, interactionControl);
			_temporaryStroke = new KStrokeView(null);
		}
		
		/**
		 * DrawInteractor.interaction_Begin creates a temporary view to display the
		 * new stroke that is being drawn. This temporaray view has no properties and
		 * is seriously just there for cosmetic purposes
		 */
		override public function interaction_Begin(point:Point):void
		{
			_interactionControl.begin_interaction_operation();
			activate();
			interaction_Update(point);
		}
		
		/**
		 * Updates the temporary view with the new mouse move point.
		 * Adds to the collection of points that will be used to create the
		 * Stroke Object in the model
		 */
		override public function interaction_Update(point:Point):void
		{
			_temporaryStroke.edit_AddPoint(point);
		}
		
		override public function interaction_End():void
		{
			if(_points.length < 2)
			{
				reset();
				_interactionControl.end_interaction_operation();
				return;
			}
			
			_points = _CatmullRomSpline(_points);
			
			var drawOp:KCompositeOperation = new KCompositeOperation();
			var newStroke:KStroke = _KSketch.object_Add_Stroke(_points, _KSketch.time, penColor, penThickness, drawOp);
			var newObjects:KModelObjectList = new KModelObjectList();
			newObjects.add(newStroke);
			_interactionControl.end_interaction_operation(drawOp, new KSelection(newObjects));
			reset();
		}		
		
		override public function activate():void
		{
			_points = new Vector.<Point>();
			_temporaryStroke.points = _points;
			_temporaryStroke.color = penColor;
			_temporaryStroke.thickness = penThickness;
			_interactorDisplay.addChild(_temporaryStroke);
		}
		
		override public function reset():void
		{
			if(_temporaryStroke.parent)
				_temporaryStroke.parent.removeChild(_temporaryStroke);
		}
		
		/**
		 * Replace straight line between points with Catmull Rom Spline
		 */
		private function _CatmullRomSpline(points:Vector.<Point>):Vector.<Point>
		{
			//Check there is at least 4 control points
			var pCtr:int = points.length;
			
			if(pCtr < 4)
			{
				return points;
			}		
			
			//Set tangent for all points
			var m:Array = new Array(pCtr);
			
			//Tangent for first control point
			m[0] = _PointTangent(points[1], points[0]);
			pCtr--;
			
			//Tangent for the rest of control points
			for(var i:int = 1; i<pCtr; i++)
			{
				m[i] = _PointTangent(points[i + 1], points[i - 1]);
			}
			
			//Tangent for last control point
			m[pCtr] = _PointTangent(points[pCtr], points[pCtr - 1]);
			
			//Create new points for Catmull Rom Spline
			var newPoints:Vector.<Point> = new Vector.<Point>();
			
			for(var j:int = 0; j < pCtr; j++)
			{
				var nxtJ:int = j + 1;
				var p0:Point = points[j];
				var p1:Point = points[nxtJ];
				var m0:Point = m[j];
				var m1:Point = m[nxtJ];
				
				//Set resolution to maximum update every 1 pixel
				var res:Number = 1/(1 + Point.distance(p0, p1));
				
				for(var t:Number = 0; t < 1; t+=res)
				{
					var t2:Number = t * t;
					var OneMinusT:Number = 1 - t;
					var twoT:Number = 2*t;
					
					var h00:Number = (1 + twoT)*OneMinusT*OneMinusT;
					var h10:Number = t*OneMinusT*OneMinusT;
					var h01:Number = t2*(3 - twoT);
					var h11:Number = t2*(t - 1);					
					
					var xCoord:Number = h00 * p0.x + h10 * m0.x + h01 * p1.x + h11 * m1.x;
					var yCoord:Number = h00 * p0.y + h10 * m0.y + h01 * p1.y + h11 * m1.y;
					
					newPoints.push(new Point(xCoord, yCoord));
				}		
			}
			
			//Add last control point to Catmull Rom Spline
			newPoints.push(new Point(points[pCtr].x, points[pCtr].y));
			
			return newPoints;
		}
		
		/**
		 * Used to calculate tangent of control points in Catmull Rom Spline
		 */
		private function _PointTangent(prevPt:Point, nxtPt:Point):Point
		{
			return new Point((prevPt.x - nxtPt.x)/2, (prevPt.y - nxtPt.y)/2);
		}
	}
}