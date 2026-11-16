import 'package:flutter/material.dart';

import '../models/history_record.dart';
import '../services/database_service.dart';
import '../utils/date_formats.dart';
import '../widgets/liztia_app_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// Cota inferior única para el selector y la navegación día a día.
  static final DateTime _firstDate = DateTime(2000);

  late DateTime _selectedDate;
  late Future<List<HistoryRecord>> _historyFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _historyFuture = DatabaseService.instance.getHistoryByDate(
      DateFormats.fecha(_selectedDate),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _firstDate,
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _historyFuture = DatabaseService.instance.getHistoryByDate(
        DateFormats.fecha(_selectedDate),
      );
    });
  }

  void _changeDay(int days) {
    if (days > 0 && DateUtils.isSameDay(_selectedDate, DateTime.now())) {
      return;
    }
    final next = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + days,
    );
    if (next.isBefore(_firstDate)) return;
    setState(() {
      _selectedDate = next;
      _historyFuture = DatabaseService.instance.getHistoryByDate(
        DateFormats.fecha(_selectedDate),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const LiztiaAppBar(title: 'Historial'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeDay(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Día anterior',
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormats.displayDate(_selectedDate)),
                  ),
                ),
                IconButton(
                  onPressed: isToday ? null : () => _changeDay(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Día siguiente',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<HistoryRecord>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'No se pudo cargar el historial',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final records = snapshot.data ?? const <HistoryRecord>[];
                if (records.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay registros para la fecha',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return ListTile(
                      key: ValueKey(record.id),
                      leading: const Icon(Icons.person),
                      title: Text('${record.nombre} ${record.apellido}'.trim()),
                      subtitle: Text(
                        DateFormats.displayTimestamp(record.timestamp),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
