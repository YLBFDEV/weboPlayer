package
{
	import com.alex.flexlite.components.VideoUI;
	import com.greensock.TweenLite;
	import com.hurlant.util.Base64;
	
	import flash.display.Bitmap;
	import flash.events.Event;
	import flash.events.FullScreenEvent;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import events.GlobalServer;
	import events.GlobalServerEvent;
	import events.HttpEvent;
	import events.PlayerEvent;
	
	import net.DefinedPlayer;
	import net.HttpRequest;
	
	import org.flexlite.domCore.Injector;
	import org.flexlite.domUI.components.Group;
	import org.flexlite.domUI.core.Theme;
	import org.flexlite.domUI.managers.SystemManager;
	import org.flexlite.domUI.skins.themes.VectorTheme;
	
	import view.AdvertChart;
	import view.ControllBar;
	import view.LoadingBar;
	import view.Recommend;
	import view.TopBar;
	import view.VideoShare;
	import view.WaterMark;
	
	[SWF(width="482", height="355", frameRate="25", backgroundColor="#000000")]
	public class Main extends SystemManager
	{
		private const minW:Number = 482;
		private const minH:Number = 355;
		
		private var _frontContainer:Group;
		private var _behindContainer:Group;
		
		private var loadingBar:LoadingBar;
		private var advertChart:AdvertChart;
		private var videoScreen:VideoUI;
		private var topBar:TopBar;
		private var controllBar:ControllBar;
		private var recommend:Recommend;
		private var share:VideoShare;
		private var waterMark:WaterMark;
		
		private var definedPlayer:DefinedPlayer;
		private var playerUrl:String = "http://www.tvm.cn/weibo/get_data?url=www.tvm.cn/ishare/play/play.html?id=";
		private var _playerParams:Object={
			id:null//(mp4url)
		}
		
		private var _playerInfo:Object={
			url:null,//(mp4url)
			thumburl:null,//缩略图
			title:null,//标题
			summary:null,//总结
			swfUrl:null,//嵌入swf
			linksUrl:null//来源链接
		}
		private var IsPlayer:Boolean=true;//是否第一次播放
		public function Main()
		{
			super();
			
			Injector.mapClass(Theme,VectorTheme);
			//收藏页
			//navigateToURL( (new URLRequest("javascript:window.external.addFavorite('http://qq.com', '收藏名字')")), "_self");
			addEventListener(Event.ADDED_TO_STAGE, addedToStage);
			
			playerParams.id = this.loaderInfo.parameters.url;
			
			playerParams.id = 566389;
			
			_main = this;
		}
		
		private static var _main:Main

		public function get playerParams():Object
		{
			return _playerParams;
		}

		public function set playerParams(value:Object):void
		{
			_playerParams = value;
		}

		public static function get main():Main
		{
			return _main;
		}
		
		public function get frontContainer():Group
		{
			if(_frontContainer == null)
				_frontContainer = new Group();
			return _frontContainer;
		}
		
		public function get playerInfo():Object
		{
			return _playerInfo;	
		}
		
		public function get behindContainer():Group
		{
			if(_behindContainer == null)
				_behindContainer = new Group();
			return _behindContainer;
		}
		
		private function addedToStage(event:Event):void
		{
			requestPlayer();
			
			stage.addEventListener(FullScreenEvent.FULL_SCREEN,fullScreenChangeHandler);
			stage.addEventListener(Event.RESIZE, resizeHandler);
			
			addEventListener(MouseEvent.MOUSE_MOVE,userActiveHandler);
		}
		
		
		public function requestPlayer():void
		{
			var http:HttpRequest = new HttpRequest();
			http.addEventListener(HttpEvent.HTTPDATA_SUCCESS, complete);
			http.connect(playerUrl+playerParams.id);
		}
		
		private function ioError(event:Event):void
		{
			//			trace("请求视频源加载错误！！！");
		}
		
		private function complete(event:HttpEvent):void
		{
			var loader:URLLoader = event.data as URLLoader;
			var data:Object = JSON.parse(loader.data);
			
			playerInfo.title = data.display_name;
			playerInfo.url = data.stream.url;
			playerInfo.summary = data.summary;
			var u:String	= data.image.url;
//			playerInfo.thumburl = u.replace(/\s/g, "").split("\x00-\x20").join("");
//			playerInfo.thumburl = "";
			playerInfo.thumburl = u;
			
			playerInfo.swfUrl =data.embed_code;
			playerInfo.linksUrl = data.links.url;
			
//			if(definedPlayer == null)
			initPlayer();
		}
		
		private function initPlayer():void
		{
			if(playerInfo.url)
			{
				//				controllBar.updateProgressBarMaximum(playerParams.content.duration);
				
				definedPlayer = new DefinedPlayer(playerInfo.url, 0);
				videoScreen.attatchNetStream(definedPlayer.netStream);
			}
			
			definedPlayer.addEventListener(PlayerEvent.PLAYER_UPDATE, playerUpdate);
			definedPlayer.addEventListener(PlayerEvent.MEDIA_DURATION_UPDATE, durationUpdate);
			definedPlayer.addEventListener(PlayerEvent.PLAYER_BUFFER_UPDATE, bufferUpdate);
			definedPlayer.addEventListener(PlayerEvent.PLAYER_BUFFER_FULL, removeLoadBar);
			
			controllBar.addEventListener(PlayerEvent.CONTROLLBAR_UPDATE, controllBarUpdate);
			controllBar.addEventListener(PlayerEvent.CONTROLLBAR_PLAY, controllBarPlay);
			controllBar.addEventListener(PlayerEvent.VOLUME_UPDATE, volumeUpdate);
//			
			GlobalServer.addEventListener(GlobalServerEvent.VIDEO_SHARE_ADD, shareAdd);
			GlobalServer.addEventListener(GlobalServerEvent.VIDEO_SHARE_REMOVE, shareRemove);
			
			
			GlobalServer.addEventListener(GlobalServerEvent.PLAYER_PLAY_START, playerPlayStart);
			GlobalServer.addEventListener(GlobalServerEvent.PLAYER_PLAY_STOP, playerPlayStop);
			GlobalServer.addEventListener(GlobalServerEvent.PLAYER_SEEK_UPDATE, playerSeekUpdate);
			
			GlobalServer.addEventListener(GlobalServerEvent.RECOMMEND_PLAY, recommendPlay);
			
			GlobalServer.addEventListener(GlobalServerEvent.PLAYER_PLAY_PAUSE, playerPlayPause);
			
			definedPlayer.bufferTime = 30;
			definedPlayer.play();
			
			loadingBar.open();
			
			controllBar.playStatus = true;
//			playerStatus = !playerParams.auto_play;
//			
//			videoScreenChange();
//			if(ExternalInterface.available)
//			{
//				ExternalInterface.addCallback("seek", seekExternal);//秒
//			}
		}
		
		private function recommendPlay(event:GlobalServerEvent):void
		{
			playerParams.id = event.data;
			
			requestPlayer();
		}
		
		private var rateCount:int=0;
		private function playerUpdate(event:PlayerEvent):void
		{
			var object:Object = event.data;
			rateCount++;
			//call2js
			if(ExternalInterface.available)
			{
				ExternalInterface.call('updateTime', Number(object.time)*1000);
			}
			
			//			playLabel.text = "当前播放时间"+(Number(event.data));
			
			if(rateCount >= 10)
			{
				rateCount = 0;
				controllBar.updateProgressBarCur(Number(object.time));
				
				controllBar.updateLoadProgress(object.bytesProgress);
			}
		}
		
		private function durationUpdate(event:PlayerEvent):void
		{
//			if(!Boolean(int(playerParams.auto_play)) && IsPlayer)
//			{
//				definedPlayer.pause();
//				IsPlayer = false;				
//			}
			
			controllBar.updateProgressBarMaximum(Number(event.data));
			
			fullScreenChangeHandler(null);
		}
		
		private function bufferUpdate(event:PlayerEvent):void
		{
			var buffTime:Number = Number(event.data)%2;
			loadingBar.updateProgress(buffTime, 2);
		}
		
		private function removeLoadBar(event:PlayerEvent):void
		{
			loadingBar.close();
		}
		
		private function controllBarUpdate(event:PlayerEvent):void
		{
//			definedPlayer.seek(Number(event.data));
			playerSeek(Number(event.data));
		}
		
		private function playerSeekUpdate(event:GlobalServerEvent):void
		{
			playerSeek(Number(event.data));
		}
	
		private function playerSeek(value:Number):void
		{
			definedPlayer.seek(value);
		}
		
		private function controllBarPlay(event:PlayerEvent):void
		{
			playerPause();
		}
		
		private function volumeUpdate(event:PlayerEvent):void
		{
			definedPlayer.volume(Number(event.data));
		}
		
		private function playerPlayPause(event:GlobalServerEvent):void
		{
			playerPause();
		}
		
		private function playerPlayStart(event:GlobalServerEvent):void
		{
			recommend.close();
			
			fullScreenChangeHandler(null);
		}
		
		private function playerPlayStop(event:GlobalServerEvent):void
		{
			recommend.open();
		}
		
		private function shareAdd(event:GlobalServerEvent):void
		{
			share.open();
		}
		
		private function shareRemove(event:GlobalServerEvent):void
		{
		}
		
		private function clickPlayPause(event:MouseEvent):void
		{
			playerPause();
		}
		
		/**
		 *	播放器暂停播放 
		 */
		private function playerPause():void
		{
			if(definedPlayer == null)return;
			
			definedPlayer.pause();
			
			if(definedPlayer.playStatus)
			{
				share.close();
				advertChart.close();
			}
			else
			{
				if(!share.panel_open_status)
					advertChart.open();
			}
			
			controllBar.playStatus = definedPlayer.playStatus;
		}
		
		private var _userActive:Boolean;
		public function get userActive():Boolean
		{
			return _userActive;
		}
		
		public function set userActive(value:Boolean):void
		{
			if(_userActive !== value)
			{
				_userActive = value;
				
				showControllBar(userActive);
			}
		}
		
		//Hide&ShowAnimation
		private function showControllBar(userActive:Boolean):void
		{
			if(topBar)
			{
				TweenLite.killTweensOf(topBar);
				
				TweenLite.to(topBar, 1, {top:(userActive ? 0 : -topBar.height)});
			}
			
			if(controllBar)
			{
				TweenLite.killTweensOf(controllBar);
				
				TweenLite.to(controllBar, 1, {bottom:(userActive ? 0 : -controllBar.height-8)});
			}
		}
		
		//DeAcitvehandlerFun
		protected function userActiveHandler(event:MouseEvent):void
		{
			userActive = true;
			
			monitorDeactive();
		}
		
		//MonitorTiemoutID
		private var monitorId:int;
		
		//Monitor Controllbar Deative
		private function monitorDeactive():void
		{
			if(monitorId) clearTimeout(monitorId);
			
			monitorId = setTimeout(function():void
			{
				userActive = false;
			},2000);
		}
		
		private function resizeHandler(event:Event):void
		{
			fullScreenChangeHandler(null);
		}
		
		private function fullScreenChangeHandler(event:FullScreenEvent):void
		{
			if(!IsInit)return;
			if(definedPlayer == null)return;
			
			var mediaInfo:Object = definedPlayer.mediaInfo;
			if(mediaInfo == null || mediaInfo.height <= 0 || mediaInfo.width <= 0)return;
			
			var w:Number = stage.stageWidth;
			var h:Number = stage.stageHeight
			if(w < stage.fullScreenWidth)
				w = minW;
			if(h <stage.fullScreenHeight)
				h = minH;
			
			frontContainer.width = w;
			frontContainer.height = h;
			
			behindContainer.width = w;
			behindContainer.height = h;
			
			var perw:Number = w / mediaInfo.width;
			var perh:Number = h / mediaInfo.height;
			var scale:Number = perw < perh ? perw : perh;
			
			videoScreen.width = mediaInfo.width*scale;
			videoScreen.height = mediaInfo.height*scale;
			
			waterMark.right = (w-videoScreen.width)/2/*+waterMark.width*/;
			waterMark.top = (h-videoScreen.height)/2/*+waterMark.height*/;
			
			recommend.scaleWH(w, h);
		}
		
		private var IsInit:Boolean=false;
		override protected function createChildren():void
		{
			super.createChildren();
			
			videoScreen = new VideoUI();
//			videoScreen.percentHeight = videoScreen.percentWidth = 100;
			videoScreen.horizontalCenter = 0;
			videoScreen.verticalCenter = 0;
			addElement(videoScreen);
			videoScreen.buttonMode = true;
			videoScreen.addEventListener(MouseEvent.CLICK, clickPlayPause);
			
//			frontContainer.horizontalCenter = 0;
//			frontContainer.verticalCenter = 0;
			addElement(frontContainer);
			
			topBar = new TopBar();
			topBar.percentWidth = 100;
			topBar.height = 40;
			topBar.top = 0;
			addElement(topBar);
			
			loadingBar = new LoadingBar();
			loadingBar.horizontalCenter = 0;
			loadingBar.top = 40;
//			addElement(loadingBar);
//			loadingBarStatus = false;
			
			recommend = new Recommend();
			recommend.x = 0;
			recommend.y = 40;
//			recommend.open();
			
			controllBar = new ControllBar();
			controllBar.percentWidth = 100;
			controllBar.height = 40;
			controllBar.bottom = 0;
			addElement(controllBar);
			
//			behindContainer.horizontalCenter = 0;
//			behindContainer.verticalCenter = 0;
			addElement(behindContainer);
			
			advertChart = new AdvertChart();
			advertChart.horizontalCenter = 0;
			advertChart.verticalCenter = 0;
//			addElement(advertChart);
//			advertChartStatus = false;
			
			share = new VideoShare();
			share.horizontalCenter = 0;
			share.verticalCenter = 0;
//			addElement(share);
//			videoShare = false;
			waterMark = new WaterMark();
			waterMark.right = 15;
			waterMark.top = 15;
			waterMark.open();
			
			IsInit = true;
		}
	}
}