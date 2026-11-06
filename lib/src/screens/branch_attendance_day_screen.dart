import 'dart:async';
import 'package:flutter/material.dart';
import '../models/branch_attendance_model.dart';
import '../services/branch_attendance_service.dart';
import '../services/language_manager.dart';
import '../widgets/translated_text.dart';

/// One editable row on the day-entry form.
class _EntryRow {
  final int employeeId;
  final String name;
  final String designation;

  /// True only for rows the incharge added via search in this session.
  /// Those (and only those) may be removed before saving.
  final bool isAdded;

  // API-facing values (what POST /mark receives).
  String status; // '' | present | absent
  String ot; // '' | Half Day | Full Day

  _EntryRow({
    required this.employeeId,
    required this.name,
    required this.designation,
    required this.isAdded,
    this.status = BranchStatus.none,
    this.ot = BranchOt.none,
  });

  /// The single dropdown value shown to the user (see [_Choice]).
  String get choice {
    if (status == BranchStatus.absent) return _Choice.absent;
    if (status == BranchStatus.present) {
      if (ot == BranchOt.halfDay) return _Choice.halfOt;
      if (ot == BranchOt.fullDay) return _Choice.fullOt;
      return _Choice.present;
    }
    return _Choice.none;
  }

  /// Maps the dropdown choice back to attendance_type + ot_type.
  /// OT choices mean "present" with that OT, matching the server's rule that
  /// OT only applies to present.
  void applyChoice(String c) {
    switch (c) {
      case _Choice.present:
        status = BranchStatus.present;
        ot = BranchOt.none;
      case _Choice.absent:
        status = BranchStatus.absent;
        ot = BranchOt.none;
      case _Choice.halfOt:
        status = BranchStatus.present;
        ot = BranchOt.halfDay;
      case _Choice.fullOt:
        status = BranchStatus.present;
        ot = BranchOt.fullDay;
      default:
        status = BranchStatus.none;
        ot = BranchOt.none;
    }
  }
}

/// Options of the single attendance dropdown.
class _Choice {
  static const String none = '';
  static const String present = 'present';
  static const String absent = 'absent';
  static const String halfOt = 'half_ot';
  static const String fullOt = 'full_ot';

  /// value -> label (insertion order = dropdown order)
  static const Map<String, String> labels = {
    none: 'Select',
    present: 'Present',
    absent: 'Absent',
    halfOt: 'Half Day OT',
    fullOt: 'Full Day OT',
  };

  static Color color(String c) {
    switch (c) {
      case present:
        return const Color(0xFF16A34A);
      case absent:
        return const Color(0xFFDC2626);
      case halfOt:
      case fullOt:
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFF64748B);
    }
  }
}

/// Screen 2 - day entry form. Pops with the saved [DateTime] on success.
class BranchAttendanceDayScreen extends StatefulWidget {
  final DateTime initialDate;

  const BranchAttendanceDayScreen({super.key, required this.initialDate});

  @override
  State<BranchAttendanceDayScreen> createState() =>
      _BranchAttendanceDayScreenState();
}

class _BranchAttendanceDayScreenState extends State<BranchAttendanceDayScreen> {
  final _service = BranchAttendanceService();

  late DateTime _date;
  List<_EntryRow> _rows = [];
  String _zone = '';
  String _branchName = '';

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  bool _dirty = false;
  int _loadToken = 0; // ignore out-of-order GET /day responses

  @override
  void initState() {
    super.initState();
    _date = DateUtils.dateOnly(widget.initialDate);
    _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchDay(_date);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _zone = data.zone;
        _branchName = data.branchName;
        _rows = data.employees
            .map((e) => _EntryRow(
                  employeeId: e.employeeId,
                  name: e.employeeName,
                  designation: e.designation,
                  isAdded: false,
                  status: e.status,
                  ot: e.otType,
                ))
            .toList();
        _dirty = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      if (handleBranchAttendanceAuthError(context, e)) return;
      setState(() {
        _error = branchErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------- helpers

  String _displayDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  String _t(String s) => LanguageManager.instance.translateSync(s);

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xFFB91C1C) : null,
        ),
      );
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const TranslatedText('Discard changes?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const TranslatedText(
            'You have unsaved attendance changes that will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const TranslatedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC91115),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const TranslatedText('Discard'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------------------------------------------------------------- actions

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    final next = DateUtils.dateOnly(picked);
    if (next == _date) return;
    if (!await _confirmDiscard()) return;
    setState(() => _date = next);
    _load();
  }

  void _setChoice(_EntryRow row, String? value) {
    if (value == null) return;
    setState(() {
      row.applyChoice(value);
      _dirty = true;
    });
  }

