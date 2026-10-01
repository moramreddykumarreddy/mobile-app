// lib/core/services/his_websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'auth_api_service.dart';
import 'session_menu_service.dart';

enum WsStatus {
  idle,
  connecting,
  open,
  closed,
  authError,
}

/// HIS WebSocket service for camp + dashboard realtime updates.
/// Replicates ApVisionCare.Portal (src/core/websocket/his-websocket.ts) 1:1.
///
/// Features:
/// - Strict Singleton instance across the application lifecycle.
/// - Clean reconnect semantics without background retry loops.
/// - Automatic re-subscription to active rooms (dashboards and camps) upon reconnect.
/// - `ValueNotifier<WsStatus>` for reactive UI badges.
class HisWebSocketService {
  static final HisWebSocketService _instance = HisWebSocketService._internal();
  factory HisWebSocketService() => _instance;
  HisWebSocketService._internal();

  static const String defaultWsUrl = 'wss://apihis.hmissupport.in/ws';
  static const int authCloseCode = 1008;

  WebSocket? _socket;
  StreamSubscription? _subscription;

  String? _userId;
  final ValueNotifier<WsStatus> statusNotifier = ValueNotifier<WsStatus>(WsStatus.idle);

  bool _closedByUs = false;
  int? _lastCloseCode;
  String _lastCloseReason = '';

  final Set<String> _camps = <String>{};
  final Set<String> _dashboards = <String>{};
  final Map<String, Set<void Function(dynamic)>> _handlers = {};

  WsStatus get status => statusNotifier.value;
  int? get lastCloseCode => _lastCloseCode;
  String get lastCloseReason => _lastCloseReason;
  String? get userId => _userId;
  bool get isConnected => status == WsStatus.open;

  void _setStatus(WsStatus next) {
    if (statusNotifier.value != next) {
      statusNotifier.value = next;
      debugPrint('⚡ [HisWebSocket] Status changed: $next');
    }
  }

  void _emit(String event, dynamic data) {
    final set = _handlers[event];
    if (set == null || set.isEmpty) return;
    for (final fn in List.from(set)) {
      try {
        fn(data);
      } catch (e, st) {
        debugPrint('⚠️ [HisWebSocket] Handler error for event "$event": $e\n$st');
      }
    }
  }

  /// Connect to HIS WebSocket with userId
  Future<void> connect({String? userId, bool force = false}) async {
    final resolvedId = userId ?? _userId ?? SessionMenuService().userId ?? SessionMenuService().username;
    if (resolvedId.trim().isEmpty) {
      debugPrint('⚠️ [HisWebSocket] Cannot connect: userId is empty.');
      return;
    }
    _userId = resolvedId.trim();

    // Already connected or connecting
    if (_socket != null &&
        (_socket!.readyState == WebSocket.open ||
            _socket!.readyState == WebSocket.connecting) &&
        !force) {
      if (_socket!.readyState == WebSocket.open && status != WsStatus.open) {
        _setStatus(WsStatus.open);
      }
      return;
    }

    await _open();
  }

