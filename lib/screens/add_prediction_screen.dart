import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prediction.dart';
import '../viewmodels/matches_view_model.dart';
import '../viewmodels/predictions_view_model.dart';

class AddPredictionScreen extends ConsumerStatefulWidget {
  final String? initialMatchLabel;
  final double? homeOdds;
  final double? drawOdds;
  final double? awayOdds;
  final int? fixtureId;
  final DateTime? kickoffUtc;

  const AddPredictionScreen({
    super.key,
    this.initialMatchLabel,
    this.homeOdds,
    this.drawOdds,
    this.awayOdds,
    this.fixtureId,
    this.kickoffUtc,
  });

  @override
  ConsumerState<AddPredictionScreen> createState() =>
      _AddPredictionScreenState();
}

class _AddPredictionScreenState extends ConsumerState<AddPredictionScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _matchCtrl   = TextEditingController();
  final _oddsCtrl    = TextEditingController();
  final _stakeCtrl   = TextEditingController();
  final _commentCtrl = TextEditingController();

  String _selection  = '1';
  int    _confidence = 3;

  bool get _fromMatch => widget.initialMatchLabel != null;

  double? get _currentOdds =>
      double.tryParse(_oddsCtrl.text.trim().replaceAll(',', '.'));
  double? get _currentStake =>
      double.tryParse(_stakeCtrl.text.trim().replaceAll(',', '.'));
  double? get _potentialGain {
    final o = _currentOdds;
    final s = _currentStake;
    if (o == null || s == null) return null;
    return s * o;
  }

  @override
  void initState() {
    super.initState();
    if (_fromMatch) _matchCtrl.text = widget.initialMatchLabel!;
    _syncOdds();
    _oddsCtrl.addListener(() => setState(() {}));
    _stakeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _matchCtrl.dispose();
    _oddsCtrl.dispose();
    _stakeCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _syncOdds() {
    final odds = switch (_selection) {
      '1' => widget.homeOdds,
      'N' => widget.drawOdds,
      _   => widget.awayOdds,
    };
    if (odds != null) _oddsCtrl.text = odds.toStringAsFixed(2);
  }

  bool get _bettingClosed {
    if (widget.kickoffUtc == null) return false;
    return widget.kickoffUtc!.difference(DateTime.now().toUtc()).inMinutes < 5;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_bettingClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paris fermés — moins de 5 min avant le coup d\'envoi'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final prediction = Prediction(
      id:          DateTime.now().millisecondsSinceEpoch.toString(),
      matchLabel:  _matchCtrl.text.trim(),
      selection:   _selection,
      odds:        double.parse(_oddsCtrl.text.trim().replaceAll(',', '.')),
      stake:       _currentStake,
      comment:     _commentCtrl.text.trim(),
      confidence:  _confidence,
      createdAt:   DateTime.now(),
      fixtureId:   widget.fixtureId,
      kickoffUtc:  widget.kickoffUtc,
    );

    await ref.read(predictionsProvider.notifier).add(prediction);

    if (mounted) {
      ref.read(selectedTabProvider.notifier).state = 0;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pronostic enregistré ✓'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String? get _kickoffWarning {
    if (widget.kickoffUtc == null) return null;
    final diff = widget.kickoffUtc!.difference(DateTime.now().toUtc());
    if (diff.inMinutes < 0) return 'Match déjà commencé — pari refusé';
    if (diff.inMinutes < 5) return 'Paris fermés dans moins de 5 minutes';
    if (diff.inMinutes < 30) {
      final m = diff.inMinutes;
      return 'Paris ferment dans $m min';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warning = _kickoffWarning;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: const Text('Nouveau pronostic',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Avertissement fermeture des paris ──────────────────
              if (warning != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _bettingClosed
                        ? const Color(0xFFDC2626).withValues(alpha: 0.10)
                        : Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _bettingClosed
                          ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _bettingClosed
                            ? Icons.lock_rounded
                            : Icons.timer_outlined,
                        size: 16,
                        color: _bettingClosed
                            ? const Color(0xFFDC2626)
                            : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _bettingClosed
                                ? const Color(0xFFDC2626)
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Match ──────────────────────────────────────────────
              TextFormField(
                controller: _matchCtrl,
                readOnly: _fromMatch,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Match',
                  hintText: 'ex : Arsenal - Chelsea',
                  suffixIcon: _fromMatch
                      ? const Icon(Icons.lock_outline, size: 18)
                      : null,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 24),

              // ── Sélection 1 / N / 2 ────────────────────────────────
              const Text('Pronostic',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '1', label: Text('1 – Dom.')),
                  ButtonSegment(value: 'N', label: Text('N – Nul')),
                  ButtonSegment(value: '2', label: Text('2 – Ext.')),
                ],
                selected: {_selection},
                onSelectionChanged: (s) => setState(() {
                  _selection = s.first;
                  _syncOdds();
                }),
              ),
              const SizedBox(height: 24),

              // ── Cote + Mise côte à côte ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _oddsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cote',
                        hintText: '1.90',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requis';
                        final d = double.tryParse(v.trim().replaceAll(',', '.'));
                        if (d == null || d <= 1.0) return '> 1.0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stakeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Mise (€)',
                        hintText: 'ex : 10',
                      ),
                    ),
                  ),
                ],
              ),

              // ── Gain potentiel ──────────────────────────────────────
              if (_potentialGain != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gain potentiel',
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w500)),
                      Text(
                        '${_potentialGain!.toStringAsFixed(2)} €',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // ── Confiance ───────────────────────────────────────────
              Row(
                children: [
                  const Text('Confiance',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('$_confidence / 5',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _confidence.toDouble(),
                min: 1, max: 5, divisions: 4,
                label: '$_confidence',
                onChanged: (v) => setState(() => _confidence = v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => Icon(
                  i < _confidence ? Icons.star : Icons.star_border,
                  color: Colors.amber, size: 28,
                )),
              ),
              const SizedBox(height: 24),

              // ── Commentaire ─────────────────────────────────────────
              TextFormField(
                controller: _commentCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Commentaire (optionnel)',
                  hintText: 'ex : Arsenal solide à domicile.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // ── Bouton enregistrer ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Enregistrer',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
