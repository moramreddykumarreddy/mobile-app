// lib/features/camps/screens/live_camp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/auth_api_service.dart';
import '../../../core/services/his_websocket_service.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_bar.dart';
import '../../../core/widgets/staff_app_drawer.dart';
import '../../../core/widgets/staff_bottom_nav_bar.dart';

class LiveCampScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const LiveCampScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 255,
    this.moduleId = 43,
    this.actionCode = 'VIEW',
  });

  @override
  State<LiveCampScreen> createState() => _LiveCampScreenState();
}

class _LiveCampScreenState extends State<LiveCampScreen> {
  final HisWebSocketService _ws = HisWebSocketService();
  final List<VoidCallback> _wsUnsubscribers = [];

  bool _isLoading = true;
  List<Map<String, dynamic>> _campList = [];
  dynamic _selectedCampCode;
  Map<String, dynamic>? _activeCamp = {
    'campName': 'Eluru Eluru Rural eluru Eye Camp',
    'distName': 'Eluru',
    'mandalName': null,
    'teamName': 'Eluru team',
    'patientLimit': 100,
    'startTime': '2026-08-19T00:00:00.000Z',
    'registeredToday': 0,
    'screened': 0,
    'inQueue': 0,
    'referredOut': 0,
    'redFlags': 0,
    'avgWaitMins': 0,
    'avgScreenMins': 0,
    'capacityPct': 0,
    'snapshotOn': '2026-10-01T06:00:00.059Z',
  };
  List<dynamic> _liveQueue = [];

  @override
  void initState() {
    super.initState();
    _loadLiveDashboard();
    _initRealtime();
  }

  @override
  void reassemble() {
    super.reassemble();
    _loadLiveDashboard();
    _initRealtime();
  }

  @override
  void dispose() {
    for (final unsub in _wsUnsubscribers) {
      unsub();
    }
    _wsUnsubscribers.clear();
    if (_selectedCampCode != null) {
      _ws.leaveCamp(_selectedCampCode);
    }
    _ws.leaveDashboard('live-camp');
    super.dispose();
  }

  Future<void> _initRealtime() async {
    final uid = await AuthApiService().ensureUserId();
    if (uid != null && uid.isNotEmpty) {
      await _ws.connect(userId: uid);
    } else {
      await _ws.connect();
    }

    _ws.joinDashboard('live-camp');
    if (_selectedCampCode != null) {
      _ws.joinCamp(_selectedCampCode);
    }

    for (final unsub in _wsUnsubscribers) {
      unsub();
    }
    _wsUnsubscribers.clear();

    _wsUnsubscribers.add(_ws.on('live-camp-update', _onLiveCampUpdate));
    _wsUnsubscribers.add(_ws.on('patient-registered', (data) {
      debugPrint('⚡ [LiveCampScreen] Realtime: patient-registered event received');
      if (mounted) {
        _loadLiveDashboard(silent: true);
      }
    }));
    _wsUnsubscribers.add(_ws.on('emr-updated', (data) {
      debugPrint('⚡ [LiveCampScreen] Realtime: emr-updated event received');
      if (mounted) {
        _loadLiveDashboard(silent: true);
      }
    }));
  }

  void _onLiveCampUpdate(dynamic data) {
    debugPrint('⚡ [LiveCampScreen] Realtime: live-camp-update received: $data');
    if (!mounted) return;

    List<dynamic> rows = [];
    if (data is List) {
      rows = data;
    } else if (data is Map) {
      if (data['data'] is List) {
        rows = data['data'] as List;
      } else if (data['camps'] is List) {
        rows = data['camps'] as List;
      } else {
        rows = [data];
      }
    }

    if (rows.isEmpty) return;

    final currentCode = _selectedCampCode?.toString();
    Map<String, dynamic>? matchingCamp;

    for (final r in rows) {
      if (r is Map) {
        final code = (r['campCode'] ?? r['camp_code'])?.toString();
        final idx = _campList.indexWhere(
          (c) => (c['campCode'] ?? c['camp_code'])?.toString() == code,
        );
        if (idx != -1) {
          _campList[idx] = {..._campList[idx], ...Map<String, dynamic>.from(r)};
        }

        if (currentCode != null && code == currentCode) {
          matchingCamp = Map<String, dynamic>.from(r);
        }
      }
    }

    if (matchingCamp != null) {
      setState(() {
        _activeCamp = {
          if (_activeCamp != null) ..._activeCamp!,
          ...matchingCamp!,
        };
      });
    }
  }

