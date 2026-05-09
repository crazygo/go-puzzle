import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/data/tactics_problem_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads capture AI tactics dataset from bundled asset', () async {
    final problems = await const TacticsProblemRepository().loadProblems();

    expect(problems, isNotEmpty);
    expect(
        problems.map((problem) => problem.category).toSet(), contains('trap'));
    expect(
        problems.map((problem) => problem.category).toSet(),
        contains('group_fate'));
    // Validate a few schema fields on the first problem.
    final first = problems.first;
    expect(first.id, isNotEmpty);
    expect(first.boardSize, anyOf(9, 13));
    expect(first.captureTarget, greaterThan(0));
  });
}
