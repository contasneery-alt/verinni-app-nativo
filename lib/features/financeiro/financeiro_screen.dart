import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/formatters.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  double _totalReceitas = 0;
  double _totalDespesas = 0;
  List<Map<String, dynamic>> _orcamentosAprovados = [];
  List<_ChartData> _chartData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    try {
      // Load approved budgets as revenue
      final orcamentos = await _supabase
          .from('orcamentos')
          .select('*')
          .inFilter('status', ['approved', 'completed'])
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(orcamentos);
      double total = 0;
      for (final orc in list) {
        final v = double.tryParse(
            orc['total_value']?.toString() ??
                orc['valor']?.toString() ??
                orc['amount']?.toString() ??
                '0');
        if (v != null) total += v;
      }

      // Try loading expenses
      double despesas = 0;
      try {
        final exp = await _supabase.from('expenses').select('amount');
        for (final e in exp) {
          final v = double.tryParse(e['amount']?.toString() ?? '0');
          if (v != null) despesas += v;
        }
      } catch (_) {}

      // Build chart data (last 6 months)
      final chartData = _buildMonthlyChartData(list);

      if (mounted) {
        setState(() {
          _orcamentosAprovados = list;
          _totalReceitas = total;
          _totalDespesas = despesas;
          _chartData = chartData;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _orcamentosAprovados = [];
          _totalReceitas = 0;
        });
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  List<_ChartData> _buildMonthlyChartData(List<Map<String, dynamic>> orcamentos) {
    final now = DateTime.now();
    final data = <_ChartData>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthOrc = orcamentos.where((orc) {
        final dateStr = orc['created_at']?.toString();
        if (dateStr == null) return false;
        try {
          final date = DateTime.parse(dateStr);
          return date.year == month.year && date.month == month.month;
        } catch (_) {
          return false;
        }
      });

      double total = 0;
      for (final o in monthOrc) {
        final v = double.tryParse(
            o['total_value']?.toString() ?? o['valor']?.toString() ?? '0');
        if (v != null) total += v;
      }

      final monthNames = [
        'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
        'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
      ];
      data.add(_ChartData(monthNames[month.month - 1], total));
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _totalReceitas - _totalDespesas;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financeiro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary cards
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Receitas',
                            value: AppFormatters.currency(_totalReceitas),
                            icon: Icons.trending_up,
                            iconColor: AppColors.success,
                            subtitle: 'Orçamentos aprovados',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Despesas',
                            value: AppFormatters.currency(_totalDespesas),
                            icon: Icons.trending_down,
                            iconColor: AppColors.error,
                            subtitle: 'Total registrado',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'Saldo',
                            value: AppFormatters.currency(saldo),
                            icon: Icons.account_balance,
                            iconColor: saldo >= 0 ? AppColors.success : AppColors.error,
                            subtitle: 'Receitas - Despesas',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Chart
                    VerinniCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receitas por Mês',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Últimos 6 meses (orçamentos aprovados)',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 200,
                            child: _chartData.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Sem dados para exibir',
                                      style: TextStyle(
                                          color: AppColors.textMuted),
                                    ),
                                  )
                                : BarChart(
                                    BarChartData(
                                      backgroundColor: Colors.transparent,
                                      borderData: FlBorderData(show: false),
                                      gridData: const FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        horizontalInterval: 1,
                                        getDrawingHorizontalLine: _gridLine,
                                      ),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        topTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false),
                                        ),
                                        leftTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              final i = value.toInt();
                                              if (i >= 0 &&
                                                  i < _chartData.length) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8),
                                                  child: Text(
                                                    _chartData[i].month,
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ),
                                      ),
                                      barGroups: _chartData
                                          .asMap()
                                          .entries
                                          .map(
                                            (e) => BarChartGroupData(
                                              x: e.key,
                                              barRods: [
                                                BarChartRodData(
                                                  toY: e.value.value > 0
                                                      ? e.value.value / 1000
                                                      : 0.1,
                                                  color: AppColors.primary,
                                                  width: 20,
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                    top: Radius.circular(6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              '* Valores em milhares (R\$)',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recent transactions
                    const Text(
                      'Orçamentos Aprovados',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_orcamentosAprovados.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Nenhuma receita',
                        subtitle: 'Não há orçamentos aprovados ainda',
                      )
                    else
                      ...(_orcamentosAprovados.take(10).map((orc) {
                        final valor = double.tryParse(
                                orc['total_value']?.toString() ??
                                    orc['valor']?.toString() ??
                                    '0') ??
                            0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: VerinniCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_downward,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        orc['title'] ??
                                            orc['client_name'] ??
                                            'Orçamento',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        AppFormatters.dateFromString(
                                            orc['created_at']?.toString()),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  AppFormatters.currency(valor),
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  static FlLine _gridLine(double value) {
    return FlLine(
      color: AppColors.border,
      strokeWidth: 1,
      dashArray: [4, 4],
    );
  }
}

class _ChartData {
  final String month;
  final double value;
  _ChartData(this.month, this.value);
}
