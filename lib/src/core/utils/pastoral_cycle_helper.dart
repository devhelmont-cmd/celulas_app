import 'package:intl/intl.dart';

class PastoralCycleHelper {
  /// Retorna a data do Domingo correspondente (âncora) de qualquer data informada.
  /// Se a data já for domingo, retorna ela mesma. Caso contrário, retroage até o domingo daquela semana.
  static DateTime getCycleSunday(DateTime date) {
    // weekday em Dart: Monday = 1, ..., Sunday = 7
    int weekday = date.weekday;
    if (weekday == 7) {
      return DateTime(date.year, date.month, date.day);
    } else {
      return DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday));
    }
  }

  /// Converte uma data ou uma chave "YYYY-MM-DD" em uma String amigável.
  /// Ex: "2026-10-04" -> "Semana 1 de Outubro (04/10)"
  static String formatCycleKey(DateTime sundayDate) {
    // Descobre qual é a semana do mês para este domingo (1º, 2º, 3º ou 4º/5º domingo)
    int weekNumber = ((sundayDate.day - 1) ~/ 7) + 1;

    // Nome do mês em português
    final monthName = DateFormat('MMMM', 'pt_BR').format(sundayDate);
    // Capitaliza o mês
    final capitalizedMonth = monthName.isNotEmpty
        ? '${monthName[0].toUpperCase()}${monthName.substring(1)}'
        : '';

    final dayStr = sundayDate.day.toString().padLeft(2, '0');
    final monthStr = sundayDate.month.toString().padLeft(2, '0');

    return 'Semana $weekNumber de $capitalizedMonth ($dayStr/$monthStr)';
  }

  /// Gera a chave padrão em string para o Firestore (ex: "2026-10-04")
  static String getCycleKeyString(DateTime date) {
    final sunday = getCycleSunday(date);
    return '${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';
  }
}