/**
	Const 类用于存储在代码中需要全局访问的各种值。例如: `Const.FPS`
**/
class Const {
#if !macro

	/** 默认引擎帧率 (60) **/
	public static var FPS(get,never) : Int;
		static inline function get_FPS() return Std.int( hxd.System.getDefaultFrameRate() );

	/**
		"固定"更新帧率。30fps是个不错的选择，因为它几乎可以在任何像样的设备上运行，
		而且对于任何游戏相关的物理运算来说都足够了。
	**/
	public static final FIXED_UPDATE_FPS = 30;

	/** 网格大小（像素） **/
	public static final GRID = 16;

	/** "无限"值，或者说是一个"很大的数" **/
	public static final INFINITE : Int = 0xfffFfff;

	static var _nextUniqueId = 0;
	/** 唯一值生成器 **/
	public static inline function makeUniqueId() {
		return _nextUniqueId++;
	}

	/** 视口缩放 **/
	public static var SCALE(get,never) : Int;
		static inline function get_SCALE() {
			// 可以替换为其他确定游戏缩放的方式
			return dn.heaps.Scaler.bestFit_i(200,200);
		}

	/** UI元素的特定缩放 **/
	public static var UI_SCALE(get,never) : Float;
		static inline function get_UI_SCALE() {
			// 可以替换为其他确定UI缩放的方式
			return dn.heaps.Scaler.bestFit_i(400,400);
		}

	/** 当前构建信息，包括日期、时间、语言和其他各种信息 **/
	public static var BUILD_INFO(get,never) : String;
		static function get_BUILD_INFO() return dn.MacroTools.getBuildInfo();

	/** 游戏图层索引 **/
	static var _inc = 0;
	public static var DP_BG = _inc++;
	public static var DP_FX_BG = _inc++;
	public static var DP_MAIN = _inc++;
	public static var DP_FRONT = _inc++;
	public static var DP_FX_FRONT = _inc++;
	public static var DP_TOP = _inc++;
	public static var DP_UI = _inc++;

	/**
		使用 CastleDB 和 JSON 文件的简化"常量数据库"
		它将包含以下两个来源中的所有值：

		- `res/const.json`，一个基本的JSON文件
		- `res/data.cdb`，CastleDB文件中名为"ConstDb"的表

		这允许你非常容易地访问游戏常量和设置。例如：

			在 `res/const.json` 中：
				{ "myValue":5, "someText":"hello" }

			你可以使用：
				Const.db.myValue; // 等于 5
				Const.db.someText; // 等于 "hello"

		如果JSON在运行时发生变化，`myValue`字段会保持更新，这允许在不重新编译的情况下进行测试。
		重要提示：这种热重载功能仅在使用`-debug`标志构建项目时有效。
		在发布版本中，所有值都会变成常量并被完全嵌入。
	**/
	public static var db = ConstDbBuilder.buildVar(["data.cdb", "const.json"]);

#end
}
