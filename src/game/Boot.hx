/**
	Boot类是应用程序的入口点。
	它的功能比较简单，主要是创建Main类并处理游戏循环。因此，你不应该在这个类中做太多事情。
**/

class Boot extends hxd.App {
	#if debug
	// 调试模式下控制游戏速度
	var tmodSpeedMul = 1.0;

	// 控制器的快捷引用
	var ca(get,never) : ControllerAccess<GameAction>;
		inline function get_ca() return App.ME.ca;
	#end


	/**
		应用程序入口点：一切从这里开始
	**/
	static function main() {
		new Boot();
	}

	/**
		当引擎准备就绪时调用，实际的应用程序可以开始运行
	**/
	override function init() {
		new App(s2d);
		onResize();
	}

	// 窗口大小调整时
	override function onResize() {
		super.onResize();
		dn.Process.resizeAll();
	}


	/** 主应用程序循环 **/
	override function update(deltaTime:Float) {
		super.update(deltaTime);

		// 调试模式下控制应用程序速度
		var adjustedTmod = hxd.Timer.tmod;
		#if debug
		if( App.exists() ) {
			// 减速（切换）
			if( ca.isPressed(DebugSlowMo)  )
				tmodSpeedMul = tmodSpeedMul>=1 ? 0.2 : 1;
			adjustedTmod *= tmodSpeedMul;

			// 加速（按住按键时）
			adjustedTmod *= ca.isDown(DebugTurbo) ? 5 : 1;
		}
		#end

		#if( hl && !debug )
		try {
		#end

			// 运行所有 dn.Process 实例的循环
			dn.Process.updateAll(adjustedTmod);

			// 更新当前精灵图集的 "tmod" 值（用于动画）
			Assets.update(adjustedTmod);

		#if( hl && !debug )
		} catch(err) {
			App.onCrash(err);
		}
		#end
	}
}

