/// The 11 model inputs, grouped into 4 sections. Ranges mirror the Pydantic model in API/prediction.py
/// (percent fields are shown 0–100 and sent as 0–1).
enum Kind { code, count, money, percent }

class Option {
  const Option(this.code, this.label);
  final int code;
  final String label;
}

class FieldSpec {
  const FieldSpec(this.key, this.section, this.kind, this.label, this.helper, this.hint, this.min, this.max,
      {this.chips = const [], this.short = ''});
  final String key, label, helper, hint, short;
  final int section;
  final Kind kind;
  final num min, max;
  final List<Option> chips;

  bool get isInt => kind == Kind.code || kind == Kind.count;
}

const sectionTitles = ['School type', 'Size & cost', 'Students', 'Outcomes & staff'];

const fields = [
  FieldSpec('CONTROL', 0, Kind.code, 'Who runs the school?', 'Tap a chip or type 1–3', '1–3', 1, 3,
      chips: [Option(1, 'Public'), Option(2, 'Private nonprofit'), Option(3, 'For-profit')]),
  FieldSpec('PREDDEG', 0, Kind.code, 'Main degree awarded', 'Tap a chip or type 1–3', '1–3', 1, 3,
      chips: [Option(1, 'Certificate'), Option(2, 'Associate'), Option(3, "Bachelor's")]),
  FieldSpec('REGION', 0, Kind.code, 'Region', 'Type 1–9 or pick from the list', '1–9', 1, 9),
  FieldSpec('UGDS', 1, Kind.count, 'Undergraduate students', 'Number of undergraduates enrolled', 'e.g. 2,030', 1, 200000,
      short: 'students'),
  FieldSpec('TUITIONFEE_IN', 1, Kind.money, 'In-state tuition per year', 'Tuition and fees for in-state students, 0 – 100,000',
      'e.g. 12,000', 0, 100000, short: 'tuition'),
  FieldSpec('INEXPFTE', 1, Kind.money, 'Teaching spend per student', 'Instructional spending per full-time student',
      'e.g. 9,500', 0, 300000, short: 'per student'),
  FieldSpec('PCTFLOAN', 2, Kind.percent, 'Students who take federal loans', 'Share of undergraduates with a federal loan',
      'e.g. 40', 0, 100, short: 'loans'),
  FieldSpec('PCTPELL', 2, Kind.percent, 'Students with Pell grants', 'Share of undergraduates receiving a Pell grant',
      'e.g. 35', 0, 100, short: 'Pell'),
  FieldSpec('UG25ABV', 2, Kind.percent, 'Students aged 25 or older', 'Share of undergraduates aged 25 and over', 'e.g. 12',
      0, 100, short: 'aged 25+'),
  FieldSpec('MD_EARN_WNE_P10', 3, Kind.money, 'Median earnings 10 years after entry',
      'Typical earnings of former students, 10,000 – 200,000', 'e.g. 55,000', 10000, 200000, short: 'earnings'),
  FieldSpec('AVGFACSAL', 3, Kind.money, 'Average faculty salary per month', 'Monthly pay of teaching staff, 500 – 30,000',
      'e.g. 8,500', 500, 30000, short: '/mo faculty'),
];

FieldSpec spec(String key) => fields.firstWhere((f) => f.key == key);
List<FieldSpec> fieldsOf(int section) => fields.where((f) => f.section == section).toList();

class Region {
  const Region(this.code, this.name, this.states);
  final int code;
  final String name, states;
}

const regions = [
  Region(1, 'New England', 'CT, ME, MA, NH, RI, VT'),
  Region(2, 'Mid East', 'DE, DC, MD, NJ, NY, PA'),
  Region(3, 'Great Lakes', 'IL, IN, MI, OH, WI'),
  Region(4, 'Plains', 'IA, KS, MN, MO, NE, ND, SD'),
  Region(5, 'Southeast', 'AL, AR, FL, GA, KY, LA, MS, NC, SC, TN, VA, WV'),
  Region(6, 'Southwest', 'AZ, NM, OK, TX'),
  Region(7, 'Rocky Mountains', 'CO, ID, MT, UT, WY'),
  Region(8, 'Far West', 'AK, CA, HI, NV, OR, WA'),
  Region(9, 'Outlying areas', 'Puerto Rico, Guam, U.S. Virgin Islands, American Samoa'),
];

class Example {
  const Example(this.label, this.values);
  final String label;
  final Map<String, String> values; // as the user would type them
}

/// Real schools from the cleaned dataset, each the closest to its group's median profile.
const examples = [
  Example('Public university', {
    'CONTROL': '1', 'PREDDEG': '3', 'REGION': '5', 'UGDS': '10,074', 'TUITIONFEE_IN': '10,762', 'INEXPFTE': '10,232',
    'PCTFLOAN': '38.1', 'PCTPELL': '38.7', 'UG25ABV': '9.1', 'MD_EARN_WNE_P10': '56,442', 'AVGFACSAL': '10,181',
  }),
  Example('Private college', {
    'CONTROL': '2', 'PREDDEG': '3', 'REGION': '4', 'UGDS': '1,175', 'TUITIONFEE_IN': '38,360', 'INEXPFTE': '8,295',
    'PCTFLOAN': '54.1', 'PCTPELL': '29.4', 'UG25ABV': '9', 'MD_EARN_WNE_P10': '57,028', 'AVGFACSAL': '7,580',
  }),
  Example('For-profit', {
    'CONTROL': '3', 'PREDDEG': '1', 'REGION': '5', 'UGDS': '582', 'TUITIONFEE_IN': '15,535', 'INEXPFTE': '3,724',
    'PCTFLOAN': '71.2', 'PCTPELL': '77.4', 'UG25ABV': '62.2', 'MD_EARN_WNE_P10': '40,843', 'AVGFACSAL': '6,090',
  }),
  // shortcut: user's own school — only tuition is known ($3,000/yr); other values borrowed from "Public university",
  // replace them with the school's real figures when available.
  Example('My school', {
    'CONTROL': '1', 'PREDDEG': '3', 'REGION': '5', 'UGDS': '10,074', 'TUITIONFEE_IN': '3,000', 'INEXPFTE': '10,232',
    'PCTFLOAN': '38.1', 'PCTPELL': '38.7', 'UG25ABV': '9.1', 'MD_EARN_WNE_P10': '56,442', 'AVGFACSAL': '10,181',
  }),
];

/// Facts about the model/data, shown in the result card and About sheet (from multivariate.ipynb).
abstract final class ModelFacts {
  static const q1 = 12000.0, median = 19487.0, q3 = 23250.0, min = 3500.0, max = 50350.0;
  static const rmse = '±\$3.5k';
  static const institutions = '2,699';
  static const model = 'Random Forest';
}
