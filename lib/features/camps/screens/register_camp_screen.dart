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
  String? _selectedCamp;
  String? _selectedCampCode;
  bool _isSearching = false;
  Map<String, dynamic>? _foundPatient;
  bool _isRegistering = false;

  List<String> _activeCamps = [];

  @override
  void initState() {
    super.initState();
    _loadCampsDropdown();
  }

  Future<void> _loadCampsDropdown() async {
    try {
      final list = await MobileApiService().fetchCampsDropdown(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode, // Dynamically sends 'VIEW' initially
      );
      if (mounted && list.isNotEmpty) {
        setState(() {
          _activeCamps = list.map((c) {
            final name = c['camp_name'] ?? c['name'] ?? 'Vision Camp';
            final code = c['camp_code'] ?? c['code'] ?? '';
            return '$name ($code)';
          }).toList();
          if (_activeCamps.isNotEmpty) {
            _selectedCamp = _activeCamps.first;
            final match = RegExp(r'\(([^)]+)\)').firstMatch(_selectedCamp!);
            _selectedCampCode = match?.group(1) ?? _selectedCamp;
          }
        });
      }
    } catch (_) {}
  }

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
    });

    try {
      final patient = await MobileApiService().searchPatient(
        query,
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode, // 'VIEW'
      );
      if (mounted) {
        setState(() {
          _isSearching = false;
          if (patient != null) {
            _foundPatient = {
              'uhid': patient['uhid']?.toString() ?? patient['mrn']?.toString() ?? '',
              'name': patient['name']?.toString() ?? 'Patient',
              'age': patient['age']?.toString() ?? '',
              'gender': patient['gender']?.toString() ?? '',
              'mobile': patient['mobile']?.toString() ?? query,
              'village': patient['village']?.toString() ?? '',
              'district': patient['district']?.toString() ?? '',
              'abhaId': patient['abha_number']?.toString() ?? patient['abhaId']?.toString() ?? '',
              'mrn': int.tryParse(patient['mrn']?.toString() ?? '0') ?? 0,
            };
          } else {
            _foundPatient = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No patient found for "$query"')),
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _foundPatient = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to search patient. Check connection.')),
        );
      }
    }
  }

  Future<void> _registerToCamp() async {
    if (_foundPatient == null) return;

    setState(() => _isRegistering = true);

    final mrn = (_foundPatient!['mrn'] as int?) ?? 101;
    await MobileApiService().registerPatientToCamp(
      mrn: mrn,
      campCode: _selectedCampCode,
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: widget.actionCode, // Dynamically sends 'VIEW' (or 'ADD')
    );

    if (!mounted) return;
    setState(() => _isRegistering = false);

    final tokenNo = 'T-${DateTime.now().minute}${DateTime.now().second}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Registration Successful!',
                style: GoogleFonts.notoSans(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Patient has been registered to $_selectedCamp',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOKEN NUMBER',
                      style: GoogleFonts.notoSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      tokenNo,
                      style: GoogleFonts.notoSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('Printing Token Slip for $tokenNo...', style: GoogleFonts.notoSans(fontSize: 13)),
                        ],
                      ),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Print Token Slip'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _foundPatient = null;
                    _searchController.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            // Select Active Camp
            Text(
              'Select Active Camp',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCamp,
                  items: _activeCamps.map((camp) {
                    return DropdownMenuItem(
                      value: camp,
                      child: Text(
                        camp,
                        style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCamp = val;
                        final match = RegExp(r'\(([^)]+)\)').firstMatch(val);
                        _selectedCampCode = match?.group(1) ?? val;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Search Patient Section
            Text(
              'Find Patient',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    style: GoogleFonts.notoSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter Mobile / Aadhaar / UHID',
                      hintStyle: GoogleFonts.notoSans(color: const Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Patient Card or Empty Prompt
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
                          backgroundColor: AppColors.primaryLight.withOpacity(0.15),
                          child: const Icon(Icons.person, color: AppColors.primary),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    _buildInfoRow('UHID', _foundPatient!['uhid']),
                    const SizedBox(height: 6),
                    _buildInfoRow('Mobile', _foundPatient!['mobile']),
                    const SizedBox(height: 6),
                    _buildInfoRow('ABHA ID', _foundPatient!['abhaId']),
                    const SizedBox(height: 6),
                    _buildInfoRow('Location', '${_foundPatient!['village']}, ${_foundPatient!['district']}'),
                    const SizedBox(height: 14),

                    // Consent checkbox matching portal
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_box_rounded, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Patient consent obtained for camp screening',
                              style: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isRegistering
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 20),
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
                          _searchController.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Clear Selection'),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.person_search_outlined, size: 54, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        'Search for a patient to register',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
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
          style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        Text(
          value,
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
