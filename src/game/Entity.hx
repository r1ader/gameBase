class Entity {
    /** 所有实体的固定数组 **/
    public static var ALL : FixedArray<Entity> = new FixedArray(1024);
    /** 垃圾回收用的实体固定数组 **/
    public static var GC : FixedArray<Entity> = new FixedArray(ALL.maxSize);

	// 便于访问所有重要内容的各种getter
	public var app(get,never) : App; inline function get_app() return App.ME;
	public var game(get,never) : Game; inline function get_game() return Game.ME;
	public var fx(get,never) : Fx; inline function get_fx() return Game.ME.fx;
	public var level(get,never) : Level; inline function get_level() return Game.ME.level;
	public var destroyed(default,null) = false;
	public var ftime(get,never) : Float; inline function get_ftime() return game.ftime;
	public var camera(get,never) : Camera; inline function get_camera() return game.camera;

	var tmod(get,never) : Float; inline function get_tmod() return Game.ME.tmod;
	var utmod(get,never) : Float; inline function get_utmod() return Game.ME.utmod;
	public var hud(get,never) : ui.Hud; inline function get_hud() return Game.ME.hud;

	/** 冷却时间 **/
	public var cd : dn.Cooldown;

	/** 不受慢动作影响的冷却时间（即始终以实时计算） **/
	public var ucd : dn.Cooldown;

	/** 临时游戏效果 **/
	var affects : Map<Affect,Float> = new Map();

	/** 状态机。值应该只能通过`startState(v)`来改变 **/
	public var state(default,null) : State;

	/** 唯一标识符 **/
	public var uid(default,null) : Int;

	/** 网格X坐标 **/
    public var cx = 0;
	/** 网格Y坐标 **/
    public var cy = 0;
	/** 网格内X坐标（从0.0到1.0） **/
    public var xr = 0.5;
	/** 网格内Y坐标（从0.0到1.0） **/
    public var yr = 1.0;

	var allVelocities : VelocityArray;

	/** 实体的基础X/Y速度 **/
	public var vBase : Velocity;
	/** "外部推力"速度。用于将实体推向某个方向，独立于"用户控制"的基础速度 **/
	public var vBump : Velocity;

	/** 最新一次fixedUpdate开始时附着点的上一个已知X位置（像素） **/
	var lastFixedUpdateX = 0.;
	/** 最新一次fixedUpdate开始时附着点的上一个已知Y位置（像素） **/
	var lastFixedUpdateY = 0.;

	/** 如果为TRUE，精灵显示坐标将在最后已知位置和当前位置之间进行插值。如果游戏逻辑发生在`fixedUpdate()`中（所以是30 FPS），但你仍想让精灵位置在60 FPS或更高的帧率下平滑移动时这很有用 **/
	var interpolateSprPos = true;

	/** 所有X速度的总和 **/
	public var dxTotal(get,never) : Float; inline function get_dxTotal() return allVelocities.getSumX();
	/** 所有Y速度的总和 **/
	public var dyTotal(get,never) : Float; inline function get_dyTotal() return allVelocities.getSumY();

	/** 实体像素宽度 **/
	public var wid(default,set) : Float = Const.GRID;
		inline function set_wid(v) { invalidateDebugBounds=true;  return wid=v; }
	public var iwid(get,set) : Int;
		inline function get_iwid() return M.round(wid);
		inline function set_iwid(v:Int) { invalidateDebugBounds=true; wid=v; return iwid; }

	/** 实体像素高度 **/
	public var hei(default,set) : Float = Const.GRID;
		inline function set_hei(v) { invalidateDebugBounds=true;  return hei=v; }
	public var ihei(get,set) : Int;
		inline function get_ihei() return M.round(hei);
		inline function set_ihei(v:Int) { invalidateDebugBounds=true; hei=v; return ihei; }

	/** 内部半径（像素）（即宽度/高度中较小值的一半） **/
	public var innerRadius(get,never) : Float;
		inline function get_innerRadius() return M.fmin(wid,hei)*0.5;

	/** "大"半径（像素）（即宽度/高度中较大值的一半） **/
	public var largeRadius(get,never) : Float;
		inline function get_largeRadius() return M.fmax(wid,hei)*0.5;

	/** 水平方向，只能是-1或1 **/
	public var dir(default,set) = 1;

	/** 当前精灵X **/
	public var sprX(get,never) : Float;
		inline function get_sprX() {
			return interpolateSprPos
				? M.lerp( lastFixedUpdateX, (cx+xr)*Const.GRID, game.getFixedUpdateAccuRatio() )
				: (cx+xr)*Const.GRID;
		}

	/** 当前精灵Y **/
	public var sprY(get,never) : Float;
		inline function get_sprY() {
			return interpolateSprPos
				? M.lerp( lastFixedUpdateY, (cy+yr)*Const.GRID, game.getFixedUpdateAccuRatio() )
				: (cy+yr)*Const.GRID;
		}

	/** 精灵X缩放 **/
	public var sprScaleX = 1.0;
	/** 精灵Y缩放 **/
	public var sprScaleY = 1.0;

	/** 精灵X挤压和拉伸缩放，会在几帧后自动恢复到1 **/
	var sprSquashX = 1.0;
	/** 精灵Y挤压和拉伸缩放，会在几帧后自动恢复到1 **/
	var sprSquashY = 1.0;

	/** 实体可见性 **/
	public var entityVisible = true;

	/** 当前生命值 **/
	public var life(default,null) : dn.struct.Stat<Int>;
	/** 如果最后一个伤害来源是实体则记录该实体 **/
	public var lastDmgSource(default,null) : Null<Entity>;

	/** 水平方向（左=-1或右=1）：从"最后伤害来源"到"此实体" **/
	public var lastHitDirFromSource(get,never) : Int;
	inline function get_lastHitDirFromSource() return lastDmgSource==null ? -dir : -dirTo(lastDmgSource);

	/** 水平方向（左=-1或右=1）：从"此实体"到"最后伤害来源" **/
	public var lastHitDirToSource(get,never) : Int;
		inline function get_lastHitDirToSource() return lastDmgSource==null ? dir : dirTo(lastDmgSource);

	/** 主要实体HSprite实例 **/
    public var spr : HSprite;

	/** 应用于精灵的颜色向量变换 **/
	public var baseColor : h3d.Vector;

	/** 应用于精灵的颜色矩阵变换 **/
	public var colorMatrix : h3d.Matrix;

	// 受伤时的动画闪烁颜色
	var blinkColor : h3d.Vector;

	/** 精灵X轴抖动强度 **/
	var shakePowX = 0.;
	/** 精灵Y轴抖动强度 **/
	var shakePowY = 0.;

	// 调试相关
	var debugLabel : Null<h2d.Text>;
	var debugBounds : Null<h2d.Graphics>;
	var invalidateDebugBounds = false;

	/** 定义实体在其附着点的X对齐（0到1.0） **/
	public var pivotX(default,set) : Float = 0.5;
	/** 定义实体在其附着点的Y对齐（0到1.0） **/
	public var pivotY(default,set) : Float = 1;

	/** 实体附着点X像素坐标 **/
	public var attachX(get,never) : Float; inline function get_attachX() return (cx+xr)*Const.GRID;
	/** 实体附着点Y像素坐标 **/
	public var attachY(get,never) : Float; inline function get_attachY() return (cy+yr)*Const.GRID;

	// 便于游戏编程的各种坐标获取器

	/** 边界框左侧像素坐标 **/
	public var left(get,never) : Float; inline function get_left() return attachX + (0-pivotX) * wid;
	/** 边界框右侧像素坐标 **/
	public var right(get,never) : Float; inline function get_right() return attachX + (1-pivotX) * wid;
	/** 边界框顶部像素坐标 **/
	public var top(get,never) : Float; inline function get_top() return attachY + (0-pivotY) * hei;
	/** 边界框底部像素坐标 **/
	public var bottom(get,never) : Float; inline function get_bottom() return attachY + (1-pivotY) * hei;

	/** 边界框中心X像素坐标 **/
	public var centerX(get,never) : Float; inline function get_centerX() return attachX + (0.5-pivotX) * wid;
	/** 边界框中心Y像素坐标 **/
	public var centerY(get,never) : Float; inline function get_centerY() return attachY + (0.5-pivotY) * hei;

	/** 当前在屏幕上的X位置（即绝对位置） **/
	public var screenAttachX(get,never) : Float;
		inline function get_screenAttachX() return game!=null && !game.destroyed ? sprX*Const.SCALE + game.scroller.x : sprX*Const.SCALE;

	/** 当前在屏幕上的Y位置（即绝对位置） **/
	public var screenAttachY(get,never) : Float;
		inline function get_screenAttachY() return game!=null && !game.destroyed ? sprY*Const.SCALE + game.scroller.y : sprY*Const.SCALE;

	/** 上一帧的attachX值 **/
	public var prevFrameAttachX(default,null) : Float = -Const.INFINITE;
	/** 上一帧的attachY值 **/
	public var prevFrameAttachY(default,null) : Float = -Const.INFINITE;

	var actions : RecyclablePool<tools.ChargedAction>;


	/**
		构造函数
	**/
    public function new(x:Int, y:Int) {
        uid = Const.makeUniqueId();
		ALL.push(this);

		cd = new dn.Cooldown(Const.FPS);
		ucd = new dn.Cooldown(Const.FPS);
		life = new Stat();
        setPosCase(x,y);
		initLife(1);
		state = Normal;
		actions = new RecyclablePool(15, ()->new tools.ChargedAction());

		allVelocities = new VelocityArray(15);
		vBase = registerNewVelocity(0.82);
		vBump = registerNewVelocity(0.93);

        spr = new HSprite(Assets.tiles);
		Game.ME.scroller.add(spr, Const.DP_MAIN);
		spr.colorAdd = new h3d.Vector();
		baseColor = new h3d.Vector();
		blinkColor = new h3d.Vector();
		spr.colorMatrix = colorMatrix = h3d.Matrix.I();
		spr.setCenterRatio(pivotX, pivotY);

		if( ui.Console.ME.hasFlag(F_Bounds) )
			enableDebugBounds();
    }


	/** 注册一个新的速度 **/
	public function registerNewVelocity(frict:Float) : Velocity {
		var v = Velocity.createFrict(frict);
		allVelocities.push(v);
		return v;
	}


	/** 从显示上下文中移除精灵。只有在你100%确定你的实体不会需要`spr`实例本身时才这么做 **/
	function noSprite() {
		spr.setEmptyTexture();
		spr.remove();
	}


	function set_pivotX(v) {
		pivotX = M.fclamp(v,0,1);
		if( spr!=null )
			spr.setCenterRatio(pivotX, pivotY);
		return pivotX;
	}

	function set_pivotY(v) {
		pivotY = M.fclamp(v,0,1);
		if( spr!=null )
			spr.setCenterRatio(pivotX, pivotY);
		return pivotY;
	}

	/** 初始化当前和最大生命值 **/
	public function initLife(v) {
		life.initMaxOnMax(v);
	}

	/** 造成伤害 **/
	public function hit(dmg:Int, from:Null<Entity>) {
		if( !isAlive() || dmg<=0 )
			return;

		life.v -= dmg;
		lastDmgSource = from;
		onDamage(dmg, from);
		if( life.v<=0 )
			onDie();
	}

	/** 立即击杀 **/
	public function kill(by:Null<Entity>) {
		if( isAlive() )
			hit(life.v, by);
	}

	function onDamage(dmg:Int, from:Entity) {}

	function onDie() {
		destroy();
	}

	inline function set_dir(v) {
		return dir = v>0 ? 1 : v<0 ? -1 : dir;
	}

	/** 如果当前实体未被销毁或击杀则返回TRUE **/
	public inline function isAlive() {
		return !destroyed && life.v>0;
	}

	/** 将实体移动到网格坐标 **/
	public function setPosCase(x:Int, y:Int) {
		cx = x;
		cy = y;
		xr = 0.5;
		yr = 1;
		onPosManuallyChangedBoth();
	}

	/** 将实体移动到像素坐标 **/
	public function setPosPixel(x:Float, y:Float) {
		cx = Std.int(x/Const.GRID);
		cy = Std.int(y/Const.GRID);
		xr = (x-cx*Const.GRID)/Const.GRID;
		yr = (y-cy*Const.GRID)/Const.GRID;
		onPosManuallyChangedBoth();
	}

	/** 当你手动（即忽略物理）修改X和Y实体坐标时应该调用此函数 **/
	function onPosManuallyChangedBoth() {
		if( M.dist(attachX,attachY,prevFrameAttachX,prevFrameAttachY) > Const.GRID*2 ) {
			prevFrameAttachX = attachX;
			prevFrameAttachY = attachY;
		}
		updateLastFixedUpdatePos();
	}

	/** 当你手动（即忽略物理）修改实体X坐标时应该调用此函数 **/
	function onPosManuallyChangedX() {
		if( M.fabs(attachX-prevFrameAttachX) > Const.GRID*2 )
			prevFrameAttachX = attachX;
		lastFixedUpdateX = attachX;
	}

	/** 当你手动（即忽略物理）修改实体Y坐标时应该调用此函数 **/
	function onPosManuallyChangedY() {
		if( M.fabs(attachY-prevFrameAttachY) > Const.GRID*2 )
			prevFrameAttachY = attachY;
		lastFixedUpdateY = attachY;
	}


	/** 快速设置X/Y轴心点。如果省略Y，它将等于X **/
	public function setPivots(x:Float, ?y:Float) {
		pivotX = x;
		pivotY = y!=null ? y : x;
	}

	/** 如果实体*中心点*在屏幕范围内则返回TRUE（默认边距为+32px） **/
	public inline function isOnScreenCenter(padding=32) {
		return camera.isOnScreen( centerX, centerY, padding + M.fmax(wid*0.5, hei*0.5) );
	}

	/** 如果实体矩形在屏幕范围内则返回TRUE（默认边距为+32px） **/
	public inline function isOnScreenBounds(padding=32) {
		return camera.isOnScreenRect( left,top, wid, hei, padding );
	}


	/**
		改变当前实体状态。
		如果调用后状态为`s`则返回TRUE。
	**/
	public function startState(s:State) : Bool {
		if( s==state )
			return true;

		if( !canChangeStateTo(state, s) )
			return false;

		var old = state;
		state = s;
		onStateChange(old,state);
		return true;
	}


	/** 返回TRUE以允许状态值的改变 **/
	function canChangeStateTo(from:State, to:State) {
		return true;
	}

	/** 当状态改变为新值时调用 **/
	function onStateChange(old:State, newState:State) {}


	/** 对实体施加推力/踢力 **/
	public function bump(x:Float,y:Float) {
		vBump.addXY(x,y);
	}

	/** 将速度重置为零 **/
	public function cancelVelocities() {
		allVelocities.clearAll();
	}

	public function is<T:Entity>(c:Class<T>) return Std.isOfType(this, c);
	public function as<T:Entity>(c:Class<T>) : T return Std.downcast(this, c);

	/** 返回范围[min,max]内的随机Float值。如果`sign`为TRUE，返回的值可能随机乘以-1 **/
	public inline function rnd(min,max,?sign) return Lib.rnd(min,max,sign);
	/** 返回范围[min,max]内的随机Integer值。如果`sign`为TRUE，返回的值可能随机乘以-1 **/
	public inline function irnd(min,max,?sign) return Lib.irnd(min,max,sign);

	/** 使用给定的`precision`截断float值 **/
	public inline function pretty(value:Float,?precision=1) return M.pretty(value,precision);

	public inline function dirTo(e:Entity) return e.centerX<centerX ? -1 : 1;
	public inline function dirToAng() return dir==1 ? 0. : M.PI;
	public inline function getMoveAng() return Math.atan2(dyTotal,dxTotal);

	/** 返回从此实体到某物的距离（以网格单位计） **/
	public inline function distCase(?e:Entity, ?tcx:Int, ?tcy:Int, txr=0.5, tyr=0.5) {
		if( e!=null )
			return M.dist(cx+xr, cy+yr, e.cx+e.xr, e.cy+e.yr);
		else
			return M.dist(cx+xr, cy+yr, tcx+txr, tcy+tyr);
	}

	/** 返回从此实体到某物的距离（以像素计） **/
	public inline function distPx(?e:Entity, ?x:Float, ?y:Float) {
		if( e!=null )
			return M.dist(attachX, attachY, e.attachX, e.attachY);
		else
			return return M.dist(attachX, attachY, x, y);
	}

	function canSeeThrough(cx:Int, cy:Int) {
		return !level.hasCollision(cx,cy) || this.cx==cx && this.cy==cy;
	}

	/** 检查此实体与给定目标之间的基于网格的线是否被某些障碍物阻挡 **/
	public inline function sightCheck(?e:Entity, ?tcx:Int, ?tcy:Int) {
		if( e!=null)
			return e==this ? true : dn.geom.Bresenham.checkThinLine(cx, cy, e.cx, e.cy, canSeeThrough);
		else
			return dn.geom.Bresenham.checkThinLine(cx, cy, tcx, tcy, canSeeThrough);
	}

	/** 从当前坐标创建一个LPoint实例 **/
	public inline function createPoint() return LPoint.fromCase(cx+xr,cy+yr);

	/** 从当前实体边界创建一个LRect实例 **/
	public inline function createRect() return tools.LRect.fromPixels( Std.int(left), Std.int(top), Std.int(wid), Std.int(hei) );

    public final function destroy() {
        if( !destroyed ) {
            destroyed = true;
            GC.push(this);
        }
    }

    public function dispose() {
        ALL.remove(this);

		allVelocities.dispose();
		allVelocities = null;
		baseColor = null;
		blinkColor = null;
		colorMatrix = null;

		spr.remove();
		spr = null;

		if( debugLabel!=null ) {
			debugLabel.remove();
			debugLabel = null;
		}

		if( debugBounds!=null ) {
			debugBounds.remove();
			debugBounds = null;
		}

		cd.dispose();
		cd = null;

		ucd.dispose();
		ucd = null;
    }


	/** 在实体下方打印一些数值 **/
	public inline function debugFloat(v:Float, c:Col=0xffffff) {
		debug( pretty(v), c );
	}


	/** 在实体下方打印一些值 **/
	public inline function debug(?v:Dynamic, c:Col=0xffffff) {
		#if debug
		if( v==null && debugLabel!=null ) {
			debugLabel.remove();
			debugLabel = null;
		}
		if( v!=null ) {
			if( debugLabel==null ) {
				debugLabel = new h2d.Text(Assets.fontPixel, Game.ME.scroller);
				debugLabel.filter = new dn.heaps.filter.PixelOutline();
			}
			debugLabel.text = Std.string(v);
			debugLabel.textColor = c;
		}
		#end
	}

	/** 隐藏实体调试边界 **/
	public function disableDebugBounds() {
		if( debugBounds!=null ) {
			debugBounds.remove();
			debugBounds = null;
		}
	}


	/** 显示实体调试边界（位置和宽度/高度）。使用控制台中的`/bounds`命令启用它们 **/
	public function enableDebugBounds() {
		if( debugBounds==null ) {
			debugBounds = new h2d.Graphics();
			game.scroller.add(debugBounds, Const.DP_TOP);
		}
		invalidateDebugBounds = true;
	}

	function renderDebugBounds() {
		var c = Col.fromHsl((uid%20)/20, 1, 1);
		debugBounds.clear();

		// 边界矩形
		debugBounds.lineStyle(1, c, 0.5);
		debugBounds.drawRect(left-attachX, top-attachY, wid, hei);

		// 附着点
		debugBounds.lineStyle(0);
		debugBounds.beginFill(c,0.8);
		debugBounds.drawRect(-1, -1, 3, 3);
		debugBounds.endFill();

		// 中心
		debugBounds.lineStyle(1, c, 0.3);
		debugBounds.drawCircle(centerX-attachX, centerY-attachY, 3);
	}

	/** 等待`sec`秒，然后运行提供的回调 **/
	function chargeAction(id:ChargedActionId, sec:Float, onComplete:ChargedAction->Void, ?onProgress:ChargedAction->Void) {
		if( !isAlive() )
			return;

		if( isChargingAction(id) )
			cancelAction(id);

		var a = actions.alloc();
		a.id = id;
		a.onComplete = onComplete;
		a.durationS = sec;
		if( onProgress!=null )
			a.onProgress = onProgress;
	}

	/** 如果id为null，在有任何动作正在充能时返回TRUE。如果提供了id，在这个特定动作正在充能时返回TRUE **/
	public function isChargingAction(?id:ChargedActionId) {
		if( !isAlive() )
			return false;

		if( id==null )
			return actions.allocated>0;

		for(a in actions)
			if( a.id==id )
				return true;

		return false;
	}

	public function cancelAction(?onlyId:ChargedActionId) {
		if( !isAlive() )
			return;

		if( onlyId==null )
			actions.freeAll();
		else {
			var i = 0;
			while( i<actions.allocated ) {
				if( actions.get(i).id==onlyId )
					actions.freeIndex(i);
				else
					i++;
			}
		}
	}

	/** 动作管理循环 **/
	function updateActions() {
		if( !isAlive() )
			return;

		var i = 0;
		while( i<actions.allocated ) {
			if( actions.get(i).update(tmod) )
				actions.freeIndex(i);
			else
				i++;
		}
	}


	public inline function hasAffect(k:Affect) {
		return isAlive() && affects.exists(k) && affects.get(k)>0;
	}

	public inline function getAffectDurationS(k:Affect) {
		return hasAffect(k) ? affects.get(k) : 0.;
	}

	/** 添加一个效果。如果`allowLower`为TRUE，则可以用更短的持续时间覆盖现有效果 **/
	public function setAffectS(k:Affect, t:Float, allowLower=false) {
		if( !isAlive() || affects.exists(k) && affects.get(k)>t && !allowLower )
			return;

		if( t<=0 )
			clearAffect(k);
		else {
			var isNew = !hasAffect(k);
			affects.set(k,t);
			if( isNew )
				onAffectStart(k);
		}
	}

	/** 将效果持续时间乘以系数`f` **/
	public function mulAffectS(k:Affect, f:Float) {
		if( hasAffect(k) )
			setAffectS(k, getAffectDurationS(k)*f, true);
	}

	public function clearAffect(k:Affect) {
		if( hasAffect(k) ) {
			affects.remove(k);
			onAffectEnd(k);
		}
	}

	/** 效果更新循环 **/
	function updateAffects() {
		if( !isAlive() )
			return;

		for(k in affects.keys()) {
			var t = affects.get(k);
			t-=1/Const.FPS * tmod;
			if( t<=0 )
				clearAffect(k);
			else
				affects.set(k,t);
		}
	}

	function onAffectStart(k:Affect) {}
	function onAffectEnd(k:Affect) {}

	/** 如果实体处于活动状态且没有阻止动作的状态效果，则返回TRUE **/
	public function isConscious() {
		return !hasAffect(Stun) && isAlive();
	}

	/** 让`spr`短暂闪烁（例如，当受到某些伤害时） **/
	public function blink(c:Col) {
		blinkColor.setColor(c);
		cd.setS("keepBlink",0.06);
	}

	public function shakeS(xPow:Float, yPow:Float, t:Float) {
		cd.setS("shaking", t, true);
		shakePowX = xPow;
		shakePowY = yPow;
	}

	/** 短暂在X轴上压扁精灵（Y相应改变）。"1.0"表示无变形 **/
	public function setSquashX(scaleX:Float) {
		sprSquashX = scaleX;
		sprSquashY = 2-scaleX;
	}

	/** 短暂在Y轴上压扁精灵（X相应改变）。"1.0"表示无变形 **/
	public function setSquashY(scaleY:Float) {
		sprSquashX = 2-scaleY;
		sprSquashY = scaleY;
	}


	/**
		"帧开始"循环，在任何其他Entity更新循环之前调用
	**/
    public function preUpdate() {
		ucd.update(utmod);
		cd.update(tmod);
		updateAffects();
		updateActions();


		#if debug
		// 显示活动的"效果"列表（在控制台中使用`/set affect`）
		if( ui.Console.ME.hasFlag(F_Affects) ) {
			var all = [];
			for(k in affects.keys())
				all.push( k+"=>"+M.pretty( getAffectDurationS(k) , 1) );
			debug(all);
		}

		// 显示边界（在控制台中使用`/bounds`）
		if( ui.Console.ME.hasFlag(F_Bounds) && debugBounds==null )
			enableDebugBounds();

		// 隐藏边界
		if( !ui.Console.ME.hasFlag(F_Bounds) && debugBounds!=null )
			disableDebugBounds();
		#end

    }

	/**
		后更新循环，保证在任何preUpdate/update之后发生。这通常是更新渲染和显示的地方
	**/
    public function postUpdate() {
		spr.x = sprX;
		spr.y = sprY;
        spr.scaleX = dir*sprScaleX * sprSquashX;
        spr.scaleY = sprScaleY * sprSquashY;
		spr.visible = entityVisible;

		sprSquashX += (1-sprSquashX) * M.fmin(1, 0.2*tmod);
		sprSquashY += (1-sprSquashY) * M.fmin(1, 0.2*tmod);

		if( cd.has("shaking") ) {
			spr.x += Math.cos(ftime*1.1)*shakePowX * cd.getRatio("shaking");
			spr.y += Math.sin(0.3+ftime*1.7)*shakePowY * cd.getRatio("shaking");
		}

		// 闪烁
		if( !cd.has("keepBlink") ) {
			blinkColor.r*=Math.pow(0.60, tmod);
			blinkColor.g*=Math.pow(0.55, tmod);
			blinkColor.b*=Math.pow(0.50, tmod);
		}

		// 颜色添加
		spr.colorAdd.load(baseColor);
		spr.colorAdd.r += blinkColor.r;
		spr.colorAdd.g += blinkColor.g;
		spr.colorAdd.b += blinkColor.b;

		// 调试标签
		if( debugLabel!=null ) {
			debugLabel.x = Std.int(attachX - debugLabel.textWidth*0.5);
			debugLabel.y = Std.int(attachY+1);
		}

		// 调试边界
		if( debugBounds!=null ) {
			if( invalidateDebugBounds ) {
				invalidateDebugBounds = false;
				renderDebugBounds();
			}
			debugBounds.x = Std.int(attachX);
			debugBounds.y = Std.int(attachY);
		}
	}

	/**
		在帧的绝对末尾运行的循环
	**/
	public function finalUpdate() {
		prevFrameAttachX = attachX;
		prevFrameAttachY = attachY;
	}


	final function updateLastFixedUpdatePos() {
		lastFixedUpdateX = attachX;
		lastFixedUpdateY = attachY;
	}



	/** 在每个X移动步骤开始时调用 **/
	function onPreStepX() {
	}

	/** 在每个Y移动步骤开始时调用 **/
	function onPreStepY() {
	}


	/**
		主循环，但它只在"保证"的30 fps下运行（所以如果应用程序以60fps运行，在某些帧中可能不会被调用）。这通常是大多数影响物理的游戏元素应该发生的地方，以确保这些不会依赖于FPS。
	**/
	public function fixedUpdate() {
		updateLastFixedUpdatePos();

		/*
			步进：任何大于网格大小33%的移动（即0.33）都会增加这里的`steps`数量。这些步骤将把完整的移动分解成更小的迭代，以避免跳过网格碰撞。
		*/
		var steps = M.ceil( ( M.fabs(dxTotal) + M.fabs(dyTotal) ) / 0.33 );
		if( steps>0 ) {
			var n = 0;
			while ( n<steps ) {
				// X移动
				xr += dxTotal / steps;

				if( dxTotal!=0 )
					onPreStepX(); // <---- 在这里添加X碰撞检查和物理

				while( xr>1 ) { xr--; cx++; }
				while( xr<0 ) { xr++; cx--; }


				// Y移动
				yr += dyTotal / steps;

				if( dyTotal!=0 )
					onPreStepY(); // <---- 在这里添加Y碰撞检查和物理

				while( yr>1 ) { yr--; cy++; }
				while( yr<0 ) { yr++; cy--; }

				n++;
			}
		}

		// 更新速度
		for(v in allVelocities)
			v.fixedUpdate();
	}


	/**
		以完整FPS运行的主循环（即在每一帧上总是发生一次，在preUpdate之后和postUpdate之前）
	**/
    public function frameUpdate() {
    }
}