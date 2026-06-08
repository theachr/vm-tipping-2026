// Flagg-emoji for kvart landslag (openfootball-engelske namn).
// Dei fleste er ISO 3166-1 alpha-2 -> regional indicator-bokstavar.
// England og Skottland har eigne subdivisjons-emoji.

const _iso2 = {
  'Mexico': 'MX',
  'South Africa': 'ZA',
  'South Korea': 'KR',
  'Czech Republic': 'CZ',
  'Canada': 'CA',
  'Switzerland': 'CH',
  'Bosnia & Herzegovina': 'BA',
  'Qatar': 'QA',
  'USA': 'US',
  'Paraguay': 'PY',
  'Australia': 'AU',
  'Turkey': 'TR',
  'Brazil': 'BR',
  'Morocco': 'MA',
  'Haiti': 'HT',
  'Germany': 'DE',
  'Ecuador': 'EC',
  'Ivory Coast': 'CI',
  'Curaçao': 'CW',
  'Netherlands': 'NL',
  'Japan': 'JP',
  'Sweden': 'SE',
  'Tunisia': 'TN',
  'Spain': 'ES',
  'Uruguay': 'UY',
  'Saudi Arabia': 'SA',
  'Cape Verde': 'CV',
  'Belgium': 'BE',
  'Iran': 'IR',
  'Egypt': 'EG',
  'New Zealand': 'NZ',
  'France': 'FR',
  'Norway': 'NO',
  'Senegal': 'SN',
  'Iraq': 'IQ',
  'Argentina': 'AR',
  'Austria': 'AT',
  'Algeria': 'DZ',
  'Jordan': 'JO',
  'Portugal': 'PT',
  'Colombia': 'CO',
  'Uzbekistan': 'UZ',
  'DR Congo': 'CD',
  'Croatia': 'HR',
  'Ghana': 'GH',
  'Panama': 'PA',
};

// Subdivisjons-flagg (tag-sekvensar).
const _special = {
  'England': '\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}',
  'Scotland': '\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}',
};

String _fromIso2(String code) {
  const base = 0x1F1E6;
  final cp = code.toUpperCase().codeUnits
      .map((c) => String.fromCharCode(base + (c - 0x41)))
      .join();
  return cp;
}

/// Flagg-emoji for eit lag, eller eit jordklode-fallback om ukjent.
String flagFor(String team) {
  if (_special.containsKey(team)) return _special[team]!;
  final iso = _iso2[team];
  if (iso != null) return _fromIso2(iso);
  return '\u{1F310}'; // 🌐
}
