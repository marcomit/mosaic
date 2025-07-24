enum ModuleEnum {
	planner,
	cassa,
	banco,
	home,
	settings;

  static ModuleEnum? tryParse(String value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return null;
  }
}
  