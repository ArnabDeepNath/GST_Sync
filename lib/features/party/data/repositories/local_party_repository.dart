import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gspappv2/features/party/domain/models/party_model.dart';
import 'package:gspappv2/features/party/data/repositories/party_repository.dart';

class LocalPartyRepository extends PartyRepository {
  static const String _key = 'parties';
  final SharedPreferences _prefs;

  LocalPartyRepository(this._prefs);

  @override
  Future<List<Party>> getAll() async {
    final String? data = _prefs.getString(_key);
    if (data == null) return [];

    final List<dynamic> jsonList = json.decode(data);
    return jsonList.map((json) => Party.fromJson(json)).toList();
  }

  @override
  Future<Party> add(Party party) async {
    final parties = await getAll();
    parties.add(party);
    await _saveParties(parties);
    return party;
  }

  @override
  Future<void> update(Party party) async {
    final parties = await getAll();
    final index = parties.indexWhere((p) => p.id == party.id);
    if (index != -1) {
      parties[index] = party;
      await _saveParties(parties);
    }
  }

  @override
  Future<void> delete(String id) async {
    final parties = await getAll();
    parties.removeWhere((party) => party.id == id);
    await _saveParties(parties);
  }

  Future<void> _saveParties(List<Party> parties) async {
    final String data = json.encode(parties.map((p) => p.toJson()).toList());
    await _prefs.setString(_key, data);
  }
}
