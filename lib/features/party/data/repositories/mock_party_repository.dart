import 'package:gspappv2/core/repositories/base_repository.dart';
import 'package:gspappv2/features/party/domain/models/party_model.dart';

class MockPartyRepository implements BaseRepository<Party> {
  final List<Party> _parties = [];

  @override
  Future<List<Party>> getAll() async {
    return _parties;
  }

  @override
  Future<Party> add(Party party) async {
    _parties.add(party);
    return party;
  }

  @override
  Future<void> update(Party party) async {
    final index = _parties.indexWhere((p) => p.id == party.id);
    if (index != -1) {
      _parties[index] = party;
    }
  }

  @override
  Future<void> delete(String id) async {
    _parties.removeWhere((party) => party.id == id);
  }
}
