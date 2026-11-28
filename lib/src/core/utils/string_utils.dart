// lib/src/core/utils/string_utils.dart

extension StringUtils on String {
  String removeDiacritics() {
    var str = this;
    const withAccents = 'ÄÁÀÂÃÉÈÊÍÌÎÓÒÔÕÚÙÛÜÇÑäáàâãéèêíìîóòôõúùûüçñ';
    const withoutAccents = 'AAAAAEEEEIIIOOOOUUUUCNaaaaaeeeeiiioooouuuucn';

    for (int i = 0; i < withAccents.length; i++) {
      str = str.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return str;
  }

  String normalizeSearch() {
    return removeDiacritics().toLowerCase().trim();
  }

  int compareToNormalized(String other) {
    return normalizeSearch().compareTo(other.normalizeSearch());
  }
}

int compareNullableStrings(String? a, String? b) {
  final strA = (a ?? '').normalizeSearch();
  final strB = (b ?? '').normalizeSearch();
  return strA.compareTo(strB);
}
