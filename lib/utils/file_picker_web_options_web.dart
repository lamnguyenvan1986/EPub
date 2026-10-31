import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

/// Safari iOS trả focus về trang trước khi file chọn từ ứng dụng Tệp được sao
/// chép xong, nên file_picker coi đó là huỷ và trả về null. Chỉ coi là huỷ khi
/// trình duyệt báo sự kiện `cancel`.
WebOptions filePickerWebOptions() =>
    const FilePickerWebOptions(cancelUploadOnWindowBlur: false);
