class AppI18n {
  static bool isZh = true;

  static String tr(String zh, String en) => isZh ? zh : en;
}
