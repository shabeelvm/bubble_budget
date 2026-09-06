/// Currency catalogue for the Settings picker.
///
/// Deliberately a curated set rather than all ~180 ISO currencies: a full list
/// needs a searchable picker and implies conversion this app does not do.
/// At 52 entries this grid is at about its ceiling - grouped and scrollable it
/// still scans, but a further expansion should add search rather than rows.
///
/// Each entry carries its ISO code, which is what makes colliding glyphs
/// distinguishable in the UI (JPY vs CNY both use a yen sign; four Nordic
/// currencies use "kr"), and its minor-unit digit count, which several
/// currencies set to 0.
class Currency {
  final String symbol;
  final String code;

  /// Minor-unit digits. 0 for currencies with no subunit in practice.
  final int decimals;

  const Currency(this.symbol, this.code, this.decimals);
}

class CurrencyGroup {
  final String title;
  final List<Currency> items;

  const CurrencyGroup(this.title, this.items);
}

const List<CurrencyGroup> kCurrencyGroups = <CurrencyGroup>[
  CurrencyGroup('Americas & Europe', <Currency>[
    Currency('\$', 'USD', 2),
    Currency('€', 'EUR', 2),
    Currency('£', 'GBP', 2),
    Currency('C\$', 'CAD', 2),
    Currency('CHF', 'CHF', 2),
    Currency('kr', 'SEK', 2),
    Currency('zł', 'PLN', 2),
    Currency('R\$', 'BRL', 2),
    Currency('Mex\$', 'MXN', 2),
    Currency('₽', 'RUB', 2),
    Currency('kr', 'NOK', 2),
    Currency('kr', 'DKK', 2),
    Currency('Kč', 'CZK', 2),
    Currency('Ft', 'HUF', 2),
    Currency('lei', 'RON', 2),
    Currency('₴', 'UAH', 2),
    Currency('CLP\$', 'CLP', 0),
    Currency('COL\$', 'COP', 2),
    Currency('AR\$', 'ARS', 2),
  ]),
  CurrencyGroup('Asia-Pacific', <Currency>[
    Currency('A\$', 'AUD', 2),
    Currency('NZ\$', 'NZD', 2),
    Currency('₹', 'INR', 2),
    Currency('¥', 'JPY', 0),
    Currency('CN¥', 'CNY', 2),
    Currency('₩', 'KRW', 0),
    Currency('S\$', 'SGD', 2),
    Currency('HK\$', 'HKD', 2),
    Currency('Rp', 'IDR', 0),
    Currency('₱', 'PHP', 2),
    Currency('฿', 'THB', 2),
    Currency('₫', 'VND', 0),
    Currency('RM', 'MYR', 2),
    Currency('₨', 'PKR', 2),
    Currency('৳', 'BDT', 2),
    Currency('NT\$', 'TWD', 2),
    Currency('Rs', 'LKR', 2),
    Currency('NRs', 'NPR', 2),
  ]),
  CurrencyGroup('Middle East & Africa', <Currency>[
    // SR and AED rather than the Arabic glyphs, which can render with
    // unexpected directionality inside an LTR Text.
    Currency('SR', 'SAR', 2),
    Currency('AED', 'AED', 2),
    // Gulf dinars use 1000 fils, not 100 - three decimals, not two. Getting
    // this wrong shows KD240.00 for what should be KD240.000.
    Currency('KD', 'KWD', 3),
    Currency('BD', 'BHD', 3),
    Currency('RO', 'OMR', 3),
    Currency('JD', 'JOD', 3),
    Currency('QR', 'QAR', 2),
    Currency('₺', 'TRY', 2),
    Currency('₪', 'ILS', 2),
    Currency('R', 'ZAR', 2),
    Currency('₦', 'NGN', 2),
    Currency('E£', 'EGP', 2),
    Currency('KSh', 'KES', 2),
    Currency('₵', 'GHS', 2),
    Currency('DH', 'MAD', 2),
  ]),
];

const Currency kFallbackCurrency = Currency('\$', 'USD', 2);

/// Looks a currency up by ISO code. Returns the USD fallback for an unknown or
/// empty code, which is what installs from before the picker existed will have.
Currency currencyForCode(String code) {
  for (final CurrencyGroup g in kCurrencyGroups) {
    for (final Currency c in g.items) {
      if (c.code == code) return c;
    }
  }
  return kFallbackCurrency;
}
