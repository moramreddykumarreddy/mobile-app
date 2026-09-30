// lib/features/camps/screens/register_camp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_drawer.dart';

class RegisterPatientToCampScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const RegisterPatientToCampScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 169,
    this.moduleId = 27,
    this.actionCode = 'VIEW',
  });

  @override
  State<RegisterPatientToCampScreen> createState() =>
      _RegisterPatientToCampScreenState();
}

class _RegisterPatientToCampScreenState
    extends State<RegisterPatientToCampScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _foundPatient;
  bool _isRegistering = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPatient() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundPatient = null;
      _searchResults = [];
    });

    try {
      final list = await MobileApiService().searchPatients(
        query,
        searchType: 'auto',
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode,
      );

      if (!mounted) return;

      setState(() {
        _isSearching = false;
        if (list.isEmpty) {
          _searchResults = [];
          _foundPatient = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No patient found for "$query"')),
          );
        } else if (list.length == 1) {
          _selectPatient(list.first);
        } else {
          // Multiple matching patients
          _searchResults = list;
          _foundPatient = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
          _foundPatient = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to search patient. Check connection.'),
          ),
        );
      }
    }
  }

  String _calculateAge(dynamic dobVal) {
    if (dobVal == null) return '';
    final str = dobVal.toString().trim();
    if (str.isEmpty) return '';
    try {
      final date = DateTime.tryParse(str);
      if (date != null) {
        final now = DateTime.now();
        int age = now.year - date.year;
        if (now.month < date.month ||
            (now.month == date.month && now.day < date.day)) {
          age--;
        }
        if (age >= 0 && age < 125) {
          return age.toString();
        }
      }
    } catch (_) {}
    return '';
  }

  void _selectPatient(Map<String, dynamic> raw) {
    setState(() {
      final ageCalculated = raw['age']?.toString() ?? _calculateAge(raw['dob']);
      final genderRaw = raw['gender']?.toString() ?? '';
      final genderDisplay = genderRaw == 'M' ? 'Male' : (genderRaw == 'F' ? 'Female' : genderRaw);

      _foundPatient = {
        'uhid': raw['uhid']?.toString() ?? raw['mrn']?.toString() ?? '',
        'name': raw['name']?.toString() ??
            '${raw['first_name'] ?? ''} ${raw['last_name'] ?? ''}'.trim(),
        'age': ageCalculated.isNotEmpty ? ageCalculated : '—',
        'gender': genderDisplay.isNotEmpty ? genderDisplay : '—',
        'mobile': raw['mobile']?.toString() ?? raw['phone']?.toString() ?? '—',
        'email': raw['email']?.toString() ?? '',
        'village': raw['village_name']?.toString() ??
            raw['village']?.toString() ??
            '',
        'district': raw['district_name']?.toString() ??
            raw['district']?.toString() ??
            '',
        'abhaId': raw['abha_number']?.toString() ??
            raw['abha_address']?.toString() ??
            raw['abhaId']?.toString() ??
            '',
        'mrn': int.tryParse(raw['mrn']?.toString() ?? '0') ?? 0,
        'raw': raw,
      };
      if (_foundPatient!['name'].isEmpty) {
        _foundPatient!['name'] = 'Patient';
      }
      _searchResults = [];
    });
  }

  Future<void> _registerToCamp() async {
    if (_foundPatient == null) return;

    setState(() => _isRegistering = true);

    final mrn = (_foundPatient!['mrn'] as int?) ?? 0;
    final res = await MobileApiService().registerPatientToCamp(
      mrn: mrn,
      campCode: null, // Active camp derived from backend staff session
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: widget.actionCode,
    );

    if (!mounted) return;
    setState(() => _isRegistering = false);

    // If API returned failure (e.g. 409 Conflict: Patient is already registered in this camp)
    if (res['success'] != true) {
      final msg = res['message']?.toString() ?? 'Failed to register patient to camp.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg,
                  style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626), // Error Red
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Extract real API response fields
    final apiMessage = (res['message'] ?? 'Patient registered in camp successfully').toString();
    final data = res['data'] is Map ? (res['data'] as Map) : null;
    final tokenNo = data?['token_no']?.toString();
    final fullName = data?['full_name']?.toString() ?? _foundPatient!['name'];

    // ONLY when registration is genuinely successful (200 / 201):
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              apiMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              fullName,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            if (tokenNo != null && tokenNo.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOKEN NUMBER',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tokenNo,
                      style: GoogleFonts.notoSans(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _foundPatient = null;
                  _searchResults = [];
                  _searchController.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Register Next Patient'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const StaffAppDrawer(currentRoute: '/portal/register-camp'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B)),
            onPressed: () {
              if (widget.onOpenDrawer != null) {
                widget.onOpenDrawer!();
              } else {
                Scaffold.of(ctx).openDrawer();
              }
            },
            tooltip: 'Open menu (☰)',
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register Patient to Camp',
              style: GoogleFonts.notoSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Camp Registration For Patient',
              style: GoogleFonts.notoSans(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find Patient',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),

            // Search input field with action button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    style: GoogleFonts.notoSans(fontSize: 14),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Enter Name, Mobile, ABHA, Email, or MRN',
                      hintStyle: GoogleFonts.notoSans(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xFF64748B), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _foundPatient = null;
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _searchPatient(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchPatient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(54, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search_rounded,
                          color: Colors.white, size: 22),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Multiple search results list (if > 1)
            if (_searchResults.length > 1 && _foundPatient == null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Found ${_searchResults.length} Matching Patients',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Tap to select',
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._searchResults.map((p) {
                final name = p['name']?.toString() ??
                    '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
                final mrn = p['mrn'] ?? p['uhid'] ?? '—';
                final age = p['age']?.toString() ?? _calculateAge(p['dob']);
                final gender = p['gender'] == 'M'
                    ? 'Male'
                    : (p['gender'] == 'F'
                        ? 'Female'
                        : (p['gender']?.toString() ?? '—'));
                final mobile = p['mobile'] ?? p['phone'] ?? '—';
                final abha = p['abha_number'] ?? p['abha_address'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                  child: InkWell(
                    onTap: () => _selectPatient(p),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.person_rounded,
                                color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isNotEmpty ? name : 'Patient',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'MRN: $mrn',
                                        style: GoogleFonts.notoSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${age.isNotEmpty ? '$age Y • ' : ''}$gender',
                                      style: GoogleFonts.notoSans(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '📞 $mobile${abha.toString().isNotEmpty ? ' • 🆔 $abha' : ''}',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _selectPatient(p),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Select',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            // Selected Patient Card ready for registration
            if (_foundPatient != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppColors.primaryLight.withOpacity(0.15),
                          child:
                              const Icon(Icons.person, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _foundPatient!['name'],
                                style: GoogleFonts.notoSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${_foundPatient!['age']} Yrs • ${_foundPatient!['gender']}',
                                style: GoogleFonts.notoSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Active',
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('MRN / UHID',
                        _foundPatient!['uhid']?.toString() ?? '—'),
                    const SizedBox(height: 6),
                    _buildInfoRow('Mobile',
                        _foundPatient!['mobile']?.toString() ?? '—'),
                    if (_foundPatient!['email'] != null &&
                        _foundPatient!['email'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow('Email', _foundPatient!['email'].toString()),
                    ],
                    if (_foundPatient!['abhaId'] != null &&
                        _foundPatient!['abhaId'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow(
                          'ABHA ID', _foundPatient!['abhaId'].toString()),
                    ],
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      'Location',
                      [
                        _foundPatient!['village'],
                        _foundPatient!['district']
                      ]
                          .where((s) => s != null && s.toString().isNotEmpty)
                          .join(', '),
                    ),
                    const SizedBox(height: 14),

                    // Consent checkbox matching portal
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_box_rounded,
                              color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Patient consent obtained for camp screening',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Register Button
                    ElevatedButton(
                      onPressed: _isRegistering ? null : _registerToCamp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004990),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRegistering
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.how_to_reg_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Register to Camp Session',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _foundPatient = null;
                          _searchResults = [];
                          _searchController.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Clear Selection'),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
            ] else if (_searchResults.isEmpty) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.person_search_outlined,
                          size: 54, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        'Search for a patient to register',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports Name, Mobile, ABHA, Email, or MRN',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSans(
              fontSize: 12, color: const Color(0xFF64748B)),
        ),
        Text(
          value.isNotEmpty ? value : '—',
          style: GoogleFonts.notoSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
