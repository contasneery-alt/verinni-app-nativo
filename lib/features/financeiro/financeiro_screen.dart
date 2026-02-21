import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/formatters.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

/// Financeiro — usa a tabela `financial_transactions` (real) +
/// budgets aprovados/concluídos como fonte de receitas.
///
/// financial_transactions columns (real schema):
///   id, type (income/expense), category, description,
///   amount, status, due_date, payment_date, reference_id,
///   reference_type, created_by, created_at, updated_at
class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;

  bool _isLoading = true;
  double _totalReceitas = 0;
  double _totalDespesas = 0;
  double _totalPendente = 0;

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _budgetsAprovados = [];
  List<_ChartPoint> _chartData = [];

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadTransactions(),
      _loadBudgetsAprovados(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTransactions() async {
    try {
      final data = await _db
          .from('financial_transactions')
          .select('*')
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);

      double receitas = 0;
      double despesas = 0;
      double pendente = 0;

      for (final t in list) {
        final amount =
            double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
        final type = t['type']?.toString() ?? '';
        final status = t['status']?.toString() ?? '';

        if (type == 'income') {
          receitas += amount;
        } else if (type == 'expense') {
          despesas += amount;
          if (status == 'pending') pendente += amount;
        }
      }

      _transactions = list;
      _totalReceitas = receitas;
      _totalDespesas = despesas;
      _totalPendente = pendente;
      _chartData = _buildChartFromTransactions(list);
    } catch (_) {
      // Se não tiver acesso à tabela, usa budgets como receita
      _transactions = [];
    }
  }

  Future<void> _loadBudgetsAprovados() async {
    try {
      final data = await _db
          .from('budgets')
          .select('*, clients(id, name)')
          .inFilter('status', ['approved', 'completed'])
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);
      _budgetsAprovados = list;

      // Se não há transações, usa orçamentos aprovados como receita
      if (_transactions.isEmpty) {
        double total = 0;
        for (final b in list) {
          final v =
              double.tryParse(b['valor_venda']?.toString() ?? '0') ?? 0;
          total += v;
        }
        _totalReceitas = total;
        _chartData = _buildChartFromBudgets(list);
      }
    } catch (_) {
      _budgetsAprovados = [];
    }
  }

  List<_ChartPoint> _buildChartFromTransactions(
      List<Map<String, dynamic>> transactions) {
    final now = DateTime.now();
    final result = <_ChartPoint>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      double income = 0;
      double expense = 0;

      for (final t in transactions) {
        final dateStr = t['created_at']?.toString();
        if (dateStr == null) continue;
        try {
          final d = DateTime.parse(dateStr);
          if (d.year == month.year && d.month == month.month) {
            final amount =
                double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
            if (t['type'] == 'income') {
              income += amount;
            } else {
              expense += amount;
            }
          }
        } catch (_) {}
      }

      final monthNames = [
        'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
        'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
      ];
      result.add(_ChartPoint(monthNames[month.month - 1], income, expense));
    }
    return result;
  }

  List<_ChartPoint> _buildChartFromBudgets(
      List<Map<String, dynamic>> budgets) {
    final now = DateTime.now();
    final result = <_ChartPoint>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      double total = 0;
      for (final b in budgets) {
        final dateStr = b['created_at']?.toString();
        if (dateStr == null) continue;
        try {
          final d = DateTime.parse(dateStr);
          if (d.year == month.year && d.month == month.month) {
            total +=
                double.tryParse(b['valor_venda']?.toString() ?? '0') ?? 0;
          }
        } catch (_) {}
      }
      final monthNames = [
        'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
        'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
      ];
      result.add(_ChartPoint(monthNames[month.month - 1], total, 0));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _totalReceitas - _totalDespesas;
    final hasTransactions = _transactions.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financeiro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Resumo'),
            Tab(text: 'Transações'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildResumoTab(saldo, hasTransactions),
                _buildTransacoesTab(hasTransactions),
              ],
            ),
    );
  }

  Widget _buildResumoTab(double saldo, bool hasTransactions) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Receitas',
                    value: AppFormatters.currency(_totalReceitas),
                    icon: Icons.trending_up,
                    iconColor: AppColors.success,
                    subtitle: hasTransactions
                        ? 'Transações de entrada'
                        : 'Orçamentos aprovados',
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
                    subtitle: hasTransactions
                        ? 'Transações de saída'
                        : 'Registradas',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: _totalPendente > 0 ? 'A Pagar' : 'Saldo',
                    value: AppFormatters.currency(
                        _totalPendente > 0 ? _totalPendente : saldo),
                    icon: _totalPendente > 0
                        ? Icons.pending_outlined
                        : Icons.account_balance,
                    iconColor: _totalPendente > 0
                        ? AppColors.warning
                        : (saldo >= 0 ? AppColors.success : AppColors.error),
                    subtitle: _totalPendente > 0
                        ? 'Despesas pendentes'
                        : 'Receitas – Despesas',
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
                  const SizedBox(height: 4),
                  Text(
                    hasTransactions
                        ? 'Últimos 6 meses (transações financeiras)'
                        : 'Últimos 6 meses (orçamentos aprovados)',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: _chartData.isEmpty
                        ? const Center(
                            child: Text(
                              'Sem dados para exibir',
                              style:
                                  TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : BarChart(
                            BarChartData(
                              backgroundColor: Colors.transparent,
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: _gridLine,
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
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
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                            _chartData[i].month,
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
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
                                          toY: e.value.income > 0
                                              ? e.value.income / 1000
                                              : 0.05,
                                          color: AppColors.primary,
                                          width: 18,
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
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Approved budgets section
            const Text(
              'Orçamentos Aprovados',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_budgetsAprovados.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Nenhum orçamento aprovado',
                subtitle:
                    'Não há orçamentos com status "Aprovado" ou "Concluído"',
              )
            else
              ..._budgetsAprovados.take(10).map((b) {
                final client = b['clients'];
                final clientName = client is Map
                    ? client['name']?.toString() ?? 'Sem cliente'
                    : 'Sem cliente';
                final budgetNum = b['budget_number']?.toString() ??
                    b['id'].toString().substring(0, 8);
                final valor =
                    double.tryParse(b['valor_venda']?.toString() ?? '0') ??
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
                                'Orç. #$budgetNum',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                clientName,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                AppFormatters.dateFromString(
                                    b['created_at']?.toString()),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
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
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTransacoesTab(bool hasTransactions) {
    if (!hasTransactions) {
      return const EmptyState(
        icon: Icons.swap_horiz_outlined,
        title: 'Sem transações',
        subtitle:
            'Nenhuma transação financeira encontrada.\nAdicione transações via painel web.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = _transactions[i];
          final type = t['type']?.toString() ?? '';
          final amount =
              double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
          final isIncome = type == 'income';
          final status = t['status']?.toString() ?? '';

          return VerinniCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isIncome ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIncome ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['description']?.toString() ??
                            t['category']?.toString() ??
                            (isIncome ? 'Receita' : 'Despesa'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (t['category'] != null)
                        Text(
                          _categoryLabel(t['category'].toString()),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        AppFormatters.dateFromString(
                            t['created_at']?.toString()),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'} ${AppFormatters.currency(amount)}',
                      style: TextStyle(
                        color: isIncome
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (status.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _txStatusLabel(status),
                          style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _categoryLabel(String cat) {
    const map = {
      'salary': 'Salário',
      'fuel': 'Combustível',
      'maintenance': 'Manutenção',
      'material': 'Material',
      'service': 'Serviço',
      'tax': 'Imposto',
      'other': 'Outros',
    };
    return map[cat] ?? cat;
  }

  String _txStatusLabel(String s) {
    switch (s) {
      case 'paid':
        return 'Pago';
      case 'pending':
        return 'Pendente';
      case 'overdue':
        return 'Vencido';
      case 'cancelled':
        return 'Cancelado';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'overdue':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  static FlLine _gridLine(double value) {
    return FlLine(
      color: AppColors.border,
      strokeWidth: 1,
      dashArray: [4, 4],
    );
  }
}

class _ChartPoint {
  final String month;
  final double income;
  final double expense;
  _ChartPoint(this.month, this.income, this.expense);
}
