enum ReportType {
  itc,
  mm2b,
  gstr1,
  gstr3b,
  gstr9;

  String get title {
    switch (this) {
      case ReportType.itc:
        return 'ITC Report';
      case ReportType.mm2b:
        return 'Multi month 2B report';
      case ReportType.gstr1:
        return 'GSTR-1';
      case ReportType.gstr3b:
        return 'GSTR-3B';
      case ReportType.gstr9:
        return 'GSTR-9';
    }
  }

  String get description {
    switch (this) {
      case ReportType.itc:
        return 'Input Tax Credit';
      case ReportType.mm2b:
        return 'Multi-Month 2B Data';
      case ReportType.gstr1:
        return 'Outward Supplies';
      case ReportType.gstr3b:
        return 'Summary Return';
      case ReportType.gstr9:
        return 'Annual Return';
    }
  }

  bool get isAvailable {
    final now = DateTime.now();
    switch (this) {
      case ReportType.itc:
        return true; // Always available
      case ReportType.mm2b:
        return now.day >= 14;
      case ReportType.gstr1:
        return now.day >= 13;
      case ReportType.gstr3b:
        return now.day >= 15;
      case ReportType.gstr9:
        return now.day >= 15;
    }
  }
}
