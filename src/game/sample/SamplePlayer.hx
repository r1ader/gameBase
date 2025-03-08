package sample;

/**
	SamplePlayer 是一个具有一些额外功能的实体：
	- 用户控制（使用游戏手柄或键盘）
	- 受重力影响下落
	- 具有基本的关卡碰撞检测
	- 一些挤压动画，因为它们简单且能完成工作
**/

class SamplePlayer extends Entity {
	var ca : ControllerAccess<GameAction>;
	var walkSpeed = 0.;

	// 当玩家没有下落时这个值为 TRUE
	var onGround(get,never) : Bool;
		inline function get_onGround() return !destroyed && vBase.dy==0 && yr==1 && level.hasCollision(cx,cy+1);


	public function new() {
		super(5,5);

		// 使用关卡实体"PlayerStart"作为起点
		var start = level.data.l_Entities.all_PlayerStart[0];
		if( start!=null )
			setPosCase(start.cx, start.cy);

		// 杂项初始化
		vBase.setFricts(0.84, 0.94);

		// 摄像机追踪此实体
		camera.trackEntity(this, true);
		camera.clampToLevelBounds = true;

		// 初始化控制器
		ca = App.ME.controller.createAccess();
		ca.lockCondition = Game.isGameControllerLocked;

		// 占位显示
		var b = new h2d.Bitmap( h2d.Tile.fromColor(Green, iwid, ihei), spr );
		b.tile.setCenterRatio(0.5,1);
	}


	override function dispose() {
		super.dispose();
		ca.dispose(); // 不要忘记释放控制器访问
	}


	/** X轴碰撞 **/
	override function onPreStepX() {
		super.onPreStepX();

		// 右侧碰撞
		if( xr>0.8 && level.hasCollision(cx+1,cy) )
			xr = 0.8;

		// 左侧碰撞
		if( xr<0.2 && level.hasCollision(cx-1,cy) )
			xr = 0.2;
	}


	/** Y轴碰撞 **/
	override function onPreStepY() {
		super.onPreStepY();

		// 落地
		if( yr>1 && level.hasCollision(cx,cy+1) ) {
			setSquashY(0.5);
			vBase.dy = 0;
			vBump.dy = 0;
			yr = 1;
			ca.rumble(0.2, 0.06);
			onPosManuallyChangedY();
		}

		// 天花板碰撞
		if( yr<0.2 && level.hasCollision(cx,cy-1) )
			yr = 0.2;
	}


	/**
		在帧开始时检查控制输入。
		非常重要的注意事项：因为游戏物理只在 `fixedUpdate`（以恒定30 FPS）期间发生，这里不应该进行任何物理增量！
		这意味着你可以设置一个物理值（例如，参见下面的Jump），但不能进行任何跨多帧的计算（例如，走路时增加X速度）。
	**/
	override function preUpdate() {
		super.preUpdate();

		walkSpeed = 0;
		if( onGround )
			cd.setS("recentlyOnGround",0.1); // 允许"及时"跳跃


		// 跳跃
		if( cd.has("recentlyOnGround") && ca.isPressed(Jump) ) {
			vBase.dy = -0.85;
			setSquashX(0.6);
			cd.unset("recentlyOnGround");
			fx.dotsExplosionExample(centerX, centerY, 0xffcc00);
			ca.rumble(0.05, 0.06);
		}

		// 行走
		if( !isChargingAction() && ca.getAnalogDist2(MoveLeft,MoveRight)>0 ) {
			// 如上所述，我们在这里不直接修改物理值（如 `dx`）。我们只是存储一个"请求的行走速度"，它将在 fixedUpdate 中应用到实际物理中。
			walkSpeed = ca.getAnalogValue2(MoveLeft,MoveRight); // -1 到 1
		}
	}


	override function fixedUpdate() {
		super.fixedUpdate();

		// 重力
		if( !onGround )
			vBase.dy+=0.05;

		// 应用请求的行走移动
		if( walkSpeed!=0 )
			vBase.dx += walkSpeed * 0.045; // 一些任意速度
	}
}