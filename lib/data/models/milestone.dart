// ---------------------------------------------------------------------------
// Milestone — a single point-threshold ladder rung for the rewards screen.
// Computed from _milestones constant in rewards_viewmodel; not stored in Firestore.
// ---------------------------------------------------------------------------

class Milestone {
  final int target;
  final int current;
  final String rewardHint;
  const Milestone({
    required this.target,
    required this.current,
    required this.rewardHint,
  });

  int get remaining => target - current;
  double get progress =>
      target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);
  bool get isMaxed => target == 0;

  static const maxed = Milestone(target: 0, current: 0, rewardHint: '');
}