  Future<void> _open() async {
    if (_userId == null || _userId!.isEmpty) return;

    // Clean up any existing socket
    await _closeInternal();

    _closedByUs = false;
    _setStatus(WsStatus.connecting);

    try {
      final uri = Uri.parse('$defaultWsUrl?userId=${Uri.encodeComponent(_userId!)}');
      debugPrint('🔌 [HisWebSocket] Connecting to: $uri');

      // The HIS WebSocket server requires an allowed Origin (http://localhost:3000) and session cookies
      final wsHeaders = <String, dynamic>{
        'Origin': 'http://localhost:3000',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      };

      final cookieStr = AuthApiService().cookieHeader;
      if (cookieStr.isNotEmpty) {
        wsHeaders['Cookie'] = cookieStr;
      }
      debugPrint('🔌 [HisWebSocket] Handshake cookies: ${AuthApiService().cookies.keys.toList()}');

      _socket = await WebSocket.connect(
        uri.toString(),
        headers: wsHeaders,
      ).timeout(const Duration(seconds: 12));

      _lastCloseCode = null;
      _lastCloseReason = '';

      _subscription = _socket!.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (err) {
          debugPrint('⚠️ [HisWebSocket] Stream error: $err');
          _onClosed(1006, err.toString());
        },
        onDone: () {
          final code = _socket?.closeCode;
          final reason = _socket?.closeReason ?? '';
          _onClosed(code, reason);
        },
        cancelOnError: true,
      );

      // 1. Re-subscribe to any rooms active prior to this connection
      final existingCamps = List<String>.from(_camps);
      final existingDashboards = List<String>.from(_dashboards);

      for (final campCode in existingCamps) {
        _send('join-camp', {'campCode': campCode});
      }
      for (final dashboard in existingDashboards) {
        _send('join-dashboard', {'dashboard': dashboard});
      }

      _setStatus(WsStatus.open);
      debugPrint('✅ [HisWebSocket] Connected successfully! Re-subscribed to ${existingCamps.length} camps, ${existingDashboards.length} dashboards.');
    } catch (e) {
      debugPrint('❌ [HisWebSocket] Connection error: $e');
      _socket = null;
      _setStatus(WsStatus.closed);
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final text = raw.toString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;

      final event = decoded['event']?.toString() ??
          decoded['type']?.toString() ??
          decoded['name']?.toString() ??
          '';

      if (event.isEmpty) return;

      final data = decoded.containsKey('data')
          ? decoded['data']
          : decoded.containsKey('payload')
              ? decoded['payload']
              : decoded;

      debugPrint('📨 [HisWebSocket] Event received: "$event"');
      _emit(event, data);
    } catch (e) {
      debugPrint('⚠️ [HisWebSocket] Malformed message: $e');
    }
  }

  void _onClosed(int? code, String reason) {
    debugPrint('🔌 [HisWebSocket] Disconnected: code=$code, reason="$reason"');
    _lastCloseCode = code;
    _lastCloseReason = reason;
    _socket = null;

    if (_closedByUs) {
      _setStatus(WsStatus.closed);
      return;
    }

    if (code == authCloseCode) {
      _setStatus(WsStatus.authError);
      return;
    }

    _setStatus(WsStatus.closed);
  }

  bool _send(String event, Map<String, dynamic> data) {
    if (_socket == null || _socket!.readyState != WebSocket.open) {
      return false;
    }
    try {
      final msg = jsonEncode({'event': event, 'data': data});
      _socket!.add(msg);
      debugPrint('📤 [HisWebSocket] Sent: $msg');
      return true;
    } catch (e) {
      debugPrint('⚠️ [HisWebSocket] Send failed for $event: $e');
      return false;
    }
  }

  /// Explicitly re-connect (e.g. pull-to-refresh or tap on reconnect badge)
  Future<void> reconnect() async {
    final uid = _userId ?? SessionMenuService().userId ?? SessionMenuService().username;
    if (uid.isEmpty) return;
    await connect(userId: uid, force: true);
  }

  /// Disconnect socket on sign-out
  Future<void> disconnect() async {
    _closedByUs = true;
    _userId = null;
    _camps.clear();
    _dashboards.clear();
    await _closeInternal();
    _setStatus(WsStatus.closed);
  }

  Future<void> _closeInternal() async {
    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    if (_socket != null) {
      try {
        await _socket!.close(WebSocketStatus.normalClosure);
      } catch (_) {}
      _socket = null;
    }
  }

  /// Join camp room (e.g. campCode 181)
  bool joinCamp(dynamic campCode) {
    final code = campCode?.toString().trim() ?? '';
    if (code.isEmpty) return false;
    if (_camps.contains(code)) return true;
    _camps.add(code);
    return _send('join-camp', {'campCode': code});
  }

  /// Leave camp room
  bool leaveCamp(dynamic campCode) {
    final code = campCode?.toString().trim() ?? '';
    if (code.isEmpty) return false;
    _camps.remove(code);
    return _send('leave-camp', {'campCode': code});
  }

  /// Join dashboard room (e.g. 'live-camp')
  bool joinDashboard(String dashboard) {
    final name = dashboard.trim();
    if (name.isEmpty) return false;
    if (_dashboards.contains(name)) return true;
    _dashboards.add(name);
    return _send('join-dashboard', {'dashboard': name});
  }

  /// Leave dashboard room
  bool leaveDashboard(String dashboard) {
    final name = dashboard.trim();
    if (name.isEmpty) return false;
    _dashboards.remove(name);
    return _send('leave-dashboard', {'dashboard': name});
  }

  /// Register an event listener (e.g. 'live-camp-update', 'patient-registered', 'emr-updated').
  /// Returns a VoidCallback to cleanly unsubscribe.
  VoidCallback on(String event, void Function(dynamic data) handler) {
    _handlers.putIfAbsent(event, () => <void Function(dynamic)>{});
    _handlers[event]!.add(handler);
    return () {
      _handlers[event]?.remove(handler);
    };
  }
}
