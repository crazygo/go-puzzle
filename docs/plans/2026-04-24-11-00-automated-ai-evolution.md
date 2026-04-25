# Implementation Plan: Automated AI Evolution System (Capture-Go)

## 1. Background

### Context
The project currently features a functional Go engine with a specific focus on "Capture-5" rules (first to capture 5 stones wins). There are four baseline AI styles—Hunter, Counter, Trapper, and Switcher—implemented using MCTS and heuristic rules. A basic evaluation tool exists in the worktree to run limited matches between these styles.

### Problem
Scaling AI performance to a 19x19 board presents a massive search space that manual parameter tuning cannot efficiently handle. The current evaluation tool is single-threaded, lacks data persistence, and provides no diagnostic feedback on *why* an AI lost, making iterative improvement a slow, trial-and-error process. There is no automated way to evolve AI agents beyond their current static capabilities.

### Motivation
Building an automated evolution framework will enable the system to autonomously discover optimal parameter sets and tactical strategies. By shifting from manual coding to an automated "Darwinian" feedback loop, we can develop higher-dan level agents for large boards, reduce R&D time, and provide users with a more sophisticated and dynamic range of difficulty levels.

## 2. Goals
- Develop a high-throughput, parallelized match simulation arena.
- Implement a diagnostic analytics engine to identify tactical AI weaknesses.
- Integrate an evolutionary optimization loop (e.g., Genetic Algorithms) to automate parameter tuning.
- Establish a versioned registry of AI agents with tracked Elo ratings.

## 3. Implementation Plan

### Phase 1: Infrastructure & Automated Arena
- **Parallel Arena Runner**: Develop a Dart-based runner using Isolates to execute matches in parallel across CPU cores.
- **Data Schema & Persistence**: Define and implement storage (SQLite or JSON) for `AgentVersion`, `MatchResult`, and `EloHistory`.
- **Headless Optimization**: Strip UI dependencies from the engine core to maximize simulation speed.

### Phase 2: Diagnostic Analytics
- **Tactical Instrumentation**: Update the engine to log move-by-move metrics (liberties, Atari counts, territory estimates).
- **Failure Analysis**: Build a tool to detect "blunders" (moves leading to a significant drop in win probability) and tactical patterns (e.g., failure to escape a ladder).
- **Heatmap Generation**: Visualize board-specific success/failure rates to identify regional weaknesses.

### Phase 3: Automated Parameter Evolution
- **Configurable DNA**: Refactor all engine "magic numbers" (MCTS constants, heuristic weights) into a JSON-loadable configuration.
- **Evolutionary Loop**: Implement a top-level controller that generates variants, runs tournaments, and selects the "fittest" agents for the next generation.
- **Elo System**: Integrate an automated Elo calculation to track agent progress over time.

### Phase 4: Tiering & Delivery
- **Skill Snapshots**: Automatically identify and snapshot agents at different evolutionary milestones.
- **Dynamic Policy Integration**: Create a "Master Agent" that can switch tactical modes based on the game phase.

## 4. Acceptance Criteria
- [ ] A parallel match runner can execute 100 matches of 19x19 Capture-5 between two agents in under 10 minutes (hardware dependent).
- [ ] Match results are correctly persisted to the registry with full Elo history.
- [ ] The evolutionary loop can demonstrate a measurable increase in an agent's Elo over 5 generations.
- [ ] Validation commands pass without error:
    - `flutter analyze`
    - `flutter test`
    - `dart run tool/evaluate_capture_ai.dart` (updated version)
