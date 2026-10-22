import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/storage.dart';
import '../../services/zakat_service.dart';

/// Zakat al-mal calculator (2.5% of net zakatable wealth above the nisab).
class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});
  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  static const _keys = ['cash', 'gold', 'silver', 'invest', 'recv', 'debts', 'goldPrice', 'silverPrice'];
  late final Map<String, TextEditingController> _c = {
    for (final k in _keys) k: TextEditingController(text: Store.getJson('w_zakat')?[k] as String? ?? ''),
  };
  late final TextEditingController _currency = TextEditingController(text: Store.getJson('w_zakat')?['cur'] as String? ?? 'TND');
  int _karat = (Store.getJson('w_zakat')?['karat'] as int?) ?? 21;
  bool _silver = (Store.getJson('w_zakat')?['silverNisab'] as bool?) ?? false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _currency.dispose();
    super.dispose();
  }

  double _v(String k) => double.tryParse(Fmt.western(_c[k]!.text.trim()).replaceAll(',', '')) ?? 0;

  void _changed() {
    Store.setJson('w_zakat', {for (final k in _keys) k: _c[k]!.text, 'cur': _currency.text, 'karat': _karat, 'silverNisab': _silver});
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final cur = _currency.text.trim().isEmpty ? 'TND' : _currency.text.trim();
    final r = ZakatService.compute(ZakatInput(
      cash: _v('cash'),
      goldGrams: _v('gold'),
      goldKarat: _karat,
      silverGrams: _v('silver'),
      investments: _v('invest'),
      receivables: _v('recv'),
      debts: _v('debts'),
      goldPricePerGram: _v('goldPrice'),
      silverPricePerGram: _v('silverPrice'),
      useSilverNisab: _silver,
    ));
    String money(double v) => '${Fmt.number(v, decimals: 2)} $cur';

    return NoorPage(
      title: 'حاسبة الزكاة',
      subtitle: 'زكاة المال',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Glass(
          radius: 28,
          tint: r.due ? p.accent : null,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(children: [
            Text('الزكاة الواجبة', style: NoorText.label(context)),
            const SizedBox(height: 4),
            Text(money(r.zakat), style: NoorText.number(context, size: 32, w: FontWeight.w700).copyWith(color: r.due ? p.accent : p.text)),
            const SizedBox(height: 6),
            Text(
              !r.nisabKnown
                  ? 'أدخل سعر غرام ${_silver ? 'الفضة' : 'الذهب'} لمعرفة النصاب'
                  : (r.due ? 'بلغ مالك النصاب: الزكاة 2.5% من صافي المال' : 'لم يبلغ صافي مالك النصاب، فلا زكاة عليه'),
              textAlign: TextAlign.center,
              style: NoorText.caption(context),
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: p.hairline),
            const SizedBox(height: 10),
            _row(context, 'إجمالي الأموال', money(r.total)),
            _row(context, 'صافي المال بعد الديون', money(r.net)),
            _row(context, 'النصاب (${_silver ? '595 غ فضة' : '85 غ ذهب'})', r.nisabKnown ? money(r.nisab) : '—'),
          ]),
        ),
        const SectionHeader('الأسعار والعملة', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
        Row(children: [
          Expanded(flex: 2, child: _field(context, 'goldPrice', 'سعر غرام الذهب عيار 24', PhosphorIconsRegular.coins)),
          const SizedBox(width: 10),
          Expanded(child: _textField(context, _currency, 'العملة')),
        ]),
        _field(context, 'silverPrice', 'سعر غرام الفضة', PhosphorIconsRegular.coinVertical),
        const SizedBox(height: 4),
        Text('النصاب على أساس', style: NoorText.label(context)),
        const SizedBox(height: 8),
        ChipBar(
          labels: const ['الذهب (85 غ)', 'الفضة (595 غ)'],
          index: _silver ? 1 : 0,
          padding: EdgeInsets.zero,
          onChanged: (i) {
            _silver = i == 1;
            _changed();
          },
        ),
        const SectionHeader('أموالك', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
        _field(context, 'cash', 'النقود والأرصدة البنكية', PhosphorIconsRegular.wallet),
        _field(context, 'gold', 'الذهب (بالغرام)', PhosphorIconsRegular.diamond, unit: 'غ'),
        ChipBar(
          labels: const ['عيار 24', 'عيار 21', 'عيار 18'],
          index: const [24, 21, 18].indexOf(_karat),
          padding: EdgeInsets.zero,
          onChanged: (i) {
            _karat = const [24, 21, 18][i];
            _changed();
          },
        ),
        const SizedBox(height: 10),
        _field(context, 'silver', 'الفضة (بالغرام)', PhosphorIconsRegular.coinVertical, unit: 'غ'),
        _field(context, 'invest', 'الاستثمارات وعروض التجارة والأسهم', PhosphorIconsRegular.chartLineUp),
        _field(context, 'recv', 'الديون المرجو تحصيلها (لك)', PhosphorIconsRegular.handCoins),
        _field(context, 'debts', 'الديون الحالّة عليك', PhosphorIconsRegular.minusCircle),
        const SectionHeader('كيف تُحسب الزكاة؟', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
        Glass(
          radius: 22,
          child: Text(
            '• تجب الزكاة في المال إذا بلغ النصاب وحال عليه الحول (سنة هجرية كاملة).\n'
            '• النصاب: قيمة 85 غرامًا من الذهب الخالص أو 595 غرامًا من الفضة، ويرى بعض العلماء اعتماد نصاب الفضة لأنه أنفع للفقراء.\n'
            '• يُجمع المال الزكوي (النقود، الذهب والفضة، عروض التجارة، الديون المرجوّة) ويُطرح منه الدين الحالّ.\n'
            '• يُحوَّل الذهب غير الخالص إلى خالص: الوزن × العيار ÷ 24.\n'
            '• مقدار الزكاة ربع العشر: 2.5% من صافي المال.\n'
            '• لا زكاة في الحليّ المعدّ للاستعمال عند جمهور العلماء، وأوجبها الحنفية؛ فاسأل أهل العلم في بلدك عند الحاجة.',
            style: NoorText.body(context).copyWith(height: 1.9),
          ),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: NoorText.body(context).copyWith(fontSize: 13.5))),
          Text(v, style: NoorText.number(context, size: 14)),
        ]),
      );

  Widget _field(BuildContext context, String key, String label, IconData icon, {String? unit}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Glass(
          radius: 18,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(children: [
            Icon(icon, size: 19, color: context.noor.accent),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _c[key],
                onChanged: (_) => _changed(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_WesternDigits(), FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: NoorText.number(context, size: 15),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: NoorText.caption(context).copyWith(fontSize: 12.5),
                  border: InputBorder.none,
                  suffixText: unit,
                  hintText: '0',
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _textField(BuildContext context, TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Glass(
          radius: 18,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: c,
            onChanged: (_) => _changed(),
            maxLength: 6,
            style: NoorText.number(context, size: 15),
            decoration: InputDecoration(labelText: label, border: InputBorder.none, counterText: '', labelStyle: NoorText.caption(context)),
          ),
        ),
      );
}

/// Converts any Arabic-Indic digits typed by the user to Western digits.
class _WesternDigits extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = Fmt.western(newValue.text).replaceAll('٫', '.');
    return t == newValue.text ? newValue : newValue.copyWith(text: t);
  }
}
