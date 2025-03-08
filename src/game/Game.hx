class Game extends AppChildProcess {
	public static var ME : Game;

	/** 游戏控制器（手柄或键盘） **/
	public var ca : ControllerAccess<GameAction>;

	/** 粒子效果 **/
	public var fx : Fx;

	/** 基础视口控制 **/
	public var camera : Camera;

	/** 所有视觉游戏对象的容器。这个包装器由Camera移动 **/
	public var scroller : h2d.Layers;

	/** 关卡数据 **/
	public var level : Level;

	/** 用户界面 **/
	public var hud : ui.Hud;

	/** 慢动作内部值 **/
	var curGameSpeed = 1.0;
	var slowMos : Map<SlowMoId, { id:SlowMoId, t:Float, f:Float }> = new Map();


	public function new() {
		super();

		ME = this;
		ca = App.ME.controller.createAccess();
		ca.lockCondition = isGameControllerLocked;
		createRootInLayers(App.ME.root, Const.DP_BG);
		dn.Gc.runNow();

		scroller = new h2d.Layers();
		root.add(scroller, Const.DP_BG);
		scroller.filter = new h2d.filter.Nothing(); // force rendering for pixel perfect

		fx = new Fx();
		hud = new ui.Hud();
		camera = new Camera();

		startLevel(Assets.worldData.all_worlds.SampleWorld.all_levels.FirstLevel);
	}


	public static function isGameControllerLocked() {
		return !exists() || ME.isPaused() || App.ME.anyInputHasFocus();
	}


	public static inline function exists() {
		return ME!=null && !ME.destroyed;
	}


	/** 加载关卡 **/
	function startLevel(l:World.World_Level) {
		if( level!=null )
			level.destroy();
		fx.clear();
		for(e in Entity.ALL) // <---- 替换为更适合的实体销毁方式（例如保持玩家存活）
			e.destroy();
		garbageCollectEntities();

		level = new Level(l);
		// <---- 这里：实例化你的关卡实体

		camera.centerOnTarget();
		hud.onLevelStart();
		dn.Process.resizeAll();
		dn.Gc.runNow();
	}



	/** 当 CastleDB 或 `const.json` 在磁盘上发生变化时调用 **/
	@:allow(App)
	function onDbReload() {
		hud.notify("DB reloaded");
	}


	/** 当 LDtk 文件在磁盘上发生变化时调用 **/
	@:allow(assets.Assets)
	function onLdtkReload() {
		hud.notify("LDtk reloaded");
		if( level!=null )
			startLevel( Assets.worldData.all_worlds.SampleWorld.getLevel(level.data.uid) );
	}

	/** 窗口/应用程序调整大小事件 **/
	override function onResize() {
		super.onResize();
	}


	/** 垃圾回收任何标记为销毁的实体。这通常在帧结束时完成，但如果你想确保标记的实体立即被处理并从列表中删除，可以手动调用它 **/
	public function garbageCollectEntities() {
		if( Entity.GC==null || Entity.GC.allocated==0 )
			return;

		for(e in Entity.GC)
			e.dispose();
		Entity.GC.empty();
	}

	/** 如果游戏被销毁，仅在帧结束时调用 **/
	override function onDispose() {
		super.onDispose();

		fx.destroy();
		for(e in Entity.ALL)
			e.destroy();
		garbageCollectEntities();

		if( ME==this )
			ME = null;
	}


	/**
		启动累积慢动作效果，这将影响此Process及其所有子进程中的`tmod`值

		@param sec 此慢动作的实时秒数持续时间
		@param speedFactor Process `tmod`的累积乘数
	**/
	public function addSlowMo(id:SlowMoId, sec:Float, speedFactor=0.3) {
		if( slowMos.exists(id) ) {
			var s = slowMos.get(id);
			s.f = speedFactor;
			s.t = M.fmax(s.t, sec);
		}
		else
			slowMos.set(id, { id:id, t:sec, f:speedFactor });
	}


	/** 更新慢动作的循环 **/
	final function updateSlowMos() {
		// Timeout active slow-mos
		for(s in slowMos) {
			s.t -= utmod * 1/Const.FPS;
			if( s.t<=0 )
				slowMos.remove(s.id);
		}

		// Update game speed
		var targetGameSpeed = 1.0;
		for(s in slowMos)
			targetGameSpeed*=s.f;
		curGameSpeed += (targetGameSpeed-curGameSpeed) * (targetGameSpeed>curGameSpeed ? 0.2 : 0.6);

		if( M.fabs(curGameSpeed-targetGameSpeed)<=0.001 )
			curGameSpeed = targetGameSpeed;
	}


	/**
		短暂暂停游戏1帧：对于有冲击力的时刻非常有用，
		比如在街头霸王中击中对手时 ;)
	**/
	public inline function stopFrame() {
		ucd.setS("stopFrame", 4/Const.FPS);
	}


	/** 在帧开始时发生的循环 **/
	override function preUpdate() {
		super.preUpdate();

		for(e in Entity.ALL) if( !e.destroyed ) e.preUpdate();
	}

	/** 在帧结束时发生的循环 **/
	override function postUpdate() {
		super.postUpdate();

		// Update slow-motions
		updateSlowMos();
		baseTimeMul = ( 0.2 + 0.8*curGameSpeed ) * ( ucd.has("stopFrame") ? 0.1 : 1 );
		Assets.tiles.tmod = tmod;

		// Entities post-updates
		for(e in Entity.ALL) if( !e.destroyed ) e.postUpdate();

		// Entities final updates
		for(e in Entity.ALL) if( !e.destroyed ) e.finalUpdate();

		// Dispose entities marked as "destroyed"
		garbageCollectEntities();
	}


	/** 主循环但限制在30fps（所以在某些帧中可能不会被调用） **/
	override function fixedUpdate() {
		super.fixedUpdate();

		// Entities "30 fps" loop
		for(e in Entity.ALL) if( !e.destroyed ) e.fixedUpdate();
	}

	/** 主循环 **/
	override function update() {
		super.update();

		// Entities main loop
		for(e in Entity.ALL) if( !e.destroyed ) e.frameUpdate();


		// Global key shortcuts
		if( !App.ME.anyInputHasFocus() && !ui.Window.hasAnyModal() && !Console.ME.isActive() ) {
			// Exit by pressing ESC twice
			#if hl
			if( ca.isKeyboardPressed(K.ESCAPE) )
				if( !cd.hasSetS("exitWarn",3) )
					hud.notify(Lang.t._("Press ESCAPE again to exit."));
				else
					App.ME.exit();
			#end

			// Attach debug drone (CTRL-SHIFT-D)
			#if debug
			if( ca.isPressed(ToggleDebugDrone) )
				new DebugDrone(); // <-- HERE: provide an Entity as argument to attach Drone near it
			#end

			// Restart whole game
			if( ca.isPressed(Restart) )
				App.ME.startGame();

		}
	}
}