  Future<void> _addEmployee() async {
    final picked = await showModalBottomSheet<BranchEmployeeSearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EmployeeSearchSheet(
        service: _service,
        excludeIds: _rows.map((r) => r.employeeId).toSet(),
      ),
    );
    if (picked == null || !mounted) return;
    if (_rows.any((r) => r.employeeId == picked.id)) return;
    setState(() {
      _rows.add(_EntryRow(
        employeeId: picked.id,
        name: picked.name,
        designation: picked.designation,
        isAdded: true,
      ));
      _dirty = true;
    });
  }

  void _removeRow(_EntryRow row) {
    if (!row.isAdded) return; // pre-assigned teammates are never removable
    setState(() {
      _rows.remove(row);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    // Every row with a valid employee_id is sent; blank attendance goes as ""
    // and the server skips it.
    final entries = _rows
        .where((r) => r.employeeId > 0)
        .map((r) => BranchMarkEntry(
              employeeId: r.employeeId,
              attendanceType: r.status,
              otType: r.ot,
            ))
        .toList();

    setState(() => _isSaving = true);
    try {
      final message = await _service.markAttendance(_date, entries);
      if (!mounted) return;
      _toast(message);
      _dirty = false;
      Navigator.of(context).pop(_date);
    } catch (e) {
      if (!mounted) return;
      if (handleBranchAttendanceAuthError(context, e)) return;
      setState(() => _isSaving = false);
      _toast(branchErrorMessage(e), error: true);
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty && !_isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isSaving) return;
        if (await _confirmDiscard() && mounted) {
          setState(() => _dirty = false);
          Navigator.of(this.context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: LanguageManager.instance,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const TranslatedText(
              'Add Attendance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildDateBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          bottomNavigationBar: _buildSaveBar(),
        ),
      ),
    );
  }

  Widget _buildDateBar() {
    final place = [
      if (_zone.isNotEmpty) _zone[0].toUpperCase() + _zone.substring(1),
      if (_branchName.isNotEmpty) _branchName,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatedText(
            'Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _isSaving ? null : _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 18, color: Color(0xFFC91115)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _displayDate(_date),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(place,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC91115)),
      );
    }
    if (_error != null) return _buildError();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        for (final row in _rows) ...[
          _buildRowCard(row),
          const SizedBox(height: 10),
        ],
        if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: TranslatedText(
                'No employees found.',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _addEmployee,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const TranslatedText('Add Employee'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF181D50),
            side: const BorderSide(color: Color(0xFF181D50)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRowCard(_EntryRow row) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: row.isAdded ? const Color(0xFF181D50) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + designation are read-only text everywhere.
                      Text(
                        row.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t(row.designation),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (row.isAdded) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181D50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const TranslatedText(
                      'New',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF181D50),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626)),
                    tooltip: _t('Remove'),
                    onPressed: _isSaving ? null : () => _removeRow(row),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _buildSelect(
              label: 'Attendance',
              value: row.choice,
              items: _Choice.labels,
              onChanged: (v) => _setChoice(row, v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelect({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: items.entries
                  .map((e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(
                          _t(e.value),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _Choice.color(e.key),
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: _isSaving ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveBar() {
    final canSave = !_isLoading && _error == null && !_isSaving;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canSave ? _save : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded),
            label: const TranslatedText('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC91115),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 52),
            const SizedBox(height: 14),
            const TranslatedText(
              'Could not load attendance data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const TranslatedText('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC91115),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: live name search (GET /search-employee). The only way to add a
/// row is to tap a result - free-typed text can never become an entry.
class _EmployeeSearchSheet extends StatefulWidget {
  final BranchAttendanceService service;
  final Set<int> excludeIds;

  const _EmployeeSearchSheet({
    required this.service,
    required this.excludeIds,
  });

  @override
  State<_EmployeeSearchSheet> createState() => _EmployeeSearchSheetState();
}

class _EmployeeSearchSheetState extends State<_EmployeeSearchSheet> {
  static const int _minChars = 2;

  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  List<BranchEmployeeSearchResult> _results = [];
  bool _isLoading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.length < _minChars) {
      _requestId++; // invalidate anything in flight
      setState(() {
        _results = [];
        _isLoading = false;
        _error = null;
        _lastQuery = q;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
      _lastQuery = q;
    });
    try {
      final list = await widget.service.searchEmployees(q);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results =
            list.where((r) => !widget.excludeIds.contains(r.id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      if (handleBranchAttendanceAuthError(context, e)) return;
      setState(() {
        _error = branchErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.instance;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: lm.translateSync('Search employee by name'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final lm = LanguageManager.instance;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC91115)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB91C1C))),
        ),
      );
    }
    if (_lastQuery.length < _minChars) {
      return Center(
        child: Text(
          lm.translateSync('Type at least 2 letters to search'),
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          lm.translateSync('No employees found.'),
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _results[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFC91115),
            child: Text(
              r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(r.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(lm.translateSync(r.designation)),
          onTap: () => Navigator.of(context).pop(r),
        );
      },
    );
  }
}
