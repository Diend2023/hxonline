package hxonline.net;

#if air51
import air.net.WebSocket as AirWS;
import flash.events.WebSocketEvent;
import flash.utils.ByteArray;
import haxe.io.Bytes;

/**
 * 适配器：将 `air.net.WebSocket` 包装为 `haxe.net.WebSocket` 风格接口
 * 使得 Client.hx 无需改动即可使用 HARMAN AIR 51 的 WebSocket
 */
class AirWebSocket {
	public static function create(url:String, protocols:Array<String> = null, origin:String = null, debug:Bool = false):AirWebSocket {
		return new AirWebSocket(url, protocols, debug);
	}

	var _ws:AirWS;
	var _debug:Bool;
	var _url:String;

	public var onopen:Void->Void;
	public var onmessageString:String->Void;
	public var onmessageBytes:Bytes->Void;
	public var onclose:Dynamic->Void;
	public var onerror:Dynamic->Void;
	public var readyState(default, null):ReadyState;

	function new(url:String, protocols:Array<String>, debug:Bool) {
		_url = url;
		_debug = debug;
		readyState = Connecting;

		_ws = new AirWS();
		_ws.addEventListener(WebSocketEvent.DATA, _onData);

		if (debug)
			trace("[AirWebSocket] connecting to " + url);

		try {
			var vec:flash.Vector<String> = null;
			if (protocols != null && protocols.length > 0) {
				vec = new flash.Vector<String>(protocols.length);
				for (i in 0...protocols.length)
					vec[i] = protocols[i];
			}
			_ws.connect(url, vec);
		} catch (e:Dynamic) {
			if (debug)
				trace("[AirWebSocket] connect error: " + e);
			if (onerror != null)
				onerror(e);
		}
	}

	function _onData(e:WebSocketEvent):Void {
		if (readyState != Open) {
			readyState = Open;
			if (onopen != null)
				onopen();
		}

		var fmt = e.format;
		if (fmt == AirWS.fmtTEXT) {
			if (onmessageString != null)
				onmessageString(e.stringData);
		} else if (fmt == AirWS.fmtBINARY) {
			if (onmessageBytes != null) {
				var ba:ByteArray = e.data;
				if (ba != null) {
					var bytes = Bytes.ofData(ba);
					onmessageBytes(bytes);
				}
			}
		} else if (fmt == AirWS.fmtCLOSE) {
			if (_debug)
				trace("[AirWebSocket] received close frame, code: " + _ws.closeReason);
			_doClose();
		}
	}

	public function sendString(data:String):Void {
		if (_debug)
			trace("[AirWebSocket] sendString: " + data);
		try {
			_ws.sendMessage(AirWS.fmtTEXT, data);
		} catch (e:Dynamic) {
			if (onerror != null)
				onerror(e);
		}
	}

	public function sendBytes(data:Bytes):Void {
		try {
			// flash 平台上 BytesData = ByteArray，直接传入
			_ws.sendMessage(AirWS.fmtBINARY, data.getData());
		} catch (e:Dynamic) {
			if (onerror != null)
				onerror(e);
		}
	}

	public function close():Void {
		if (_debug)
			trace("[AirWebSocket] closing");
		_doClose();
	}

	function _doClose():Void {
		if (readyState == Closed)
			return;
		readyState = Closed;
		try {
			_ws.close(1000);
		} catch (e:Dynamic) {}
		if (onclose != null)
			onclose(null);
	}

	/** air.net.WebSocket 是事件驱动的，无需轮询 */
	public function process():Void {}
}

enum ReadyState {
	Connecting;
	Open;
	Closing;
	Closed;
}
#end
