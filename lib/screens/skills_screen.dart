import 'package:flutter/cupertino.dart';

import '../data/tactics_problem_repository.dart';
import '../game/capture_ai_tactics.dart';
import '../ui/tactics_labels.dart';
import 'tactics_problem_screen.dart';

const _allFilter = 'all';

const _categoryOrder = [
  'group_fate',
  'capture_race',
  'exchange',
  'multi_threat',
  'trap',
];

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({
    super.key,
    Future<List<CaptureAiTacticsProblem>>? problemsFuture,
  }) : _problemsFutureOverride = problemsFuture;

  final Future<List<CaptureAiTacticsProblem>>? _problemsFutureOverride;

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {

  late final Future<List<CaptureAiTacticsProblem>> _problemsFuture;
  String _selectedCategory = _allFilter;

  @override
  void initState() {
    super.initState();
    _problemsFuture = widget._problemsFutureOverride ??
        const TacticsProblemRepository().loadProblems();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: FutureBuilder<List<CaptureAiTacticsProblem>>(
        future: _problemsFuture,
        builder: (context, snapshot) {
          final problems = snapshot.data;
          final isLoading = snapshot.connectionState != ConnectionState.done;
          final hasError = snapshot.hasError;
          final categories =
              problems == null ? const <String>[] : _categories(problems);
          final visibleProblems = problems == null
              ? const <CaptureAiTacticsProblem>[]
              : _selectedCategory == _allFilter
                  ? problems
                  : problems
                      .where((problem) => problem.category == _selectedCategory)
                      .toList();
          final groupedProblems = problems == null
              ? const <String, List<CaptureAiTacticsProblem>>{}
              : _groupByCategory(visibleProblems, categories);

          return CustomScrollView(
            slivers: [
              const CupertinoSliverNavigationBar(
                largeTitle: Text('谜题'),
              ),
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (hasError)
                SliverFillRemaining(
                  child: _ErrorState(error: snapshot.error),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _SummaryHeader(
                    total: problems!.length,
                    visible: visibleProblems.length,
                    categories: categories.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoryFilterBar(
                    categories: categories,
                    selected: _selectedCategory,
                    counts: _categoryCounts(problems),
                    onSelected: (category) {
                      setState(() => _selectedCategory = category);
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ProblemSections(
                    groupedProblems: groupedProblems,
                    onOpenProblem: (problem) => _openProblem(context, problem),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ],
          );
        },
      ),
    );
  }

  List<String> _categories(List<CaptureAiTacticsProblem> problems) {
    final categorySet = problems.map((problem) => problem.category).toSet();
    final categories = [
      for (final category in _categoryOrder)
        if (categorySet.remove(category)) category,
      ...categorySet.toList()..sort(),
    ];
    return categories;
  }

  Map<String, List<CaptureAiTacticsProblem>> _groupByCategory(
    List<CaptureAiTacticsProblem> problems,
    List<String> categories,
  ) {
    final grouped = <String, List<CaptureAiTacticsProblem>>{
      for (final category in categories) category: <CaptureAiTacticsProblem>[],
    };
    for (final problem in problems) {
      grouped.putIfAbsent(problem.category, () => <CaptureAiTacticsProblem>[]);
      grouped[problem.category]!.add(problem);
    }
    grouped.removeWhere((_, problems) => problems.isEmpty);
    return grouped;
  }

  Map<String, int> _categoryCounts(List<CaptureAiTacticsProblem> problems) {
    final counts = <String, int>{_allFilter: problems.length};
    for (final problem in problems) {
      counts[problem.category] = (counts[problem.category] ?? 0) + 1;
    }
    return counts;
  }

  void _openProblem(BuildContext context, CaptureAiTacticsProblem problem) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => TacticsProblemScreen(problem: problem),
      ),
    );
  }
}

class _ProblemSections extends StatelessWidget {
  const _ProblemSections({
    required this.groupedProblems,
    required this.onOpenProblem,
  });

  final Map<String, List<CaptureAiTacticsProblem>> groupedProblems;
  final ValueChanged<CaptureAiTacticsProblem> onOpenProblem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groupedProblems.entries)
          _ProblemCategorySection(
            category: entry.key,
            problems: entry.value,
            onOpenProblem: onOpenProblem,
          ),
      ],
    );
  }
}

class _ProblemCategorySection extends StatelessWidget {
  const _ProblemCategorySection({
    required this.category,
    required this.problems,
    required this.onOpenProblem,
  });

  final String category;
  final List<CaptureAiTacticsProblem> problems;
  final ValueChanged<CaptureAiTacticsProblem> onOpenProblem;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  categoryName(category),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              Text(
                '${problems.length} 题',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final problem in problems)
            _TacticsProblemCard(
              problem: problem,
              onTap: () => onOpenProblem(problem),
            ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.total,
    required this.visible,
    required this.categories,
  });

  final int total;
  final int visible;
  final int categories;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI 测试题集',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '共 $total 题，当前显示 $visible 题，覆盖 $categories 个分类。进入题目后可复盘棋盘并查看 AI 建议。',
            style: TextStyle(fontSize: 14, color: secondary, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = [_allFilter, ...categories];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final category = labels[index];
          final active = category == selected;
          return _FilterChip(
            label: category == _allFilter ? '全部' : categoryName(category),
            count: counts[category] ?? 0,
            active: active,
            onTap: () => onSelected(category),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: labels.length,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = CupertinoColors.activeBlue.resolveFrom(context);
    final borderColor =
        active ? activeColor : CupertinoColors.separator.resolveFrom(context);
    final textColor =
        active ? activeColor : CupertinoColors.label.resolveFrom(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.12)
              : CupertinoColors.systemBackground.resolveFrom(context),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _TacticsProblemCard extends StatelessWidget {
  const _TacticsProblemCard({
    required this.problem,
    required this.onTap,
  });

  final CaptureAiTacticsProblem problem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tactic = problem.metadata['tactic']?.toString();
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                CupertinoColors.secondarySystemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      problem.id,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ),
                  Text(
                    '${problem.boardSize}路',
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MiniTag(label: categoryName(problem.category)),
                  if (tactic != null && tactic.isNotEmpty)
                    _MiniTag(label: tacticName(tactic)),
                  _MiniTag(label: '先手 ${playerName(problem.currentPlayer)}'),
                  _MiniTag(
                    label:
                        '提子 ${problem.capturedByBlack}:${problem.capturedByWhite}',
                  ),
                ],
              ),
              if (problem.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  problem.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: secondary, height: 1.3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '测试题集加载失败\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CupertinoColors.destructiveRed.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
