// Throwaway DevTools-protocol probe: launches headless Chrome, loads the app,
// reacts to console breadcrumbs in real time, screenshots the moment the
// dashboard's first frame appears, and detects renderer freezes/crashes.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String chromeExe =
    r'C:\Program Files\Google\Chrome\Application\chrome.exe';

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args[0] : 'http://127.0.0.1:8787';
  final port = 9300 + DateTime.now().millisecondsSinceEpoch % 500;
  final started = DateTime.now();

  void log(String msg) {
    final ms = DateTime.now().difference(started).inMilliseconds;
    print('[${ms}ms] $msg');
  }

  final proc = await Process.start(chromeExe, [
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--remote-debugging-port=$port',
    '--window-size=390,844',
    '--force-device-scale-factor=1',
    '--user-data-dir=${Directory.systemTemp.path}/cdp_${DateTime.now().millisecondsSinceEpoch}',
    'about:blank',
  ]);
  final chromeErr = <String>[];
  proc.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((l) {
    if (l.contains('hrome') && !l.contains('ERROR:google_apis')) {
      chromeErr.add(l);
    }
  });

  WebSocket? ws;
  WebSocket? browserWs;
  for (var i = 0; i < 60 && ws == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      final client = HttpClient();
      var req = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/json/list'),
      );
      var res = await req.close();
      var body = await res.transform(utf8.decoder).join();
      for (final t in jsonDecode(body) as List) {
        final m = Map<String, dynamic>.from(t as Map);
        if (m['type'] == 'page' && m['webSocketDebuggerUrl'] != null) {
          ws = await WebSocket.connect(m['webSocketDebuggerUrl'] as String);
          break;
        }
      }
      if (ws != null) {
        req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/json/version'),
        );
        res = await req.close();
        body = await res.transform(utf8.decoder).join();
        final v = Map<String, dynamic>.from(jsonDecode(body) as Map);
        final bUrl = v['webSocketDebuggerUrl'] as String?;
        if (bUrl != null) {
          browserWs = await WebSocket.connect(bUrl);
        }
      }
      client.close(force: true);
    } catch (_) {
      // retry
    }
  }
  if (ws == null) {
    log('CDP: could not connect');
    proc.kill();
    exit(1);
  }
  log('connected pageWs=${ws != null} browserWs=${browserWs != null}');

  var id = 0;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  var frozeAtMs = -1;
  var frameShotTaken = false;

  Future<Map<String, dynamic>> send(
    String method, [
    Map<String, dynamic> params = const {},
  ]) {
    final c = Completer<Map<String, dynamic>>();
    final i = ++id;
    pending[i] = c;
    ws!.add(jsonEncode({'id': i, 'method': method, 'params': params}));
    return c.future.timeout(const Duration(seconds: 20));
  }

  Future<void> shot(String name) async {
    try {
      final r = await send('Page.captureScreenshot', {'format': 'png'});
      File(name).writeAsBytesSync(base64Decode(r['data'] as String));
      log('saved $name');
    } catch (e) {
      log('shot failed $name');
    }
  }

  Future<void> takeFrameShot(String why) async {
    if (frameShotTaken) return;
    frameShotTaken = true;
    log('frame shot triggered by: $why');
    await shot('debug_frame.png');
  }

  /* ------------------------- browser-level tracing ------------------------ */

  var bId = 0;
  final bPending = <int, Completer<Map<String, dynamic>>>{};
  final traceEvents = <Map<String, dynamic>>[];
  var tracingComplete = false;

  Future<Map<String, dynamic>> sendB(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    if (browserWs == null) return <String, dynamic>{};
    final c = Completer<Map<String, dynamic>>();
    final i = ++bId;
    bPending[i] = c;
    browserWs!.add(jsonEncode({'id': i, 'method': method, 'params': params}));
    return c.future.timeout(const Duration(seconds: 10));
  }

  browserWs?.listen((data) {
    final m = jsonDecode(data as String) as Map<String, dynamic>;
    if (m.containsKey('id')) {
      final c = bPending.remove(m['id']);
      if (c == null) return;
      if (m.containsKey('result')) {
        c.complete(Map<String, dynamic>.from(m['result'] as Map));
      } else {
        c.completeError(m['error']);
      }
      return;
    }
    final method = m['method'];
    if (method == 'Tracing.dataCollected') {
      final v = (m['params'] as Map)['value'] as List?;
      if (v != null) {
        traceEvents.addAll(v.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } else if (method == 'Tracing.tracingComplete') {
      tracingComplete = true;
    }
  });

  ws!.listen((data) {
    final m = jsonDecode(data as String) as Map<String, dynamic>;
    if (m.containsKey('id')) {
      final c = pending.remove(m['id']);
      if (c == null) return;
      if (m.containsKey('result')) {
        c.complete(Map<String, dynamic>.from(m['result'] as Map));
      } else {
        c.completeError(m['error']);
      }
      return;
    }
    final method = m['method'] as String? ?? '';
    final params = Map<String, dynamic>.from(m['params'] as Map? ?? {});
    if (method == 'Runtime.consoleAPICalled') {
      final args = (params['args'] as List)
          .map((a) =>
              (a as Map)['value'] ??
              (a as Map)['description'] ??
              (a as Map)['type'] ??
              '')
          .join(' ');
      final type = params['type'];
      if (type == 'log' || type == 'error' || type == 'warning') {
        log('CONSOLE[$type]: $args');
      }
      if (args.contains('first frame')) {
        // Screenshot immediately — this is the moment before the freeze.
        unawaited(takeFrameShot(args));
      }
    } else if (method == 'Runtime.exceptionThrown') {
      final d = Map<String, dynamic>.from(
        params['exceptionDetails'] as Map? ?? {},
      );
      final ex = Map<String, dynamic>.from(d['exception'] as Map? ?? {});
      log('EXCEPTION: ${d['text']} ${ex['description'] ?? ex['value'] ?? ''}');
    } else if (method.contains('targetCrashed') ||
        method.contains('Target.targetCrashed')) {
      log('TARGET CRASHED: $method ${params}');
    } else if (method == 'Inspector.detached') {
      log('INSPECTOR DETACHED: ${params['reason']}');
    } else {
      log('EVENT $method');
    }
  });

  try {
    await send('Page.enable');
    await send('Runtime.enable');
    await send('Inspector.enable').catchError((_) => <String, dynamic>{});
    await send('Page.navigate', {'url': url});
    try {
      final tr = await sendB('Tracing.start', {
        'categories':
            'devtools.timeline,disabled-by-default-devtools.timeline,'
            'blink,user_timing,v8.execute',
      });
      log('tracing started browserWs=${browserWs != null} result=$tr');
    } catch (e) {
      log('tracing start failed: $e browserWs=${browserWs != null}');
    }
  } catch (e) {
    log('setup failed: $e');
    proc.kill(ProcessSignal.sigkill);
    exit(1);
  }

  // Poll every second: a successful evaluate proves the main thread runs.
  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    try {
      final r = await send('Runtime.evaluate', {
        'expression': 'document.title',
        'returnByValue': true,
      });
      final res = Map<String, dynamic>.from(r['result'] as Map? ?? {});
      if (i % 5 == 0) log('alive t=${i + 1}s title=${res['value']}');
    } catch (_) {
      frozeAtMs = DateTime.now().difference(started).inMilliseconds;
      log('FROZEN at t=${i + 1}s (evaluate timed out)');
      break;
    }
  }

  // Give in-flight console events a moment, then final screenshot attempt.
  await Future<void>.delayed(const Duration(seconds: 2));
  await shot('debug_final.png');

  // Stop tracing and dump what the main thread was doing.
  try {
    await sendB('Tracing.end');
  } catch (_) {}
  for (var i = 0; i < 20 && !tracingComplete; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  File('trace_tmp.json').writeAsStringSync(jsonEncode(traceEvents));
  log('trace events: ${traceEvents.length} complete=$tracingComplete');

  if (frozeAtMs < 0) {
    log('no freeze detected within poll window');
  }

  log('--- chrome stderr (last 10) ---');
  for (final l in chromeErr.skip(chromeErr.length > 10 ? chromeErr.length - 10 : 0)) {
    log(l);
  }

  proc.kill(ProcessSignal.sigkill);
  exit(0);
}
