import '../../l10n/app_localizations.dart';

/// 城市名称国际化（达人筛选等使用）
class CityDisplayHelper {
  CityDisplayHelper._();

  static String getDisplayName(String cityKey, AppLocalizations l10n) {
    if (cityKey == 'all') return l10n.commonAll;
    switch (cityKey) {
      case 'London': return l10n.cityLondon;
      case 'Edinburgh': return l10n.cityEdinburgh;
      case 'Manchester': return l10n.cityManchester;
      case 'Birmingham': return l10n.cityBirmingham;
      case 'Glasgow': return l10n.cityGlasgow;
      case 'Bristol': return l10n.cityBristol;
      case 'Sheffield': return l10n.citySheffield;
      case 'Leeds': return l10n.cityLeeds;
      case 'Nottingham': return l10n.cityNottingham;
      case 'Newcastle': return l10n.cityNewcastle;
      case 'Southampton': return l10n.citySouthampton;
      case 'Liverpool': return l10n.cityLiverpool;
      case 'Cardiff': return l10n.cityCardiff;
      case 'Coventry': return l10n.cityCoventry;
      case 'Exeter': return l10n.cityExeter;
      case 'Leicester': return l10n.cityLeicester;
      case 'York': return l10n.cityYork;
      case 'Aberdeen': return l10n.cityAberdeen;
      case 'Bath': return l10n.cityBath;
      case 'Dundee': return l10n.cityDundee;
      case 'Reading': return l10n.cityReading;
      case 'St Andrews': return l10n.cityStAndrews;
      case 'Belfast': return l10n.cityBelfast;
      case 'Brighton': return l10n.cityBrighton;
      case 'Durham': return l10n.cityDurham;
      case 'Norwich': return l10n.cityNorwich;
      case 'Swansea': return l10n.citySwansea;
      case 'Loughborough': return l10n.cityLoughborough;
      case 'Lancaster': return l10n.cityLancaster;
      case 'Warwick': return l10n.cityWarwick;
      case 'Cambridge': return l10n.cityCambridge;
      case 'Oxford': return l10n.cityOxford;
      default: return cityKey;
    }
  }
}
