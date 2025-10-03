import 'package:flutter_test/flutter_test.dart';
import 'package:pastor_report/utils/extract_excel_data.dart';

void main() {
  test('Extract staff data from Excel', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await extractStaffData();
  });
}
