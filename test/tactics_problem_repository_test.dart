import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/data/tactics_problem_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads capture AI tactics dataset from bundled asset', () async {
    final problems = await const TacticsProblemRepository().loadProblems();

    expect(problems, hasLength(134));
    expect(problems.first.id, 'gf-9-001');
    expect(
        problems.map((problem) => problem.category).toSet(), contains('trap'));
  });
}
