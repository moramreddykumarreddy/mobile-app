// lib/features/patient/screens/register_patient_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_drawer.dart';
import '../../camps/screens/register_camp_screen.dart';

class RegisterPatientScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const RegisterPatientScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 180,
    this.moduleId = 29,
    this.actionCode = 'VIEW',
  });

  @override
  State<RegisterPatientScreen> createState() => _RegisterPatientScreenState();
}

class _RegisterPatientScreenState extends State<RegisterPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _mobileController = TextEditingController();
  final _idValueController = TextEditingController();
  final _addressController = TextEditingController();
  final _villageController = TextEditingController();
  final _pincodeController = TextEditingController();

  String _gender = 'Male';
  String _district = 'Guntur';
  String _state = 'Andhra Pradesh';
  String _idType = 'AADHAAR';
  bool _isSaving = false;
  bool _isLookingUpPincode = false;

  final List<String> _districts = [
    'Anakapalli',
    'Ananthapuramu',
    'Annamayya',
    'Bapatla',
    'Chittoor',
    'Dr. B.R. Ambedkar Konaseema',
    'East Godavari',
    'Eluru',
    'Guntur',
    'Kakinada',
    'Konaseema',
    'Krishna',
    'Kurnool',
    'Nandyal',
    'NTR',
    'Palnadu',
    'Parvathipuram Manyam',
    'Prakasam',
    'Sri Potti Sriramulu Nellore',
    'Sri Sathya Sai',
    'Srikakulam',
    'Tirupati',
    'Visakhapatnam',
    'Vizianagaram',
    'West Godavari',
    'YSR Kadapa',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    _idValueController.dispose();
    _addressController.dispose();
    _villageController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _lookupPincode(String pincode) async {
    if (pincode.trim().length != 6) return;
    setState(() => _isLookingUpPincode = true);
    try {
      final res = await MobileApiService().fetchPincodeDetails(pincode.trim());
      if (mounted && res != null) {
        setState(() {
          if (res['state_name'] != null) {
            _state = res['state_name'].toString();
          }
          final districts = res['districts'];
          if (districts is List && districts.isNotEmpty) {
            final first = districts.first;
            final dName = first is Map ? (first['district_name'] ?? first['name']) : first.toString();
            if (dName != null && dName.toString().isNotEmpty) {
              final match = _districts.firstWhere(
                (d) => d.toLowerCase() == dName.toString().toLowerCase(),
                orElse: () => _district,
              );
              _district = match;
            }
          }
          _isLookingUpPincode = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLookingUpPincode = false);
    }
  }

  Future<void> _submitPatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final age = int.tryParse(_ageController.text.trim()) ?? 30;
    final birthYear = DateTime.now().year - age;
    final dob = '$birthYear-01-01';

    final genderCode = _gender == 'Male' ? 'M' : (_gender == 'Female' ? 'F' : 'O');

    final payload = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim().isNotEmpty ? _lastNameController.text.trim() : 'Patient',
      'gender': genderCode,
      'dob': dob,
      'mobile': _mobileController.text.trim(),
      'identifier_type': _idType,
      'identifier_value': _idValueController.text.trim(),
      'address_line1': _addressController.text.trim(),
      'city': _villageController.text.trim(),
      'district': _district,
      'state': _state,
      'pincode': _pincodeController.text.trim(),
    };

    final res = await MobileApiService().registerPatient(
      payload,
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: 'ADD',
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final rawData = res['data'];
    final generatedUhid = rawData is Map
        ? (rawData['mrn'] ?? rawData['uhid'] ?? rawData['patient_id']?.toString())
        : null;
    final displayUhid = generatedUhid?.toString() ??
        'APVC-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF16A34A), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Patient Registered!',
              style: GoogleFonts.notoSans(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()} has been enrolled successfully into AP Vision Care.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'ASSIGNED MRN / UHID',
                    style: GoogleFonts.notoSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    displayUhid,
                    style: GoogleFonts.notoSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RegisterPatientToCampScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.how_to_reg_rounded, size: 18),
              label: const Text('Enroll into Camp Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _formKey.currentState!.reset();
                _firstNameController.clear();
                _lastNameController.clear();
                _ageController.clear();
                _mobileController.clear();
                _idValueController.clear();
                _addressController.clear();
                _villageController.clear();
                _pincodeController.clear();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
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
      drawer: const StaffAppDrawer(currentRoute: '/portal/register-patient'),
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
              'Register Patient',
              style: GoogleFonts.notoSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'New Patient Enrollment & Demographics',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Demographics Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // First & Last Name
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('First Name *'),
                              TextFormField(
                                controller: _firstNameController,
                                style: GoogleFonts.notoSans(fontSize: 14),
                                validator: (v) => (v == null || v.trim().length < 2)
                                    ? 'Enter first name'
                                    : null,
                                decoration: _buildInputDec('e.g. Ramesh', Icons.person_outline),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Last Name *'),
                              TextFormField(
                                controller: _lastNameController,
                                style: GoogleFonts.notoSans(fontSize: 14),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Enter last name'
                                    : null,
                                decoration: _buildInputDec('e.g. Kumar', Icons.person_outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Age & Gender Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Age (Yrs) *'),
                              TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.notoSans(fontSize: 14),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter age' : null,
                                decoration: _buildInputDec('e.g. 52', Icons.cake_outlined),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Gender *'),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _gender,
                                    items: ['Male', 'Female', 'Other'].map((g) {
                                      return DropdownMenuItem(
                                        value: g,
                                        child: Text(
                                          g,
                                          style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w600),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _gender = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Mobile Number
                    _buildLabel('Mobile Number *'),
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: GoogleFonts.notoSans(fontSize: 14),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter mobile number';
                        if (v.trim().length != 10) return 'Enter valid 10-digit mobile number';
                        return null;
                      },
                      decoration: _buildInputDec('10-digit mobile number', Icons.phone_outlined, prefixText: '+91 '),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Identity & ABHA Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identity & Identification',
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('ID Type'),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _idType,
                                    items: [
                                      'AADHAAR',
                                      'PAN',
                                      'VOTER_ID',
                                      'PASSPORT',
                                      'DRIVING_LICENSE',
                                    ].map((t) {
                                      return DropdownMenuItem(
                                        value: t,
                                        child: Text(t, style: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w700)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _idType = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('ID Number *'),
                              TextFormField(
                                controller: _idValueController,
                                style: GoogleFonts.notoSans(fontSize: 14),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter ID number';
                                  if (_idType == 'AADHAAR' && v.trim().length != 12) {
                                    return 'Aadhaar must be 12 digits';
                                  }
                                  return null;
                                },
                                decoration: _buildInputDec('ID number value', Icons.badge_outlined),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Address & Location Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Address & Location',
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pincode with Auto-Lookup
                    _buildLabel('Pincode *'),
                    TextFormField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: GoogleFonts.notoSans(fontSize: 14),
                      onChanged: (val) {
                        if (val.trim().length == 6) {
                          _lookupPincode(val.trim());
                        }
                      },
                      validator: (v) => (v == null || v.trim().length != 6) ? 'Enter valid 6-digit pincode' : null,
                      decoration: InputDecoration(
                        hintText: 'e.g. 522001',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.pin_drop_outlined, color: Color(0xFF94A3B8), size: 20),
                        suffixIcon: _isLookingUpPincode
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Street Address
                    _buildLabel('Address Line 1 *'),
                    TextFormField(
                      controller: _addressController,
                      style: GoogleFonts.notoSans(fontSize: 14),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter street address' : null,
                      decoration: _buildInputDec('House no., Street, Landmark', Icons.home_outlined),
                    ),
                    const SizedBox(height: 14),

                    // Village / City
                    _buildLabel('Village / City / Mandal *'),
                    TextFormField(
                      controller: _villageController,
                      style: GoogleFonts.notoSans(fontSize: 14),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter village / city' : null,
                      decoration: _buildInputDec('e.g. Mangalagiri', Icons.holiday_village_outlined),
                    ),
                    const SizedBox(height: 14),

                    // District Dropdown
                    _buildLabel('District (AP) *'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _districts.contains(_district) ? _district : _districts.first,
                          items: _districts.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text(
                                d,
                                style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _district = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSaving ? null : _submitPatient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Register Patient in Database',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.notoSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _buildInputDec(String hint, IconData icon, {String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
      hintStyle: GoogleFonts.notoSans(color: const Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
