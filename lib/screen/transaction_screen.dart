import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/section_card.dart';
import '../utils/status_badge.dart';
import '../models/transactions.dart';

List<Transaction> _sampleTransactions() {
  final now = DateTime.now();
  return [];
}

enum TransactionTypeFilter { all, receive, release }

extension _TransactionTypeFilterLabel on TransactionTypeFilter {
  String get label {
    switch (this) {
      case TransactionTypeFilter.all:
        return 'All Types';
      case TransactionTypeFilter.receive:
        return 'Receive';
      case TransactionTypeFilter.release:
        return 'Release';
    }
  }
}

enum TransactionSort { recentlyAdded, oldestFirst }

extension _TransactionSortLabel on TransactionSort {
  String get label {
    switch (this) {
      case TransactionSort.recentlyAdded:
        return 'Recently Added';
      case TransactionSort.oldestFirst:
        return 'Oldest First';
    }
  }
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<Transaction> _transactions;

  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;
  TransactionSort _sortOption = TransactionSort.recentlyAdded;

  @override
  void initState() {
    super.initState();
    _transactions = _sampleTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> get _filteredTransactions {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _transactions.where((t) {
      final matchesQuery =
          query.isEmpty || t.billNo.toLowerCase().contains(query);

      final matchesType = switch (_typeFilter) {
        TransactionTypeFilter.all => true,
        TransactionTypeFilter.receive => t.type.toLowerCase() == 'receive',
        TransactionTypeFilter.release => t.type.toLowerCase() == 'release',
      };

      return matchesQuery && matchesType;
    }).toList();

    switch (_sortOption) {
      case TransactionSort.recentlyAdded:
        filtered.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateComp = dateB.compareTo(dateA);
          if (dateComp != 0) return dateComp;
          return (b.id ?? 0).compareTo(a.id ?? 0);
        });
        break;
      case TransactionSort.oldestFirst:
        filtered.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateComp = dateA.compareTo(dateB);
          if (dateComp != 0) return dateComp;
          return (a.id ?? 0).compareTo(b.id ?? 0);
        });
        break;
    }

    return filtered;
  }

  void _onReceive() {
    // Hook up your own "add transaction" flow here.
    setState(() {
      _transactions.insert(
        0,
        Transaction(
          id: _transactions.length + 1,
          billNo: 'RCV-2026-NEW${_transactions.length + 1}',
          type: 'Receive',
          totalItems: 0,
          createdByName: 'You',
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  void _onRelease() {
    // Hook up your own "add transaction" flow here.
    setState(() {
      _transactions.insert(
        0,
        Transaction(
          id: _transactions.length + 1,
          billNo: 'REL-2026-NEW${_transactions.length + 1}',
          type: 'Release',
          totalItems: 0,
          createdByName: 'You',
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  void _showTransactionDetails(Transaction t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t.billNo, style: AppTextStyles.h3),
        content: Text(
          'Type: ${t.type}\nTotal items: ${t.formattedTotalItems}\n'
          'Created by: ${t.createdByName ?? 'Unknown'}',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 600;
    final horizontalPadding = compact ? 16.0 : 32.0;

    String subtitleText;
    if (filtered.length != _transactions.length) {
      subtitleText = '${filtered.length} of ${_transactions.length} transactions';
    } else {
      subtitleText = '${_transactions.length} total stock transactions';
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding:
                EdgeInsets.fromLTRB(horizontalPadding, 28, horizontalPadding, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(title: 'Transactions', subtitle: subtitleText),
                const SizedBox(height: AppSpacing.lg),
                _buildFilterBar(),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                  child: filtered.isEmpty
                      ? SizedBox(
                          height: 200,
                          child: Center(
                            child: Text(
                              _transactions.isEmpty
                                  ? 'No transactions recorded yet. Click "Receive" or "Release" to create one.'
                                  : 'No transactions match your search or filter criteria.',
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : compact
                          ? _buildMobileTransactionList(filtered)
                          : _buildDesktopTransactionTable(filtered),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _onReceive,
                      icon: const Icon(Icons.call_received_rounded,
                          color: Colors.white, size: 20),
                      label: Text(
                        'Receive',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _onRelease,
                      icon: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 20),
                      label: Text(
                        'Release',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final compact = MediaQuery.of(context).size.width < 600;

    final searchField = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration.collapsed(
                hintText: 'Search bill number...',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
              style: AppTextStyles.body,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {});
              },
              child: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textMuted),
            ),
        ],
      ),
    );

    final typeDropdown = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TransactionTypeFilter>(
          value: _typeFilter,
          icon: const Icon(Icons.filter_list_rounded,
              size: 18, color: AppColors.textSecondary),
          style: AppTextStyles.body,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          isExpanded: compact,
          items: TransactionTypeFilter.values
              .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
              .toList(),
          onChanged: (v) =>
              setState(() => _typeFilter = v ?? TransactionTypeFilter.all),
        ),
      ),
    );

    final sortDropdown = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TransactionSort>(
          value: _sortOption,
          icon: const Icon(Icons.swap_vert_rounded,
              size: 18, color: AppColors.textSecondary),
          style: AppTextStyles.body,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          isExpanded: compact,
          items: TransactionSort.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
              .toList(),
          onChanged: (v) =>
              setState(() => _sortOption = v ?? TransactionSort.recentlyAdded),
        ),
      ),
    );

    if (compact) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: typeDropdown),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: sortDropdown),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: AppSpacing.md),
        typeDropdown,
        const SizedBox(width: AppSpacing.md),
        sortDropdown,
      ],
    );
  }

  Widget _buildMobileTransactionList(List<Transaction> transactions) {
    return Column(
      children: transactions.map((t) {
        final isInbound = t.type.toLowerCase() == 'receive';
        final dateStr = t.createdAt != null
            ? '${t.createdAt!.year}-${t.createdAt!.month.toString().padLeft(2, '0')}-${t.createdAt!.day.toString().padLeft(2, '0')}'
            : 'N/A';

        return Column(
          children: [
            InkWell(
              onTap: () => _showTransactionDetails(t),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            t.billNo,
                            style: AppTextStyles.mono.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: isInbound ? 'Receive' : 'Release',
                          tone: isInbound ? BadgeTone.success : BadgeTone.danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.person_outline_rounded,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            t.createdByName ?? 'Unknown',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.neutralSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${t.formattedTotalItems} total items',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDesktopTransactionTable(List<Transaction> transactions) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(flex: 4, child: Text('BILL NO.', style: AppTextStyles.label)),
              Expanded(flex: 2, child: Text('TYPE', style: AppTextStyles.label)),
              Expanded(flex: 3, child: Text('CREATED BY', style: AppTextStyles.label)),
              Expanded(
                flex: 2,
                child: Text('TOTAL ITEMS',
                    textAlign: TextAlign.right, style: AppTextStyles.label),
              ),
            ],
          ),
        ),
        const Divider(height: 0.6, thickness: 0.6),
        ...transactions.expand((t) {
          final isInbound = t.type.toLowerCase() == 'receive';
          final dateStr = t.createdAt != null
              ? '${t.createdAt!.year}-${t.createdAt!.month.toString().padLeft(2, '0')}-${t.createdAt!.day.toString().padLeft(2, '0')}'
              : 'N/A';

          return [
            InkWell(
              onTap: () => _showTransactionDetails(t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.billNo,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.mono.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: StatusBadge(
                        label: isInbound ? 'Receive' : 'Release',
                        tone: isInbound ? BadgeTone.success : BadgeTone.danger,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        t.createdByName ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        t.formattedTotalItems,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 0.6, thickness: 0.6),
          ];
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Optional: quick runnable demo
// ---------------------------------------------------------------------------
void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transactions Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.primary),
      home: const Scaffold(body: TransactionsScreen()),
    );
  }
}