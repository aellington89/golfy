/// A single shot's editable fields (#22), independent of order — its
/// `shotNumber` is assigned from position in the list when saved. The Hole
/// Entry form builds these from its in-memory drafts and hands them to
/// [GolfyRepository.saveHole], which turns them into `hole_shots` rows.
class HoleShotInput {
  const HoleShotInput({
    this.club,
    this.distanceYards,
    this.lie,
    this.result,
  });

  final String? club;
  final int? distanceYards;
  final String? lie;
  final String? result;
}
