class Level extends GameChildProcess {
	/** 关卡基于网格的宽度 **/
	public var cWid(default,null): Int;
	/** 关卡基于网格的高度 **/
	public var cHei(default,null): Int;

	/** 关卡像素宽度 **/
	public var pxWid(default,null) : Int;
	/** 关卡像素高度 **/
	public var pxHei(default,null) : Int;

	public var data : World_Level;
	var tilesetSource : h2d.Tile;

	public var marks : dn.MarkerMap<LevelMark>;
	var invalidated = true;

	public function new(ldtkLevel:World.World_Level) {
		super();

		createRootInLayers(Game.ME.scroller, Const.DP_BG);
		data = ldtkLevel;
		cWid = data.l_Collisions.cWid;
		cHei = data.l_Collisions.cHei;
		pxWid = cWid * Const.GRID;
		pxHei = cHei * Const.GRID;
		tilesetSource = hxd.Res.levels.sampleWorldTiles.toAseprite().toTile();

		marks = new dn.MarkerMap(cWid, cHei);
		for(cy in 0...cHei)
		for(cx in 0...cWid) {
			if( data.l_Collisions.getInt(cx,cy)==1 )
				marks.set(M_Coll_Wall, cx,cy);
		}
	}

	override function onDispose() {
		super.onDispose();
		data = null;
		tilesetSource = null;
		marks.dispose();
		marks = null;
	}

	/** 判断给定坐标是否在关卡边界内 **/
	public inline function isValid(cx,cy) return cx>=0 && cx<cWid && cy>=0 && cy<cHei;

	/** 获取给定关卡网格坐标的整数ID **/
	public inline function coordId(cx,cy) return cx + cy*cWid;

	/** 请求关卡重新渲染，这将在当前帧结束时进行 **/
	public inline function invalidate() {
		invalidated = true;
	}

	/** 返回"Collisions"层在给定位置是否包含碰撞值 **/
	public inline function hasCollision(cx,cy) : Bool {
		return !isValid(cx,cy) ? true : marks.has(M_Coll_Wall, cx,cy);
	}

	/** 渲染当前关卡 **/
	function render() {
		// 关卡渲染占位符
		root.removeChildren();

		var tg = new h2d.TileGroup(tilesetSource, root);
		data.l_Collisions.render(tg);
	}

	override function postUpdate() {
		super.postUpdate();

		if( invalidated ) {
			invalidated = false;
			render();
		}
	}
}