import 'package:flutter/cupertino.dart';

/// Horizontal scrollable date timeline for the daily puzzle screen.
class DateTimeline extends StatefulWidget {
  final List<DateTime> dates;
  final DateTime selectedDate;
  final void Function(DateTime date) onDateSelected;

  const DateTimeline({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<DateTimeline> createState() => _DateTimelineState();
}

class _DateTimelineState extends State<DateTimeline> {
  late ScrollController _scrollController;
  static const double _itemWidth = 64.0;
  static const double _itemHeight = 72.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(DateTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final index = widget.dates.indexWhere(
      (d) => _isSameDay(d, widget.selectedDate),
    );
    if (index == -1) return;
    final offset = (index * _itemWidth) - 100.0;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _itemHeight,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.dates.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final date = widget.dates[index];
          final isSelected = _isSameDay(date, widget.selectedDate);
          final isToday = _isSameDay(date, DateTime.now());
          return _DateItem(
            date: date,
            isSelected: isSelected,
            isToday: isToday,
            onTap: () => widget.onDateSelected(date),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateItem extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  static const _weekDays = ['日', '一', '二', '三', '四', '五', '六'];
  static const _months = ['1月', '2月', '3月', '4月', '5月', '6月',
                           '7月', '8月', '9月', '10月', '11月', '12月'];

  const _DateItem({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.systemBlue
              : isToday
                  ? CupertinoColors.systemBlue.withOpacity(0.1)
                  : CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          border: isToday && !isSelected
              ? Border.all(color: CupertinoColors.systemBlue, width: 1.5)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CupertinoColors.systemBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekDays[date.weekday % 7],
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? CupertinoColors.white
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? CupertinoColors.white
                    : isToday
                        ? CupertinoColors.systemBlue
                        : CupertinoColors.label.resolveFrom(context),
              ),
            ),
            Text(
              _months[date.month - 1],
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? CupertinoColors.white.withOpacity(0.8)
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