  int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? fallback;
  }

  String _formatStartTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'pm' : 'am';
      return '$hour:$minute $period';
    } catch (_) {
      return '05:30 am';
    }
  }

  String _formatSnapshot(String? iso) {
    if (iso == null || iso.isEmpty) return 'Just now';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'pm' : 'am';
      return '$day $month, $hour:$minute $period';
    } catch (_) {
      return 'Just now';
    }
  }

  Future<void> _loadLiveDashboard({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final res = await MobileApiService().fetchLiveCampDashboard(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode,
      );

      debugPrint('[LiveCampScreen] _loadLiveDashboard response: $res');

      if (mounted) {
        setState(() {
          if (res['success'] == true) {
            final rawCamps = res['camps'];
            if (rawCamps is List && rawCamps.isNotEmpty) {
              _campList = rawCamps
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }

            if (res['camp'] is Map) {
              final first = Map<String, dynamic>.from(res['camp'] as Map);
              if (_campList.isEmpty) {
                _campList = [first];
              }
              _activeCamp = first;
            }

            if (_campList.isNotEmpty) {
              final oldCampCode = _selectedCampCode;
              _selectedCampCode ??=
                  _campList.first['campCode'] ?? _campList.first['camp_code'];
              _activeCamp = _campList.firstWhere(
                (c) =>
                    _selectedCampCode != null &&
                    (c['campCode'] ?? c['camp_code']).toString() ==
                        _selectedCampCode.toString(),
                orElse: () => _campList.first,
              );

              if (_selectedCampCode != null && _selectedCampCode != oldCampCode) {
                if (oldCampCode != null) {
                  _ws.leaveCamp(oldCampCode);
                }
                _ws.joinCamp(_selectedCampCode);
              }
            }

            final queue = res['queue'];
            if (queue is List) {
              _liveQueue = queue;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('LiveCampScreen _loadLiveDashboard error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final camp = _activeCamp ?? {};
    final campName = camp['campName']?.toString() ??
        camp['camp_name']?.toString() ??
        camp['name']?.toString() ??
        'Eluru Eluru Rural eluru Eye Camp';
    final distName = camp['distName']?.toString() ??
        camp['dist_name']?.toString() ??
        camp['district']?.toString() ??
        'Eluru';
    final mandalName = camp['mandalName']?.toString() ??
        camp['mandal_name']?.toString() ??
        camp['mandal']?.toString();
    final teamName = camp['teamName']?.toString() ??
        camp['team_name']?.toString() ??
        camp['team']?.toString() ??
        'Eluru team';
    final patientLimit = _parseInt(camp['patientLimit'] ?? camp['patient_limit'], 100);
    final screened = _parseInt(camp['screened'] ?? camp['screened_count'], 0);
    final registeredToday = _parseInt(camp['registeredToday'] ?? camp['registered_today'], 0);
    final inQueue = _parseInt(camp['inQueue'] ?? camp['in_queue'], 0);
    final referredOut = _parseInt(camp['referredOut'] ?? camp['referred_out'], 0);
    final redFlags = _parseInt(camp['redFlags'] ?? camp['red_flags'], 0);
    final avgWaitMins = _parseInt(camp['avgWaitMins'] ?? camp['avg_wait_mins'], 0);
    final avgScreenMins = _parseInt(camp['avgScreenMins'] ?? camp['avg_screen_mins'], 0);
    final capacityPct = _parseInt(camp['capacityPct'] ?? camp['capacity_pct'], 0);
    final startTimeStr = camp['startTime']?.toString() ?? camp['start_time']?.toString();
    final snapshotOnStr = camp['snapshotOn']?.toString() ?? camp['snapshot_on']?.toString();

    final formattedStart = _formatStartTime(startTimeStr);
    final formattedUpdated = _formatSnapshot(snapshotOnStr);
    final tokensText = registeredToday == 0 ? 'No tokens yet' : '$registeredToday tokens issued';
    final progressValue = patientLimit > 0
        ? (screened / patientLimit).clamp(0.0, 1.0)
        : (capacityPct / 100.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const StaffAppDrawer(currentRoute: '/portal/live-camp'),
      bottomNavigationBar: const StaffBottomNavBar(currentRoute: '/portal/live-camp'),
      appBar: StaffAppBar(onOpenDrawer: widget.onOpenDrawer),
      body: RefreshIndicator(
        onRefresh: () async {
          _ws.reconnect();
          await _loadLiveDashboard();
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 3),
                ),

              // Top Breadcrumb & Status line (Eluru · in progress)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        distName,
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '·',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'in progress',
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  if (_campList.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<dynamic>(
                          value: _selectedCampCode,
                          isDense: true,
                          items: _campList.map((c) {
                            final code = c['campCode'] ?? c['camp_code'];
                            final name = c['campName'] ?? c['camp_name'] ?? 'Camp';
                            return DropdownMenuItem<dynamic>(
                              value: code,
                              child: Text(
                                name.toString(),
                                style: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              if (_selectedCampCode != null && _selectedCampCode != val) {
                                _ws.leaveCamp(_selectedCampCode);
                              }
                              setState(() {
                                _selectedCampCode = val;
                                _activeCamp = _campList.firstWhere(
                                  (c) => (c['campCode'] ?? c['camp_code']) == val,
                                  orElse: () => _campList.first,
                                );
                              });
                              _ws.joinCamp(val);
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Active Camp Dark Navy Hero Card (1:1 Web-matched style for mobile)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF002B49), Color(0xFF001F38)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF002B49).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge: ACTIVE CAMP
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF38BDF8).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'ACTIVE CAMP',
                            style: GoogleFonts.notoSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF38BDF8),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        ValueListenableBuilder<WsStatus>(
                          valueListenable: _ws.statusNotifier,
                          builder: (context, status, _) {
                            Color dotColor;
                            String statusText;
                            switch (status) {
                              case WsStatus.open:
                                dotColor = const Color(0xFF4ADE80);
                                statusText = 'Live Sync';
                                break;
                              case WsStatus.connecting:
                                dotColor = const Color(0xFFFBBF24);
                                statusText = 'Connecting…';
                                break;
                              case WsStatus.closed:
                                dotColor = const Color(0xFF94A3B8);
                                statusText = 'Offline · Tap';
                                break;
                              case WsStatus.authError:
                                dotColor = const Color(0xFFF87171);
                                statusText = 'Auth Err';
                                break;
                              case WsStatus.idle:
                                dotColor = const Color(0xFF94A3B8);
                                statusText = 'Idle';
                                break;
                            }

                            return GestureDetector(
                              onTap: () {
                                if (status != WsStatus.open) {
                                  _ws.reconnect();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: dotColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      statusText,
                                      style: GoogleFonts.notoSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Camp Title
                    Text(
                      campName,
                      style: GoogleFonts.notoSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Subtitle: District: Eluru · Mandal: — · Eluru team
                    Text(
                      'District: $distName · Mandal: ${mandalName != null && mandalName.toString().trim().isNotEmpty ? mandalName : '—'} · $teamName',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // Started & Tokens & Snapshot line
                    Text(
                      'Started $formattedStart · $tokensText · Last updated $formattedUpdated',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withOpacity(0.12), height: 1),
                    const SizedBox(height: 14),

                    // Screened / Limit Numbers & Capacity Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$screened',
                              style: GoogleFonts.notoSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Screened',
                              style: GoogleFonts.notoSans(
                                fontSize: 11.5,
                                color: Colors.white.withOpacity(0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '/',
                                style: GoogleFonts.notoSans(
                                  fontSize: 20,
                                  color: Colors.white.withOpacity(0.35),
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                            Text(
                              '$patientLimit',
                              style: GoogleFonts.notoSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Limit',
                              style: GoogleFonts.notoSans(
                                fontSize: 11.5,
                                color: Colors.white.withOpacity(0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$capacityPct% capacity',
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Capacity Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressValue,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Avg wait 0 min · Avg screen 0 min
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Avg wait $avgWaitMins min · Avg screen $avgScreenMins min',
                          style: GoogleFonts.notoSans(
                            fontSize: 11.5,
                            color: Colors.white.withOpacity(0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5 Metric Cards (Matching Web App Pastel Theme, 2-column grid + full alert card)
              Row(
                children: [
                  Expanded(
                    child: _buildWebMetricCard(
                      label: 'REGISTERED TODAY',
                      value: '$registeredToday',
                      icon: Icons.people_alt_outlined,
                      headerColor: const Color(0xFF0369A1),
                      borderColor: const Color(0xFFBAE6FD),
                      bgColor: const Color(0xFFF0F9FF),
                      iconColor: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildWebMetricCard(
                      label: 'SCREENED',
                      value: '$screened',
                      icon: Icons.how_to_reg_outlined,
                      headerColor: const Color(0xFF059669),
                      borderColor: const Color(0xFFA7F3D0),
                      bgColor: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildWebMetricCard(
                      label: 'IN QUEUE',
                      value: '$inQueue',
                      icon: Icons.access_time_rounded,
                      headerColor: const Color(0xFFD97706),
                      borderColor: const Color(0xFFFDE68A),
                      bgColor: const Color(0xFFFFFBEB),
                      iconColor: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildWebMetricCard(
                      label: 'REFERRED OUT',
                      value: '$referredOut',
                      icon: Icons.assignment_return_outlined,
                      headerColor: const Color(0xFFEA580C),
                      borderColor: const Color(0xFFFED7AA),
                      bgColor: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 5th Card: RED-FLAG ALERTS (Full Width)
              _buildWebMetricCard(
                label: 'RED-FLAG ALERTS',
                value: '$redFlags',
                icon: Icons.warning_amber_rounded,
                headerColor: const Color(0xFFE11D48),
                borderColor: const Color(0xFFFECDD3),
                bgColor: const Color(0xFFFFF1F2),
                iconColor: const Color(0xFFE11D48),
                isFullWidth: true,
              ),

              const SizedBox(height: 24),

              // Live Patient Queue Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Live Patient Queue',
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _liveQueue.isEmpty
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_liveQueue.length} Active',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _liveQueue.isEmpty
                            ? const Color(0xFF64748B)
                            : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Queue List or Empty State
              if (_liveQueue.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.queue_rounded,
                          size: 26,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No patients currently in live queue',
                        style: GoogleFonts.notoSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registered patients will appear here in real-time as they enter triage, refraction, and doctor consultation.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          fontSize: 11.5,
                          color: const Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _liveQueue.length,
                  itemBuilder: (context, index) {
                    final item = _liveQueue[index] is Map ? _liveQueue[index] as Map : {};
                    final token = item['token']?.toString() ??
                        item['token_no']?.toString() ??
                        'T-${index + 1}';
                    final name = item['patientName']?.toString() ??
                        item['patient_name']?.toString() ??
                        item['name']?.toString() ??
                        'Patient';
                    final age = item['age']?.toString() ?? '';
                    final gender = item['gender']?.toString() ?? '';
                    final stage = item['stage']?.toString() ??
                        item['status']?.toString() ??
                        'In Queue';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              token,
                              style: GoogleFonts.notoSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                if (age.isNotEmpty || gender.isNotEmpty)
                                  Text(
                                    '$age Yrs • $gender',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              stage,
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: index * 60));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Metric Card matching the Web Design with soft pastel background, colored border, and clean typography
  Widget _buildWebMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color headerColor,
    required Color borderColor,
    required Color bgColor,
    required Color iconColor,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.notoSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: headerColor,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(
                icon,
                size: 18,
                color: iconColor.withOpacity(0.85),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.notoSans(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
