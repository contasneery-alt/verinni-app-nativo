import 'package:intl/intl.dart';

class AppFormatters {
  static final _currencyFormatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final _dateFormatter = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _dateTimeFormatter =
      DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final _timeFormatter = DateFormat('HH:mm', 'pt_BR');

  static String currency(double? value) {
    if (value == null) return 'R\$ 0,00';
    return _currencyFormatter.format(value);
  }

  static String currencyFromString(String? value) {
    if (value == null || value.isEmpty) return 'R\$ 0,00';
    return currency(double.tryParse(value) ?? 0.0);
  }

  /// Formata valor compacto: 1.500 → R$ 1,5K ; 1.200.000 → R$ 1,2M
  static String currencyCompact(double? value) {
    if (value == null || value == 0) return 'R\$ 0';
    if (value >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(1)}K';
    }
    return currency(value);
  }

  static String date(DateTime? date) {
    if (date == null) return '--';
    return _dateFormatter.format(date);
  }

  static String dateFromString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    try {
      return date(DateTime.parse(dateStr).toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  static String dateTime(DateTime? date) {
    if (date == null) return '--';
    return _dateTimeFormatter.format(date);
  }

  static String dateTimeFromString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    try {
      return dateTime(DateTime.parse(dateStr).toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  static String time(DateTime? date) {
    if (date == null) return '--';
    return _timeFormatter.format(date);
  }

  static String cpf(String? cpf) {
    if (cpf == null || cpf.length != 11) return cpf ?? '--';
    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9)}';
  }

  static String phone(String? phone) {
    if (phone == null) return '--';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  static String initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  static String timeAgo(String? dateStr) {
    if (dateStr == null) return '--';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return 'agora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
      if (diff.inHours < 24) return '${diff.inHours}h atrás';
      if (diff.inDays < 7) return '${diff.inDays}d atrás';
      return AppFormatters.dateFromString(dateStr);
    } catch (_) {
      return '--';
    }
  }
}
