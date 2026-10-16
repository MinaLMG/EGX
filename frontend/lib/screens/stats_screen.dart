import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../services/wallet_service.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings.dart';

/// Models a wallet's performance stats from the server
class WalletStatItem {
  final String walletId;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime? firstDepositDate;
  final double firstDepositAmount;
  final double totalDeposits;
  final double totalWithdrawals;
  final double totalNetInvestment;
  final double walletValue;
  final double revenue;
  final double revenuePercentage; // 0.25 = 25%
  final double yearlyRevenue; // 0.30 = 30%
  final double totalDuration;

  WalletStatItem({
    required this.walletId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.firstDepositDate,
    required this.firstDepositAmount,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.totalNetInvestment,
    required this.walletValue,
    required this.revenue,
    required this.revenuePercentage,
    required this.yearlyRevenue,
    required this.totalDuration,
  });

  factory WalletStatItem.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['firstDepositDate'] != null) {
      try {
        dt = DateTime.parse(json['firstDepositDate']);
      } catch (_) {}
    }
    return WalletStatItem(
      walletId: json['walletId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'User',
      userEmail: json['userEmail']?.toString() ?? '',
      firstDepositDate: dt,
      firstDepositAmount: (json['firstDepositAmount'] as num?)?.toDouble() ?? 0.0,
      totalDeposits: (json['totalDeposits'] as num?)?.toDouble() ?? 0.0,
      totalWithdrawals: (json['totalWithdrawals'] as num?)?.toDouble() ?? 0.0,
      totalNetInvestment: (json['totalNetInvestment'] as num?)?.toDouble() ?? 0.0,
      walletValue: (json['walletValue'] as num?)?.toDouble() ?? 0.0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      revenuePercentage: (json['revenuePercentage'] as num?)?.toDouble() ?? 0.0,
      yearlyRevenue: (json['yearlyRevenue'] as num?)?.toDouble() ?? 0.0,
      totalDuration: (json['totalDuration'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Models an artificial dummy point calculated along regression line or guessed 2D heatmap
class DummyPointItem {
  final String id;
  final double xVal;
  final DateTime? xDate;
  final double yVal;
  final double returnVal;
  final String label;
  final int statIndex;

  DummyPointItem({
    required this.id,
    required this.xVal,
    this.xDate,
    required this.yVal,
    required this.returnVal,
    required this.label,
    required this.statIndex,
  });
}

/// Linear regression container
class RegressionResult {
  final double slope;
  final double intercept;
  final bool isValid;

  RegressionResult({required this.slope, required this.intercept, required this.isValid});

  double predict(double x) => isValid ? (slope * x + intercept) : 0.0;
}

/// Plotted point on canvas
class ChartPoint {
  final double x;
  final double y;
  final String label;
  final bool isDummy;
  final double returnVal;
  final Color color;
  final double radius;
  final WalletStatItem? walletItem;
  final DummyPointItem? dummyItem;

  ChartPoint({
    required this.x,
    required this.y,
    required this.label,
    required this.isDummy,
    required this.returnVal,
    required this.color,
    required this.radius,
    this.walletItem,
    this.dummyItem,
  });
}

class StatsScreen extends StatefulWidget {
  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final WalletService _walletService = WalletService();
  bool _isLoading = true;
  String? _errorMessage;

  List<WalletStatItem> _allStats = [];
  Set<String> _selectedWalletIds = {};

  // 0: First Deposit vs Return
  // 1: Total Deposits vs Return
  // 2: Heat Map (First Deposit Date vs Total Deposits, bubbles = Return)
  int _currentStatIndex = 0;

  // 'revenue' or 'yearly'
  String _selectedMetric = 'revenue';

  // For Stat 1: 'date' or 'amount'
  String _stat1XMode = 'date';

  // Toggle for linear regression line display
  bool _showRegressionLine = true;

  // Dummy points list
  final List<DummyPointItem> _dummyPoints = [];

  // Currently selected point for inspection
  ChartPoint? _selectedPoint;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _walletService.getAdminStats();
      final items = data.map((json) => WalletStatItem.fromJson(json)).toList();
      if (mounted) {
        setState(() {
          _allStats = items;
          _selectedWalletIds = items.map((w) => w.walletId).toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<WalletStatItem> get _filteredWallets {
    return _allStats.where((w) => _selectedWalletIds.contains(w.walletId)).toList();
  }

  // Linear regression computation
  RegressionResult _calculateRegression(List<ChartPoint> points) {
    if (points.length < 2) {
      return RegressionResult(slope: 0, intercept: 0, isValid: false);
    }

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;
    final int n = points.length;

    for (final p in points) {
      sumX += p.x;
      sumY += p.y;
      sumXY += p.x * p.y;
      sumX2 += p.x * p.x;
    }

    final double denominator = (n * sumX2) - (sumX * sumX);
    if (denominator.abs() < 1e-9) {
      return RegressionResult(slope: 0, intercept: sumY / n, isValid: false);
    }

    final double slope = ((n * sumXY) - (sumX * sumY)) / denominator;
    final double intercept = (sumY - (slope * sumX)) / n;

    return RegressionResult(slope: slope, intercept: intercept, isValid: true);
  }

  /// 2D Model Predictor for Stat 3 (Heatmap):
  /// Given target (X: First Deposit Date, Y: Total Deposits), estimates/guesses the Return %
  /// using Bivariate Multiple Linear Regression (Plane fit) with Inverse Distance Weighting fallback.
  double _predictHeatmapReturn({
    required double targetXDateMillis,
    required double targetTotalDeposits,
    required List<WalletStatItem> wallets,
  }) {
    if (wallets.isEmpty) return 0.0;
    if (wallets.length == 1) {
      final w = wallets.first;
      return (_selectedMetric == 'yearly' ? w.yearlyRevenue : w.revenuePercentage) * 100;
    }

    final List<double> xs = [];
    final List<double> ys = [];
    final List<double> zs = [];

    for (final w in wallets) {
      final dt = w.firstDepositDate ?? DateTime.now();
      xs.add(dt.millisecondsSinceEpoch.toDouble());
      ys.add(w.totalDeposits);
      zs.add((_selectedMetric == 'yearly' ? w.yearlyRevenue : w.revenuePercentage) * 100);
    }

    final double minX = xs.reduce((a, b) => a < b ? a : b);
    final double maxX = xs.reduce((a, b) => a > b ? a : b);
    final double minY = ys.reduce((a, b) => a < b ? a : b);
    final double maxY = ys.reduce((a, b) => a > b ? a : b);

    final spanX = (maxX - minX).abs();
    final spanY = (maxY - minY).abs();

    if (spanX < 1 || spanY < 1) {
      return zs.reduce((a, b) => a + b) / zs.length;
    }

    final normXs = xs.map((x) => (x - minX) / spanX).toList();
    final normYs = ys.map((y) => (y - minY) / spanY).toList();
    final targetNormX = (targetXDateMillis - minX) / spanX;
    final targetNormY = (targetTotalDeposits - minY) / spanY;

    // Try Bivariate Multiple Linear Regression: Z = b0 + b1*normX + b2*normY
    if (wallets.length >= 3) {
      final n = wallets.length.toDouble();
      double sumX = 0, sumY = 0, sumZ = 0;
      double sumXX = 0, sumYY = 0, sumXY = 0;
      double sumXZ = 0, sumYZ = 0;

      for (int i = 0; i < wallets.length; i++) {
        final nx = normXs[i];
        final ny = normYs[i];
        final z = zs[i];
        sumX += nx;
        sumY += ny;
        sumZ += z;
        sumXX += nx * nx;
        sumYY += ny * ny;
        sumXY += nx * ny;
        sumXZ += nx * z;
        sumYZ += ny * z;
      }

      final a11 = n, a12 = sumX, a13 = sumY;
      final a21 = sumX, a22 = sumXX, a23 = sumXY;
      final a31 = sumY, a32 = sumXY, a33 = sumYY;

      final det = a11 * (a22 * a33 - a23 * a32) -
                  a12 * (a21 * a33 - a23 * a31) +
                  a13 * (a21 * a32 - a22 * a31);

      if (det.abs() > 1e-5) {
        final det0 = sumZ * (a22 * a33 - a23 * a32) -
                     a12 * (sumXZ * a33 - a23 * sumYZ) +
                     a13 * (sumXZ * a32 - a22 * sumYZ);

        final det1 = a11 * (sumXZ * a33 - a23 * sumYZ) -
                     sumZ * (a21 * a33 - a23 * a31) +
                     a13 * (a21 * sumYZ - sumXZ * a31);

        final det2 = a11 * (a22 * sumYZ - sumXZ * a32) -
                     a12 * (a21 * sumYZ - sumXZ * a31) +
                     sumZ * (a21 * a32 - a22 * a31);

        final b0 = det0 / det;
        final b1 = det1 / det;
        final b2 = det2 / det;

        final predicted = b0 + b1 * targetNormX + b2 * targetNormY;

        final double minZ = zs.reduce((a, b) => a < b ? a : b);
        final double maxZ = zs.reduce((a, b) => a > b ? a : b);
        final margin = ((maxZ - minZ).abs() * 0.5).clamp(10.0, 50.0);
        if (predicted >= (minZ - margin) && predicted <= (maxZ + margin)) {
          return predicted;
        }
      }
    }

    // Inverse Distance Weighting (IDW) interpolation
    double totalWeight = 0;
    double weightedSumZ = 0;
    for (int i = 0; i < wallets.length; i++) {
      final dx = targetNormX - normXs[i];
      final dy = targetNormY - normYs[i];
      final dist2 = dx * dx + dy * dy;
      if (dist2 < 1e-6) {
        return zs[i];
      }
      final w = 1.0 / dist2;
      totalWeight += w;
      weightedSumZ += w * zs[i];
    }

    if (totalWeight > 0) {
      return weightedSumZ / totalWeight;
    }

    return zs.reduce((a, b) => a + b) / zs.length;
  }

  Color _getReturnColor(double retPct) {
    if (retPct >= 30.0) return const Color(0xFF00E676);
    if (retPct >= 10.0) return const Color(0xFF69F0AE);
    if (retPct >= 0.0) return const Color(0xFFAEEA00);
    if (retPct >= -10.0) return const Color(0xFFFFAB00);
    return const Color(0xFFFF1744);
  }

  List<ChartPoint> _buildPoints() {
    final wallets = _filteredWallets;
    final List<ChartPoint> points = [];

    for (final w in wallets) {
      double x = 0;
      double y = 0;
      double retPct = (_selectedMetric == 'yearly' ? w.yearlyRevenue : w.revenuePercentage) * 100;

      if (_currentStatIndex == 0) {
        // Stat 1: First deposit vs Return
        if (_stat1XMode == 'date') {
          final dt = w.firstDepositDate ?? DateTime.now();
          x = dt.millisecondsSinceEpoch.toDouble();
        } else {
          x = w.firstDepositAmount;
        }
        y = retPct;
      } else if (_currentStatIndex == 1) {
        // Stat 2: Total deposits vs Return
        x = w.totalDeposits;
        y = retPct;
      } else {
        // Stat 3: Heat Map (X: First Deposit Date, Y: Total Deposits, Bubble: Return)
        final dt = w.firstDepositDate ?? DateTime.now();
        x = dt.millisecondsSinceEpoch.toDouble();
        y = w.totalDeposits;
      }

      // Bubble sizing for Stat 3 (magnitude proportional)
      double radius = 10.0;
      if (_currentStatIndex == 2) {
        final mag = retPct.abs();
        radius = (16.0 + (mag * 0.4)).clamp(14.0, 34.0);
      }

      points.add(ChartPoint(
        x: x,
        y: y,
        label: w.userName,
        isDummy: false,
        returnVal: retPct,
        color: _getReturnColor(retPct),
        radius: radius,
        walletItem: w,
      ));
    }

    // Append dummy points created for the current stat
    final activeDummies = _dummyPoints.where((d) => d.statIndex == _currentStatIndex);
    for (final d in activeDummies) {
      final retPct = d.returnVal;
      double radius = 10.0;
      if (_currentStatIndex == 2) {
        final mag = retPct.abs();
        radius = (16.0 + (mag * 0.4)).clamp(14.0, 34.0);
      }
      final color = _getReturnColor(retPct);

      points.add(ChartPoint(
        x: d.xVal,
        y: d.yVal,
        label: d.label,
        isDummy: true,
        returnVal: d.returnVal,
        color: color,
        radius: radius,
        dummyItem: d,
      ));
    }

    return points;
  }

  void _showWalletFilterDialog(AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isAllSelected = _selectedWalletIds.length == _allStats.length;
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.t('select_wallets'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(isAllSelected ? Icons.clear_all : Icons.select_all, size: 16),
                        label: Text(isAllSelected ? l.t('deselect_all') : l.t('select_all')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          setModalState(() {
                            if (isAllSelected) {
                              _selectedWalletIds.clear();
                            } else {
                              _selectedWalletIds = _allStats.map((w) => w.walletId).toSet();
                            }
                          });
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedWalletIds.length}/${_allStats.length} ${l.t('selected_wallets_count')}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _allStats.length,
                      itemBuilder: (context, i) {
                        final w = _allStats[i];
                        final isChecked = _selectedWalletIds.contains(w.walletId);
                        final ret = (_selectedMetric == 'yearly' ? w.yearlyRevenue : w.revenuePercentage) * 100;
                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(w.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('EGP ${NumberFormat('#,###').format(w.totalDeposits)}'),
                          secondary: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getReturnColor(ret).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${ret >= 0 ? "+" : ""}${ret.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: _getReturnColor(ret),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                _selectedWalletIds.add(w.walletId);
                              } else {
                                _selectedWalletIds.remove(w.walletId);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(l.t('apply_filter')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddDummyPointDialog(AppLocalizations l, RegressionResult regression) {
    if (_currentStatIndex != 2 && !regression.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot compute linear regression. Need at least 2 distinct data points.')),
      );
      return;
    }

    if (_currentStatIndex == 2 && _filteredWallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please include at least 1 wallet to guess heatmap return.')),
      );
      return;
    }

    final isHeatmap = _currentStatIndex == 2;
    final isDate = (_currentStatIndex == 0 && _stat1XMode == 'date') || isHeatmap;

    DateTime selectedDate = DateTime.now();
    if (_filteredWallets.isNotEmpty) {
      final dates = _filteredWallets.map((w) => w.firstDepositDate).whereType<DateTime>().toList();
      if (dates.isNotEmpty) {
        selectedDate = dates.last;
      }
    }

    double defaultDeposits = 100000.0;
    if (isHeatmap && _filteredWallets.isNotEmpty) {
      final avg = _filteredWallets.map((w) => w.totalDeposits).reduce((a, b) => a + b) / _filteredWallets.length;
      defaultDeposits = (avg / 1000).round() * 1000.0;
      if (defaultDeposits <= 0) defaultDeposits = 50000.0;
    }

    final amountController = TextEditingController(
      text: isHeatmap ? defaultDeposits.toStringAsFixed(0) : '',
    );
    final defaultLabel = 'User ${_allStats.length + _dummyPoints.length + 1}';
    final labelController = TextEditingController(text: defaultLabel);

    double currentGuess = 0.0;
    if (isHeatmap) {
      currentGuess = _predictHeatmapReturn(
        targetXDateMillis: selectedDate.millisecondsSinceEpoch.toDouble(),
        targetTotalDeposits: defaultDeposits,
        wallets: _filteredWallets,
      );
    }
    final returnController = TextEditingController(
      text: isHeatmap ? currentGuess.toStringAsFixed(2) : '',
    );

    double getXVal() {
      if (isDate) {
        return selectedDate.millisecondsSinceEpoch.toDouble();
      } else {
        return double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
      }
    }

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final x = getXVal();
            final predY = isHeatmap ? 0.0 : regression.predict(x);

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHeatmap ? '${l.t('add_dummy_point')} (${l.t('stat_heatmap')})' : l.t('add_dummy_point'),
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isHeatmap
                          ? l.t('heatmap_dummy_desc')
                          : 'Placed directly along the hidden linear regression line.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        labelText: l.t('dummy_label'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isHeatmap) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text('${l.t('first_deposit_date')} (X): ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2015),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDlgState(() {
                              selectedDate = picked;
                              final dep = double.tryParse(amountController.text.replaceAll(',', '')) ?? defaultDeposits;
                              currentGuess = _predictHeatmapReturn(
                                targetXDateMillis: selectedDate.millisecondsSinceEpoch.toDouble(),
                                targetTotalDeposits: dep,
                                wallets: _filteredWallets,
                              );
                              returnController.text = currentGuess.toStringAsFixed(2);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '${l.t('total_deposits_label')} (Y) [EGP]',
                          hintText: 'e.g. 150000',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final dep = double.tryParse(val.replaceAll(',', '')) ?? 0.0;
                          setDlgState(() {
                            currentGuess = _predictHeatmapReturn(
                              targetXDateMillis: selectedDate.millisecondsSinceEpoch.toDouble(),
                              targetTotalDeposits: dep,
                              wallets: _filteredWallets,
                            );
                            returnController.text = currentGuess.toStringAsFixed(2);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.psychology_alt, size: 18, color: Colors.amber),
                                    const SizedBox(width: 6),
                                    Text(
                                      l.t('guessed_return'),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${currentGuess >= 0 ? "+" : ""}${currentGuess.toStringAsFixed(2)}%',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l.t('guessed_from_model'),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: returnController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: InputDecoration(
                                labelText: l.t('custom_return_pct'),
                                hintText: 'e.g. 25.0',
                                suffixText: '%',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.amber),
                                  tooltip: l.t('recalculate_guess'),
                                  onPressed: () {
                                    final dep = double.tryParse(amountController.text.replaceAll(',', '')) ?? defaultDeposits;
                                    setDlgState(() {
                                      currentGuess = _predictHeatmapReturn(
                                        targetXDateMillis: selectedDate.millisecondsSinceEpoch.toDouble(),
                                        targetTotalDeposits: dep,
                                        wallets: _filteredWallets,
                                      );
                                      returnController.text = currentGuess.toStringAsFixed(2);
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (isDate) ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text('${l.t('pick_date')}: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2015),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDlgState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ] else ...[
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: l.t('enter_x_value'),
                            hintText: 'e.g. 150000',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.t('calculated_y'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${predY >= 0 ? "+" : ""}${predY.toStringAsFixed(2)}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: Text(l.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final xVal = getXVal();
                    final double yVal;
                    final double returnVal;

                    if (isHeatmap) {
                      yVal = double.tryParse(amountController.text.replaceAll(',', '')) ?? defaultDeposits;
                      returnVal = double.tryParse(returnController.text.replaceAll('%', '').trim()) ?? currentGuess;
                    } else {
                      yVal = regression.predict(xVal);
                      returnVal = yVal;
                    }

                    final newDummy = DummyPointItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      xVal: xVal,
                      xDate: isDate ? selectedDate : null,
                      yVal: yVal,
                      returnVal: returnVal,
                      label: labelController.text.trim().isEmpty ? defaultLabel : labelController.text.trim(),
                      statIndex: _currentStatIndex,
                    );
                    setState(() {
                      _dummyPoints.add(newDummy);
                    });
                    Navigator.pop(dlgCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.t('dummy_point_added'))),
                    );
                  },
                  child: Text(l.t('ok')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final isArabic = AppSettings.instance.isArabic;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

        final rawPoints = _buildPoints();
        final regression = _calculateRegression(rawPoints.where((p) => !p.isDummy).toList());

        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l.t('admin_stats')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text('Error: $_errorMessage'),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadData, child: Text(l.t('ok'))),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Top Navigation Tabs for the 3 Stats ──
                            _buildStatSelector(l, primaryColor, isDark),
                            const SizedBox(height: 16),

                            // ── Controls Card (Wallet Filter & Metric Toggle) ──
                            _buildControlsCard(l, primaryColor, isDark),
                            const SizedBox(height: 16),

                            // ── Main Chart Visualizer ──
                            _buildChartCard(l, rawPoints, regression, isDark, primaryColor),
                            const SizedBox(height: 16),

                            // ── Selected Point Details Card ──
                            if (_selectedPoint != null) _buildSelectedPointCard(l, isDark, primaryColor),

                            // ── Dummy Points Management ──
                            _buildDummyManagementCard(l, regression, isDark, primaryColor),
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }

  Widget _buildStatSelector(AppLocalizations l, Color primary, bool isDark) {
    final titles = [
      l.t('stat_first_deposit_vs_return'),
      l.t('stat_total_deposits_vs_return'),
      l.t('stat_deposit_heatmap'),
    ];
    final icons = [
      Icons.show_chart,
      Icons.account_balance,
      Icons.bubble_chart,
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: List.generate(3, (idx) {
          final isSelected = _currentStatIndex == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentStatIndex = idx;
                  _selectedPoint = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[idx],
                      size: 20,
                      color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      titles[idx],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildControlsCard(AppLocalizations l, Color primary, bool isDark) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: Text(
                      '${l.t('selected_wallets_count')}: ${_selectedWalletIds.length}/${_allStats.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showWalletFilterDialog(l),
                  ),
                ),
                const SizedBox(width: 10),
                // Metric Selector (Revenue % vs Yearly Revenue %)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChoiceChip(
                        label: Text(l.t('return_pct'), style: const TextStyle(fontSize: 11)),
                        selected: _selectedMetric == 'revenue',
                        onSelected: (val) {
                          if (val) setState(() => _selectedMetric = 'revenue');
                        },
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: Text(l.t('yearly_return_pct'), style: const TextStyle(fontSize: 11)),
                        selected: _selectedMetric == 'yearly',
                        onSelected: (val) {
                          if (val) setState(() => _selectedMetric = 'yearly');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_currentStatIndex == 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('${l.t('x_axis_mode')}: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(l.t('first_deposit_date'), style: const TextStyle(fontSize: 11)),
                    selected: _stat1XMode == 'date',
                    onSelected: (val) {
                      if (val) setState(() => _stat1XMode = 'date');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(l.t('first_deposit_amount'), style: const TextStyle(fontSize: 11)),
                    selected: _stat1XMode == 'amount',
                    onSelected: (val) {
                      if (val) setState(() => _stat1XMode = 'amount');
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
    AppLocalizations l,
    List<ChartPoint> points,
    RegressionResult regression,
    bool isDark,
    Color primary,
  ) {
    final isDate = (_currentStatIndex == 0 && _stat1XMode == 'date') || (_currentStatIndex == 2);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentStatIndex == 0
                      ? l.t('stat_first_deposit_vs_return')
                      : _currentStatIndex == 1
                          ? l.t('stat_total_deposits_vs_return')
                          : l.t('stat_deposit_heatmap'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primary),
                ),
                Text(
                  l.t('tap_point_hint'),
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Canvas Container with custom painter
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131722) : const Color(0xFFF9F9FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              child: points.isEmpty
                  ? Center(child: Text(l.t('no_data_for_stats')))
                  : LayoutBuilder(
                      builder: (ctx, constraints) {
                        return GestureDetector(
                          onTapUp: (details) {
                            final box = ctx.findRenderObject() as RenderBox?;
                            if (box != null) {
                              final localPos = details.localPosition;
                              _handleChartTap(localPos, constraints.biggest, points, isDate);
                            }
                          },
                          child: CustomPaint(
                            size: constraints.biggest,
                            painter: StatsChartPainter(
                              points: points,
                              isDate: isDate,
                              isHeatmap: _currentStatIndex == 2,
                              showRegressionLine: _showRegressionLine && regression.isValid && _currentStatIndex != 2,
                              regression: regression,
                              selectedPoint: _selectedPoint,
                              isDark: isDark,
                              primaryColor: primary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleChartTap(Offset localPos, Size size, List<ChartPoint> points, bool isDate) {
    if (points.isEmpty) return;

    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    if (maxX == minX) maxX += 1.0;
    if (maxY == minY) maxY += 1.0;

    const padLeft = 56.0;
    const padRight = 24.0;
    const padTop = 24.0;
    const padBottom = 36.0;

    final plotWidth = size.width - padLeft - padRight;
    final plotHeight = size.height - padTop - padBottom;

    ChartPoint? nearest;
    double minDist = 34.0; // Touch threshold in pixels

    for (final p in points) {
      final px = padLeft + ((p.x - minX) / (maxX - minX)) * plotWidth;
      final py = padTop + (1.0 - ((p.y - minY) / (maxY - minY))) * plotHeight;

      final dist = (localPos - Offset(px, py)).distance;
      if (dist < minDist) {
        minDist = dist;
        nearest = p;
      }
    }

    setState(() {
      _selectedPoint = nearest;
    });
  }

  Widget _buildSelectedPointCard(AppLocalizations l, bool isDark, Color primary) {
    final p = _selectedPoint!;
    final w = p.walletItem;
    final d = p.dummyItem;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: p.color,
                      child: const Icon(
                        Icons.person,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p.label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedPoint = null),
                ),
              ],
            ),
            const Divider(),
            if (w != null) ...[
              Text('${l.t('email')}: ${w.userEmail}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l.t('first_deposit_date')}: ${w.firstDepositDate != null ? DateFormat('yyyy-MM-dd').format(w.firstDepositDate!) : "-"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${l.t('first_deposit_amount')}: EGP ${NumberFormat('#,###').format(w.firstDepositAmount)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l.t('total_deposits_label')}: EGP ${NumberFormat('#,###').format(w.totalDeposits)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${l.t('return_pct')}: ${(w.revenuePercentage * 100).toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getReturnColor(w.revenuePercentage * 100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l.t('yearly_return_pct')}: ${(w.yearlyRevenue * 100).toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getReturnColor(w.yearlyRevenue * 100),
                    ),
                  ),
                  Text(
                    '${l.t('effective_value')}: EGP ${NumberFormat('#,###').format(w.walletValue)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ] else if (d != null) ...[
              if (d.statIndex == 2) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l.t('first_deposit_date')}: ${d.xDate != null ? DateFormat('yyyy-MM-dd').format(d.xDate!) : "-"}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${l.t('total_deposits_label')}: EGP ${NumberFormat('#,###').format(d.yVal)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l.t('return_pct')}: ${d.returnVal >= 0 ? "+" : ""}${d.returnVal.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getReturnColor(d.returnVal),
                      ),
                    ),
                    Text(
                      '${l.t('yearly_return_pct')}: ${d.returnVal >= 0 ? "+" : ""}${d.returnVal.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getReturnColor(d.returnVal),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (d.xDate != null)
                      Text(
                        '${l.t('first_deposit_date')}: ${DateFormat('yyyy-MM-dd').format(d.xDate!)}',
                        style: const TextStyle(fontSize: 12),
                      )
                    else
                      Text(
                        '${l.t('first_deposit_amount')}: EGP ${NumberFormat('#,###').format(d.xVal)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    Text(
                      '${l.t('return_pct')}: ${d.yVal >= 0 ? "+" : ""}${d.yVal.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getReturnColor(d.yVal),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDummyManagementCard(
    AppLocalizations l,
    RegressionResult regression,
    bool isDark,
    Color primary,
  ) {
    final activeDummies = _dummyPoints.where((d) => d.statIndex == _currentStatIndex).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l.t('dummy_points'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l.t('add_dummy_point')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _showAddDummyPointDialog(l, regression),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentStatIndex != 2) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.t('show_regression_line'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  Switch(
                    value: _showRegressionLine,
                    activeColor: primary,
                    onChanged: (val) => setState(() => _showRegressionLine = val),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology_alt, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.t('heatmap_dummy_desc'),
                        style: const TextStyle(fontSize: 12, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (activeDummies.isNotEmpty) ...[
              const Divider(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activeDummies.map((d) {
                  final labelText = d.statIndex == 2
                      ? '${d.label} (EGP ${NumberFormat.compact().format(d.yVal)}, ${d.returnVal >= 0 ? "+" : ""}${d.returnVal.toStringAsFixed(1)}%)'
                      : '${d.label} (${d.returnVal >= 0 ? "+" : ""}${d.returnVal.toStringAsFixed(1)}%)';
                  return Chip(
                    avatar: const CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: Icon(Icons.star, size: 12, color: Colors.black),
                    ),
                    label: Text(labelText),
                    deleteIcon: const Icon(Icons.cancel, size: 16),
                    onDeleted: () {
                      setState(() {
                        _dummyPoints.removeWhere((item) => item.id == d.id);
                        if (_selectedPoint?.dummyItem?.id == d.id) {
                          _selectedPoint = null;
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: Text(l.t('clear_dummy_points')),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () {
                    setState(() {
                      _dummyPoints.removeWhere((item) => item.statIndex == _currentStatIndex);
                      _selectedPoint = null;
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Canvas CustomPainter for all 3 stats, supporting regression line and interactive bubble heatmaps
class StatsChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final bool isDate;
  final bool isHeatmap;
  final bool showRegressionLine;
  final RegressionResult regression;
  final ChartPoint? selectedPoint;
  final bool isDark;
  final Color primaryColor;

  StatsChartPainter({
    required this.points,
    required this.isDate,
    required this.isHeatmap,
    required this.showRegressionLine,
    required this.regression,
    required this.selectedPoint,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const padLeft = 56.0;
    const padRight = 24.0;
    const padTop = 24.0;
    const padBottom = 36.0;

    final plotWidth = size.width - padLeft - padRight;
    final plotHeight = size.height - padTop - padBottom;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    // Extents
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    if (maxX == minX) maxX += 1.0;
    if (maxY == minY) maxY += 1.0;

    // Add 10% breathing room to limits
    final xSpan = maxX - minX;
    final ySpan = maxY - minY;
    minX -= xSpan * 0.05;
    maxX += xSpan * 0.05;
    minY -= ySpan * 0.1;
    maxY += ySpan * 0.1;

    double toScreenX(double val) => padLeft + ((val - minX) / (maxX - minX)) * plotWidth;
    double toScreenY(double val) => padTop + (1.0 - ((val - minY) / (maxY - minY))) * plotHeight;

    // Grid paints
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1.0;

    final zeroLinePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.2)
      ..strokeWidth = 1.2;

    final textStyle = TextStyle(
      color: isDark ? Colors.white54 : Colors.black54,
      fontSize: 10,
    );

    // 1. Draw horizontal gridlines & Y labels (5 steps)
    const ySteps = 4;
    for (int i = 0; i <= ySteps; i++) {
      final yVal = minY + (i / ySteps) * (maxY - minY);
      final sy = toScreenY(yVal);

      canvas.drawLine(Offset(padLeft, sy), Offset(size.width - padRight, sy), gridPaint);

      // Label
      final String yText;
      if (isHeatmap) {
        yText = NumberFormat.compact().format(yVal);
      } else {
        yText = '${yVal >= 0 ? "+" : ""}${yVal.toStringAsFixed(0)}%';
      }

      final textSpan = TextSpan(text: yText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(padLeft - textPainter.width - 6, sy - (textPainter.height / 2)));
    }

    // Zero horizontal line if within bounds
    if (minY < 0 && maxY > 0) {
      final zeroY = toScreenY(0.0);
      canvas.drawLine(Offset(padLeft, zeroY), Offset(size.width - padRight, zeroY), zeroLinePaint);
    }

    // 2. Draw vertical gridlines & X labels (4 steps)
    const xSteps = 3;
    for (int i = 0; i <= xSteps; i++) {
      final xVal = minX + (i / xSteps) * (maxX - minX);
      final sx = toScreenX(xVal);

      canvas.drawLine(Offset(sx, padTop), Offset(sx, size.height - padBottom), gridPaint);

      final String xText;
      if (isDate) {
        final dt = DateTime.fromMillisecondsSinceEpoch(xVal.round());
        xText = DateFormat('yy/MM').format(dt);
      } else {
        xText = NumberFormat.compact().format(xVal);
      }

      final textSpan = TextSpan(text: xText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(sx - (textPainter.width / 2), size.height - padBottom + 6));
    }

    // 3. Draw Linear Regression Trendline if enabled
    if (showRegressionLine && regression.isValid) {
      final startY = regression.predict(minX);
      final endY = regression.predict(maxX);

      final linePaint = Paint()
        ..color = Colors.deepPurpleAccent.withOpacity(0.85)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final p1 = Offset(toScreenX(minX), toScreenY(startY));
      final p2 = Offset(toScreenX(maxX), toScreenY(endY));

      canvas.drawLine(p1, p2, linePaint);
    }

    // 4. Draw Points (Real and Dummy)
    for (final p in points) {
      final sx = toScreenX(p.x);
      final sy = toScreenY(p.y);
      final isSelected = selectedPoint != null &&
          ((p.walletItem != null && p.walletItem?.walletId == selectedPoint?.walletItem?.walletId) ||
              (p.dummyItem != null && p.dummyItem?.id == selectedPoint?.dummyItem?.id));

      if (isHeatmap) {
        // Stat 3: Heat Map Bubble with embedded value label (identical for real and dummy)
        final bubblePaint = Paint()
          ..color = p.color.withOpacity(0.85)
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(Offset(sx, sy), p.radius, bubblePaint);
        canvas.drawCircle(Offset(sx, sy), p.radius, borderPaint);

        // Highlight ring if selected
        if (isSelected) {
          final selRing = Paint()
            ..color = Colors.white
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(Offset(sx, sy), p.radius + 4, selRing);
        }

        // Draw return % text directly on the bubble
        final bubbleText = '${p.returnVal >= 0 ? "+" : ""}${p.returnVal.toStringAsFixed(0)}%';
        final tp = TextPainter(
          text: TextSpan(
            text: bubbleText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, Offset(sx - (tp.width / 2), sy - (tp.height / 2)));
      } else {
        // Stat 1 & 2: Circular scatter point (identical for real and dummy)
        final dotPaint = Paint()
          ..color = p.color
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = isDark ? Colors.white70 : Colors.white
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(Offset(sx, sy), p.radius, dotPaint);
        canvas.drawCircle(Offset(sx, sy), p.radius, borderPaint);

        if (isSelected) {
          final selRing = Paint()
            ..color = primaryColor
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(Offset(sx, sy), p.radius + 5, selRing);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant StatsChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedPoint != selectedPoint ||
        oldDelegate.showRegressionLine != showRegressionLine ||
        oldDelegate.isDate != isDate ||
        oldDelegate.isHeatmap != isHeatmap ||
        oldDelegate.isDark != isDark;
  }
}
