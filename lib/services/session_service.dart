import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _kOpName = 'sess_op_name';
  static const _kOpUntil = 'sess_op_until_ms';
  static const _kAdmOn = 'sess_admin_override';
  static const _kAdmName = 'sess_admin_name';

  static const Duration operatorTtl = Duration(minutes: 10);

  static String? _operatorName;
  static int? _operatorUntilEpochMs;
  static bool _adminOverride = false;
  static String? _adminName;
  static bool _loaded = false;

  SessionService() {
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final sp = await SharedPreferences.getInstance();
    _operatorName = sp.getString(_kOpName);
    _operatorUntilEpochMs = sp.getInt(_kOpUntil);
    _adminOverride = sp.getBool(_kAdmOn) ?? false;
    _adminName = sp.getString(_kAdmName);
    _loaded = true;
  }

  // --------- Operador ---------
  bool get hasValidOperator {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_operatorUntilEpochMs == null) return false;
    final valid = now < _operatorUntilEpochMs!;
    if (!valid) {
      clearOperator(); // limpa expirado
    }
    return valid;
  }

  String? get operatorName => hasValidOperator ? _operatorName : null;
  String? get operatorIfValid => operatorName;

  Future<void> startOperatorSession(String name) async {
    final sp = await SharedPreferences.getInstance();
    final until = DateTime.now().add(operatorTtl).millisecondsSinceEpoch;
    _operatorName = name;
    _operatorUntilEpochMs = until;
    await sp.setString(_kOpName, name);
    await sp.setInt(_kOpUntil, until);
  }

  Future<void> saveOrRefreshOperator({required String name, required String key}) =>
      startOperatorSession(name);

  Future<void> clearOperator() async {
    final sp = await SharedPreferences.getInstance();
    _operatorName = null;
    _operatorUntilEpochMs = null;
    await sp.remove(_kOpName);
    await sp.remove(_kOpUntil);
  }

  // --------- Admin override ---------
  bool get adminOverride => _adminOverride;
  bool get isAdminOverride => _adminOverride;
  String? get adminName => _adminName;

  Future<void> setAdminOverride(bool enabled, {String? name}) async {
    final sp = await SharedPreferences.getInstance();
    _adminOverride = enabled;
    _adminName = enabled ? (name ?? 'Admin') : null;
    await sp.setBool(_kAdmOn, enabled);
    if (enabled) {
      await sp.setString(_kAdmName, _adminName!);
    } else {
      await sp.remove(_kAdmName);
    }
  }

  Future<void> clearAdminOverride() => setAdminOverride(false);
}
