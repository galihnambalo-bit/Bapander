import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../utils/supabase_config.dart';

class CallListener extends StatefulWidget {
  final Widget child;
  const CallListener({super.key, required this.child});

  @override
  State<CallListener> createState() => _CallListenerState();
}

class _CallListenerState extends State<CallListener> with WidgetsBindingObserver {
  StreamSubscription<List<Map<String, dynamic>>>? _callSub;
  String? _currentUid;
  String? _activeCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = context.read<AuthService>();
    if (auth.currentUid != null) {
      if (state == AppLifecycleState.resumed) {
        auth.setOnlineStatus(true);
      } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        auth.setOnlineStatus(false);
      }
    }
  }

  void _updateSubscription(String? uid) {
    if (uid == _currentUid) return;
    _currentUid = uid;
    _callSub?.cancel();
    _activeCallId = null;
    if (uid == null) return;

    final callService = context.read<CallService>();
    _callSub = callService.incomingCallStream(uid).listen(_onIncomingCalls);
  }

  Future<void> _onIncomingCalls(List<Map<String, dynamic>> calls) async {
    if (!mounted) return;
    if (calls.isEmpty) {
      _activeCallId = null;
      return;
    }

    final ringingCall = calls.firstWhere(
      (c) => c['status'] == 'ringing',
      orElse: () => <String, dynamic>{},
    );
    if (ringingCall.isEmpty) {
      _activeCallId = null;
      return;
    }

    final callId = ringingCall['id']?.toString() ?? '';
    if (callId.isEmpty || callId == _activeCallId) return;
    _activeCallId = callId;

    final callerId = ringingCall['caller']?.toString() ?? '';
    if (callerId.isEmpty) return;

    final caller = await SupabaseConfig.client
        .from('users')
        .select('name,photo')
        .eq('id', callerId)
        .maybeSingle();
    if (!mounted) return;

    final callerName = caller?['name'] ?? 'Panggilan masuk';
    final callerPhoto = caller?['photo'] ?? '';

    final router = GoRouter.of(context);
    final targetLocation = '/incoming-call/$callId';
    if (router.location != targetLocation) {
      router.push(targetLocation, extra: {
        'callerName': callerName,
        'callerPhoto': callerPhoto,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.watch<AuthService>().currentUid;
    _updateSubscription(currentUid);
    return widget.child;
  }
}
