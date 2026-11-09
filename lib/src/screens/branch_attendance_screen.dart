import 'package:flutter/material.dart';
import '../models/branch_attendance_model.dart';
import '../services/branch_attendance_service.dart';
import '../services/language_manager.dart';
import '../widgets/translated_text.dart';
import 'branch_attendance_day_screen.dart';

/// Screen 1 - spreadsheet-style month view for the branch incharge's team.
class BranchAttendanceScreen extends StatefulWidget {
  const BranchAttendanceScreen({super.key});

  @override
  State<BranchAttendanceScreen> createState() => _BranchAttendanceScreenState();
}

class _BranchAttendanceScreenState extends State<BranchAttendanceScreen> {
  final _service = BranchAttendanceService();

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const List<String> _weekdayShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' // DateTime.weekday: Mon=1
  ];

  // Grid metrics. Fixed heights keep the frozen date column, the scrolling
  // body and the pinned header/footer aligned.
  static const double _dateW = 72;
  static const double _minColW = 104;
  static const double _headH = 56;
  static const double _rowH = 44;
  static const double _footRowH = 32;

  // Sunday row highlight.
  static const Color _sundayBg = Color(0xFFEFF6FF);
  static const Color _sundayDateBg = _sundayBg;

  // Header and footer follow the body's horizontal scroll position.
  final ScrollController _hBody = ScrollController();
  final ScrollController _hHead = ScrollController();
  final ScrollController _hFoot = ScrollController();

  late int _year;
  late int _monthIndex; // 0-based
  late final List<int> _years;

  BranchMonthData? _data;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _monthIndex = now.month - 1;
    final first = now.year < 2024 ? now.year : 2024;
    _years = List.generate(now.year + 1 - first + 1, (i) => first + i);
    _hBody.addListener(_syncHorizontal);
    _load();
  }

  void _syncHorizontal() {
    final offset = _hBody.hasClients ? _hBody.offset : 0.0;
    for (final c in [_hHead, _hFoot]) {
      if (c.hasClients && (c.offset - offset).abs() > 0.5) {
        final max = c.position.maxScrollExtent;
        c.jumpTo(offset > max ? max : offset);
      }
    }
  }

  @override
  void dispose() {
    _hBody.dispose();
    _hHead.dispose();
    _hFoot.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchMonth(_year, _months[_monthIndex]);
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (handleBranchAttendanceAuthError(context, e)) return;
      setState(() {
        _error = branchErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openDayEntry() async {
    final saved = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        builder: (_) => BranchAttendanceDayScreen(initialDate: DateTime.now()),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      // Jump to the month that was just edited so the change is visible.
      setState(() {
        _year = saved.year;
        _monthIndex = saved.month - 1;
      });
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageManager.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const TranslatedText(
            'Branch Attendance',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: LanguageManager.instance.translateSync('Reload List'),
              onPressed: _load,
            ),
            const SizedBox(width: 8),
          ],
        ),
        // Full-width bar (same style as the Save bar on the entry screen) so it
        // never covers the pinned totals at the bottom of the grid.
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openDayEntry,
                icon: const Icon(Icons.edit_calendar_rounded),
                label: const TranslatedText(
                  'Add Attendance',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildFilterBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    Widget dropdown<T>({
      required String label,
      required T value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged,
    }) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TranslatedText(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: items,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          dropdown<int>(
            label: 'Select Year',
            value: _year,
            items: _years
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) {
              if (v == null || v == _year) return;
              setState(() => _year = v);
              _load();
            },
          ),
          const SizedBox(width: 12),
          dropdown<int>(
            label: 'Select Month',
            value: _monthIndex,
            items: List.generate(
              12,
              (i) => DropdownMenuItem(
                value: i,
                child: Text(LanguageManager.instance.translateSync(_months[i])),
              ),
            ),
            onChanged: (v) {
              if (v == null || v == _monthIndex) return;
              setState(() => _monthIndex = v);
              _load();
            },
          ),
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

    final data = _data!;
    return Column(
      children: [
        _buildLegend(),
        Expanded(
          child: data.employees.isEmpty
              ? Center(
                  child: Text(
                    LanguageManager.instance
                        .translateSync('No employees found.'),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : _buildGrid(data),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    Widget chip(String text, Color c) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(text,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF475569))),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          children: [
            chip('P', const Color(0xFF16A34A)),
            chip('A', const Color(0xFFDC2626)),
            chip('OT', const Color(0xFF1D4ED8)),
          ],
        ),
      ),
    );
  }

  /// Transposed month grid: dates down the left (frozen), employees across the
  /// top (frozen header). Totals are pinned at the bottom. Only the body scrolls
  /// vertically; header, body and footer scroll horizontally together.
  Widget _buildGrid(BranchMonthData data) {
    final days = data.daysInMonth > 0
        ? data.daysInMonth
        : DateUtils.getDaysInMonth(_year, _monthIndex + 1);
    final emps = data.employees;
    const border = BorderSide(color: Color(0xFFE2E8F0));
    const headBg = Color(0xFFF8FAFC);

    Widget cell({
      required double width,
      required double height,
      required Widget child,
      Color? color,
      Alignment alignment = Alignment.center,
    }) {
      return Container(
        width: width,
        height: height,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          border: const Border(right: border, bottom: border),
        ),
        child: child,
      );
    }

    Widget headText(String t) => FittedBox(
          fit: BoxFit.scaleDown,
          child: TranslatedText(
            t,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
        );

    Widget framed(Widget child) => Container(
          decoration: const BoxDecoration(
            border: Border(top: border, left: border),
          ),
          child: child,
        );

    // Header/footer never take touch input; they just mirror the body.
    Widget mirrored(ScrollController controller, Widget child) =>
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: controller,
          physics: const NeverScrollableScrollPhysics(),
          child: child,
        );

    return LayoutBuilder(builder: (context, constraints) {
      // Share the available width equally when there are only a few
      // employees; otherwise keep a readable minimum and scroll sideways.
      final avail = constraints.maxWidth - 32 - _dateW; // 16px gutters
      final fit = emps.isEmpty ? _minColW : avail / emps.length;
      final colW = fit > _minColW ? fit : _minColW;

      // ---- pinned header: "Date" corner + employee names
      final header = framed(Row(
        children: [
          cell(
              width: _dateW,
              height: _headH,
              color: headBg,
              child: headText('Date')),
          Expanded(
            child: mirrored(
              _hHead,
              Row(
                children: [
                  for (final e in emps)
                    cell(
                      width: colW,
                      height: _headH,
                      color: headBg,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            e.employeeName,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            LanguageManager.instance
                                .translateSync(e.designation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ));

      // ---- body: frozen date column + horizontally scrolling day rows
      // Sunday rows are tinted across the whole row (date cell + every employee).
      bool isSunday(int d) =>
          DateTime(_year, _monthIndex + 1, d).weekday == DateTime.sunday;

      final dateColumn = Column(
        children: [
          for (var d = 1; d <= days; d++)
            cell(
              width: _dateW,
              height: _rowH,
              color: isSunday(d) ? _sundayDateBg : headBg,
              child: _buildDateLabel(d),
            ),
        ],
      );

      final dayRows = Column(
        children: [
          for (var d = 1; d <= days; d++)
            Row(
              children: [
                for (final e in emps)
                  cell(
                    width: colW,
                    height: _rowH,
                    color: isSunday(d) ? _sundayBg : Colors.white,
                    child: _buildDayValue(e.dailyAttendance[d]),
                  ),
              ],
            ),
        ],
      );

      final body = Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: framed(Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dateColumn,
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _hBody,
                    child: dayRows,
                  ),
                ),
              ],
            )),
          ),
        ),
      );

      // ---- pinned footer: totals per employee (values come from the API)
      const presentBg = Color(0xFFF0FDF4);
      const absentBg = Color(0xFFFEF2F2);
      const otBg = Color(0xFFEFF6FF);
      const presentFg = Color(0xFF16A34A);
      const absentFg = Color(0xFFDC2626);
      const otFg = Color(0xFF1D4ED8);

      Widget totalsRow(Color bg, Color fg, String Function(BranchMonthEmployee) v) =>
          Row(
            children: [
              for (final e in emps)
                cell(
                  width: colW,
                  height: _footRowH,
                  color: bg,
                  child: _totalText(v(e), fg),
                ),
            ],
          );

      final footer = framed(Row(
        children: [
          Column(
            children: [
              cell(width: _dateW, height: _footRowH, color: presentBg, child: headText('Present')),
              cell(width: _dateW, height: _footRowH, color: absentBg, child: headText('Absent')),
              cell(width: _dateW, height: _footRowH, color: otBg, child: headText('OT')),
            ],
          ),
          Expanded(
            child: mirrored(
              _hFoot,
              Column(
                children: [
                  totalsRow(presentBg, presentFg, (e) => '${e.presentCount}'),
                  totalsRow(absentBg, absentFg, (e) => '${e.leaveCount}'),
                  totalsRow(otBg, otFg, (e) => _formatOt(e.otCount)),
                ],
              ),
            ),
          ),
        ],
      ));

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            header,
            body,
            footer,
            const SizedBox(height: 8),
          ],
        ),
      );
    });
  }

  Widget _buildDateLabel(int day) {
    final weekday = DateTime(_year, _monthIndex + 1, day).weekday;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$day',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: weekday == DateTime.sunday
                ? const Color(0xFFB91C1C)
                : const Color(0xFF334155),
          ),
        ),
        Text(
          LanguageManager.instance.translateSync(_weekdayShort[weekday - 1]),
          style: TextStyle(
            fontSize: 9,
            fontWeight:
                weekday == DateTime.sunday ? FontWeight.bold : FontWeight.normal,
            color: weekday == DateTime.sunday
                ? const Color(0xFFB91C1C)
                : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _totalText(String v, Color c) => Text(
        v,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c),
      );

  /// Cell text: "P", "A", "Half OT" or "Full OT". The API sends OT days as
  /// "P/Half OT" / "P/Full OT"; show only the OT part for those.
  String _cellLabel(String value) {
    final parts = value.split('/').map((p) => p.trim()).toList();
    final ot = parts.where((p) => p.toUpperCase().contains('OT')).toList();
    return ot.isNotEmpty ? ot.join('\n') : value;
  }

  Widget _buildDayValue(String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final label = _cellLabel(value);
    final Color color;
    if (label == 'A') {
      color = const Color(0xFFDC2626);
    } else if (label == 'P') {
      color = const Color(0xFF16A34A);
    } else if (label.toUpperCase().contains('OT')) {
      color = const Color(0xFF1D4ED8);
    } else {
      color = const Color(0xFF16A34A);
    }
    return Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: color,
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

  /// Shows the API value exactly, never rounded: 0.25 -> "0.25", 0.5 -> "0.5",
  /// 2.0 -> "2".
  static String _formatOt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}
