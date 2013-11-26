/**
 * Copyright 2010-2012 Singapore Management University
 * Developed under a grant from the Singapore-MIT GAMBIT Game Lab
 * This Source Code Form is subject to the terms of the
 * Mozilla Public License, v. 2.0. If a copy of the MPL was
 * not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/.
 */
package sg.edu.smu.ksketch2.view
{
	import flash.filters.GlowFilter;
	import flash.geom.Point;
	
	import sg.edu.smu.ksketch2.controls.interactors.KDrawInteractor;
	import sg.edu.smu.ksketch2.events.KObjectEvent;
	import sg.edu.smu.ksketch2.model.objects.KStroke;
	import sg.edu.smu.ksketch2.operators.operations.KCompositeOperation;
	
	public class KStrokeView extends KObjectView
	{
		private var _points:Vector.<Point>;
		private var _thickness:Number = KDrawInteractor.penThickness;
		private var _color:uint = KDrawInteractor.penColor;
		private var _glowFilter:Array;
		private var _isTempView:Boolean;
		
		/**
		 * Object view representing strokes
		 */
		public function KStrokeView(object:KStroke, isGhost:Boolean = false, showPath:Boolean = true, isTempView:Boolean = true)
		{
			if(!isGhost)
				_ghost = new KStrokeView(object, true, showPath);
			super(object, isGhost, showPath);
			
			if(object)
			{
				points = object.points;
				_color = object.color;
				_thickness = object.thickness;
			}
			else
				_points = new Vector.<Point>();

			var filter:GlowFilter = new GlowFilter(_color, 1,10,10,8,1,true, true);
			_glowFilter = [filter];
			_render_DrawStroke();
			cacheAsBitmap = true;
			_isTempView = isTempView;
		}
		
		override public function eraseIfHit(xPoint:Number, yPoint:Number, time:int, op:KCompositeOperation):void
		{
			if(hitTestPoint(xPoint, yPoint, true))
				_object.visibilityControl.setVisibility(false, time, op);
		}
		
		/**
		 * Setting this explicitly changes the points that will be drawn
		 */
		public function set points(newPoints:Vector.<Point>):void
		{
			_points = newPoints;
			_render_DrawStroke();
		}
		
		/**
		 * Adds a point to the end of this stroke view. Forces a rerender
		 */
		public function edit_AddPoint(newPoint:Point):void
		{
			//Convert sampled points to Catmull-Rom Spline control points
			var ctrlPt1:Point;
			var ctrlPt2:Point;
			var crossPt:Point;
			
			if(_points.length > 3)
			{
				//Add new Catmull-Rom Spline control point will affect last second and last third point
				var idx1:uint = _points.length - 4;
				var idx2:uint = _points.length - 3;
				var idx3:uint = _points.length - 2;
				var idx4:uint = _points.length - 1;
				var tangent:Point;
				
				//Recalculate last third point
				tangent = _PointTangent(_points[idx4], _points[_points.length - 7]);
				//_points[idx2].setTo((_points[idx1].x + (tangent.x/3)), (_points[idx1].y + (tangent.y/3)));
				
				//Recalculate last second point
				tangent = _PointTangent(newPoint, _points[idx1]);
				_points[idx3].setTo((_points[idx4].x - (tangent.x/3)), (_points[idx4].y - (tangent.y/3)));
				//_FixCuspNIntersect(_points[idx1], _points[idx2], _points[idx3], _points[idx4]);
				
				//Push in two more new Beizer control points
				ctrlPt1 = new Point((_points[idx4].x + (tangent.x/3)), (_points[idx4].y + (tangent.y/3)));
				tangent = _PointTangent(newPoint, _points[idx4]);
				ctrlPt2 = new Point((newPoint.x - (tangent.x/3)), (newPoint.y - (tangent.y/3)));
				//_FixCuspNIntersect(_points[idx4], ctrlPt1, ctrlPt2, newPoint);
				
				_points.push(ctrlPt1);				
				_points.push(ctrlPt2);
			}
			else if(_points.length == 3)
			{
				var tangentArr:Array = new Array(4);
				var splinePoints:Vector.<Point> = new Vector.<Point>();
				
				//Push in new point for ease of calculation
				_points.push(newPoint);
				
				//Calculate all four tangents
				tangentArr[0] = _PointTangent(_points[1], _points[0]);
				tangentArr[1] = _PointTangent(_points[2], _points[0]);
				tangentArr[2] = _PointTangent(_points[3], _points[1]);
				tangentArr[3] = _PointTangent(_points[3], _points[2]);
				
				//Add two bezier control points in between two catmull rom control points
				for(var i:uint = 0; i < 3; i++)
				{
					//First catmull rom control points, B0 = P0
					//First bezier control points, B1 = P0 + M0/3
					//Second bezier control points, B2 = P1 - M1/3
					splinePoints.push(_points[i]);
					ctrlPt1 = new Point((_points[i].x + (tangentArr[i].x/3)), (_points[i].y + (tangentArr[i].y/3)));
					ctrlPt2 = new Point((_points[i+1].x - (tangentArr[i+1].x/3)), (_points[i+1].y - (tangentArr[i+1].y/3)));
					
					if(i > 0 )
					{
						//_FixCuspNIntersect(_points[i], ctrlPt1, ctrlPt2, _points[i+1]);
					}
					
					splinePoints.push(ctrlPt1);
					splinePoints.push(ctrlPt2);
					
					//Second catmull rom control points, B1 = P1
					//To be covered in next iteration
				}
				
				for(i = 1; i < 4; i++)
				{
					_points[i] = splinePoints[i];
				}
				
				for(i = 4; i < 9; i++)
				{
					_points.push(splinePoints[i]);
				}
			}
			
			_points.push(newPoint);
			_render_DrawStroke();
		}
		
		private function _FixCuspNIntersect(fixPt1:Point, ctrlPt1:Point, ctrlPt2:Point, fixPt2:Point):void
		{
			var a1:Number = ctrlPt1.y  - fixPt1.y;
			var b1:Number = fixPt1.x - ctrlPt1.x;
			var c1:Number = ctrlPt1.x*fixPt1.y - fixPt1.x*ctrlPt1.y;
			var a2:Number = fixPt2.y - ctrlPt2.y;
			var b2:Number = ctrlPt2.x - fixPt2.x;
			var c2:Number = fixPt2.x*ctrlPt2.y - ctrlPt2.x*fixPt2.y;
			var denom:Number = a1*b2 - a2*b1;
			
			//Do not modify at allLines are parallel to each other
			if(denom == 0)
			{
				return;
			}
			
			//Get intersection point
			var intPt:Point = new Point(((b1*c2 - b2*c1)/denom), ((a2*c1 - a1*c2)/denom));
			
			//Cusp occurs when intersection point is on one of the two lines 
			//Self interesction occurs when intersection point is on both lines
			//Set control point 1 to intersection point if intersection point is on first line
			c1 = Math.max(fixPt1.x, ctrlPt1.x);
			c2 = Math.min(fixPt1.x, ctrlPt1.x);
			
			if((intPt.x <= c1) && (intPt.x >= c2))
			{
				ctrlPt1.copyFrom(intPt);
			}
			
			//Set control point 2 to intersection point if intersection point is on second line
			c1 = Math.max(ctrlPt2.x, fixPt2.x);
			c2 = Math.min(ctrlPt2.x, fixPt2.x);
			
			if((intPt.x <= c1) && (intPt.x >= c2))
			{			
				ctrlPt2.copyFrom(intPt);
			}
		}
		
		/**
		 * Used to calculate tangent of control points in Catmull Rom Spline
		 */
		private function _PointTangent(prevPt:Point, nxtPt:Point):Point
		{
			return new Point((prevPt.x - nxtPt.x)/2, (prevPt.y - nxtPt.y)/2);
		}
		
		/**
		 * Changes the color for this stroke view. Forces a rerender
		 */
		public function set color(newColor:uint):void
		{
			_color = newColor;
			_render_DrawStroke();
		}
		
		/**
		 * Changes the color for this stroke view. Forces a rerender
		 */
		public function set thickness(newThickness:Number):void
		{
			_thickness = newThickness;
			_render_DrawStroke();
		}
		
		/**
		 * Draws this stroke view
		 */
		protected function _render_DrawStroke():void
		{
			graphics.clear();
			if(!_points)
				return;
			
			var length:int = _points.length;

			if(length < 2)
				return;
			
			graphics.lineStyle(_thickness, _color);
			graphics.moveTo(_points[0].x, _points[0].y);
			
			var i:int;

			if(length < 4)
			{
				for(i = 1; i < length; i++)
					graphics.lineTo(_points[i].x, _points[i].y);
			}
			else
			{
				length -= 3;
				
				for(i=1; i < length; i+=3)
				{
					graphics.cubicCurveTo(_points[i].x, _points[i].y, _points[i+1].x,
						_points[i+1].y, _points[i+2].x, _points[i+2].y);
				}
			}
			
			//For debug!
			//if(_object && _object.centroid)
				//graphics.drawCircle(_object.centroid.x, _object.centroid.y, 3);
		}
		
		/**
		 * Updates the selection for this stroke view by adding/removing a filter to it
		 */
		override protected function _updateSelection(event:KObjectEvent):void
		{
			if(_object.selected)
				filters = _glowFilter;
			else
				filters = [];
			
			super._updateSelection(event);
		}
	}
}