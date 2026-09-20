/*
 * @Description: wrap object
 * @Author: ekibun
 * @Date: 2020-10-02 13:49:03
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-03 22:21:31
 */
part of '../flutter_qjs.dart';

/// js invokable
abstract class JSInvokable extends JSRef {
  dynamic invoke(List args, [dynamic thisVal]);

  static dynamic _wrap(dynamic func) {
    return func is JSInvokable
        ? func
        : func is Function
            ? _DartFunction(func)
            : func;
  }
}

class _DartFunction extends JSInvokable {
  final Function _func;
  _DartFunction(this._func);

  @override
  invoke(List args, [thisVal]) {
    try {
      /// wrap this into function
      final passThis =
          RegExp('{.*thisVal.*}').hasMatch(_func.runtimeType.toString());
      return Function.apply(_func, args, passThis ? {#thisVal: thisVal} : null);
    } finally {
      JSRef.freeRecursive(args);
      JSRef.freeRecursive(thisVal);
    }
  }

  @override
  String toString() {
    return _func.toString();
  }

  @override
  destroy() {}
}

/// implement this to capture js object release.

class _DartObject extends JSRef implements JSRefLeakable {
  Object? _obj;
  Pointer<JSContext>? _ctx;
  int? id;
  _DartObject(Pointer<JSContext> ctx, dynamic obj) {
    _ctx = ctx;
    _obj = obj;
    if (obj is JSRef) obj.dup();
    id = runtimeOpaques[jsGetRuntime(ctx)]?.addDartObject(this);
  }

  static _DartObject? fromAddress(Pointer<JSRuntime> rt, int val) {
    // 0 is the "no opaque" sentinel QuickJS returns for non-DartObject
    // values; ids are never reused, so a hit must be a live _DartObject.
    if (val == 0) return null;
    final obj = runtimeOpaques[rt]?.getDartObject(val);
    return obj is _DartObject ? obj : null;
  }

  @override
  String toString() {
    if (_ctx == null) return "DartObject(released)";
    return _obj.toString();
  }

  @override
  void destroy() {
    final ctx = _ctx;
    final obj = _obj;
    _ctx = null;
    _obj = null;
    if (ctx == null) return;
    if (id != null) {
      runtimeOpaques[jsGetRuntime(ctx)]?.removeDartObject(id!);
    }
    if (obj is JSRef) obj.free();
  }
}

/// JS Error wrapper
class JSError extends _IsolateEncodable {
  late String message;
  late String stack;
  JSError(message, [stack]) {
    if (message is JSError) {
      this.message = message.message;
      this.stack = message.stack;
    } else {
      this.message = message.toString();
      this.stack = (stack ?? StackTrace.current).toString();
    }
  }

  @override
  String toString() {
    return stack.isEmpty ? message.toString() : "$message\n$stack";
  }

  static JSError? _decode(Map obj) {
    if (obj.containsKey(#jsError))
      return JSError(obj[#jsError], obj[#jsErrorStack]);
    return null;
  }

  @override
  Map _encode() {
    return {
      #jsError: message,
      #jsErrorStack: stack,
    };
  }
}

/// JS Object reference
/// call [release] to release js object.
class _JSObject extends JSRef {
  Pointer<JSValue>? _val;
  Pointer<JSContext>? _ctx;
  int? id;

  /// Create
  _JSObject(Pointer<JSContext> ctx, Pointer<JSValue> val) {
    this._ctx = ctx;
    final rt = jsGetRuntime(ctx);
    this._val = jsDupValue(ctx, val);
    id = runtimeOpaques[rt]?.addDartObject(this);
  }

  @override
  void destroy() {
    final ctx = _ctx;
    final val = _val;
    _val = null;
    _ctx = null;
    if (ctx == null || val == null) return;
    final rt = jsGetRuntime(ctx);
    if (id != null) {
      runtimeOpaques[rt]?.removeDartObject(id!);
    }
    jsFreeValue(ctx, val);
  }

  @override
  String toString() {
    if (_ctx == null || _val == null) return "JSObject(released)";
    return jsToCString(_ctx!, _val!);
  }
}

/// JS function wrapper
class _JSFunction extends _JSObject implements JSInvokable, _IsolateEncodable {
  _JSFunction(Pointer<JSContext> ctx, Pointer<JSValue> val) : super(ctx, val);

  @override
  invoke(List<dynamic> arguments, [dynamic thisVal]) {
    final jsRet = _invoke(arguments, thisVal);
    final ctx = _ctx!;
    try {
      bool isException = jsIsException(jsRet) != 0;
      if (isException) {
        throw _parseJSException(ctx);
      }
      return _jsToDart(ctx, jsRet);
    } finally {
      jsFreeValue(ctx, jsRet);
    }
  }

  Pointer<JSValue> _invoke(List<dynamic> arguments, [dynamic thisVal]) {
    final ctx = _ctx;
    final val = _val;
    if (ctx == null || val == null)
      throw JSError("InternalError: JSValue released");
    final args = <Pointer<JSValue>>[];
    Pointer<JSValue> jsThis;
    try {
      for (final e in arguments) {
        args.add(_dartToJs(ctx, e));
      }
      jsThis = _dartToJs(ctx, thisVal);
    } catch (e) {
      for (final a in args) {
        jsFreeValue(ctx, a);
      }
      rethrow;
    }
    try {
      final jsRet = jsCall(ctx, val, jsThis, args);
      return jsRet;
    } finally {
      jsFreeValue(ctx, jsThis);
      for (final jsArg in args) {
        jsFreeValue(ctx, jsArg);
      }
    }
  }

  @override
  Map _encode() {
    return IsolateFunction._new(this)._encode();
  }
}

/// Dart function wrapper for isolate
class IsolateFunction extends JSInvokable implements _IsolateEncodable {
  int? _isolateId;
  SendPort? _port;
  JSInvokable? _invokable;
  IsolateFunction._fromId(this._isolateId, this._port);

  static int _nextIsolateFunctionId = 0;

  IsolateFunction._new(this._invokable) {
    _isolateId = _nextIsolateFunctionId++;
    _handlers[_isolateId!] = this;
  }
  IsolateFunction(Function func) : this._new(_DartFunction(func));

  static ReceivePort? _invokeHandler;
  static Map<int, IsolateFunction> _handlers = {};

  static get _handlePort {
    if (_invokeHandler == null) {
      _invokeHandler = ReceivePort();
      _invokeHandler!.listen((msg) async {
        final msgPort = msg[#port];
        try {
          final handler = _handlers[msg[#handler]];
          if (handler == null) throw JSError('handler released');
          final ret = _encodeData(await handler._handle(msg[#msg]));
          if (msgPort != null) msgPort.send(ret);
        } catch (e) {
          final err = _encodeData(e);
          if (msgPort != null)
            msgPort.send({
              #error: err,
            });
        }
      });
    }
    return _invokeHandler!.sendPort;
  }

  _send(msg) async {
    final port = _port;
    if (port == null) return _handle(msg);
    final evaluatePort = ReceivePort();
    try {
      port.send({
        #handler: _isolateId,
        #msg: msg,
        #port: evaluatePort.sendPort,
      });
      final result = await evaluatePort.first;
      if (result is Map && result.containsKey(#error))
        throw _decodeData(result[#error]);
      return _decodeData(result);
    } finally {
      evaluatePort.close();
    }
  }

  _destroy() {
    if (_isolateId != null) {
      _handlers.remove(_isolateId);
    }
    _invokable?.free();
    _invokable = null;
  }

  _handle(msg) async {
    switch (msg) {
      case #dup:
        _refCount++;
        return null;
      case #free:
        _refCount--;
        if (_refCount < 0) _destroy();
        return null;
      case #destroy:
        _destroy();
        return null;
    }
    final List args = _decodeData(msg[#args]);
    final thisVal = _decodeData(msg[#thisVal]);
    return _invokable?.invoke(args, thisVal);
  }

  @override
  Future invoke(List positionalArguments, [thisVal]) async {
    final List dArgs = _encodeData(positionalArguments);
    final dThisVal = _encodeData(thisVal);
    return _send({
      #args: dArgs,
      #thisVal: dThisVal,
    });
  }

  static IsolateFunction? _decode(Map obj) {
    if (obj.containsKey(#jsFunctionPort))
      return IsolateFunction._fromId(
        obj[#jsFunctionId],
        obj[#jsFunctionPort],
      );
    return null;
  }

  @override
  Map _encode() {
    return {
      #jsFunctionId: _isolateId,
      #jsFunctionPort: _port ?? IsolateFunction._handlePort,
    };
  }

  int _refCount = 0;

  @override
  dup() {
    _send(#dup);
  }

  @override
  free() {
    _send(#free);
  }

  @override
  void destroy() {
    _send(#destroy);
  }
}
