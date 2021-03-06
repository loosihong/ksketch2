package sg.edu.smu.ksketch2.operators.operations
{
	import sg.edu.smu.ksketch2.model.data_structures.IVisibilityKey;

	public class KVisibilityChangedOperation implements IModelOperation
	{
		private var _key:IVisibilityKey;
		private var _oldVisibility:Boolean;
		private var _newVisibility:Boolean
		
		public function KVisibilityChangedOperation(key:IVisibilityKey, oldVisibility:Boolean, newVisibility:Boolean)
		{
			_key = key;
			_oldVisibility = oldVisibility;
			_newVisibility = newVisibility;
		}
		
		public function get errorMessage():String
		{
			return "KVisibilityChangedOperation does not have enough information to perform its duties";
		}
		
		public function isValid():Boolean
		{
			return _key != null;
		}
		
		public function undo():void
		{
			_key.visible = _oldVisibility;
		}
		
		public function redo():void
		{
			_key.visible = _newVisibility;
		}
		
		public function debug():void
		{
			
		}
	}
}