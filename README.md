# DevicePersona

DevicePersona là tweak Theos/Logos thử nghiệm dành cho **iOS 15 rootful**. Tweak cho phép ứng dụng bên thứ ba được chọn nhìn thấy một profile thiết bị tùy chỉnh mà không sửa thông tin phần cứng thật của iPhone.

## Cài bằng Sileo

Sau khi GitHub Pages được bật cho repository này, thêm nguồn sau vào Sileo:

```text
https://minhanhqc3-commits.github.io/devicepersona-repo/
```

Hoặc mở liên kết nhanh:

```text
sileo://source/https://minhanhqc3-commits.github.io/devicepersona-repo/
```

Tìm **DevicePersona**, cài hoặc nâng cấp lên bản **0.2.0**, rồi mở ứng dụng **DevicePersona** ngay trên Màn hình chính để cấu hình. Gói vẫn giữ mục **Settings → DevicePersona** làm phương án dự phòng, nhưng ứng dụng ngoài Màn hình chính không phụ thuộc PreferenceLoader.

Gói phụ thuộc **Cephei Tweak Support 1.17.1** dành cho rootful. Nếu Sileo chưa tìm thấy dependency `ws.hbang.common`, hãy thêm nguồn Chariz `https://repo.chariz.com/`, refresh Sources rồi cài lại.

## Phạm vi

- `UIDevice`: tên máy, model hiển thị, tên/phiên bản hệ điều hành và IDFV.
- `NSLocale` / `NSTimeZone`: locale, danh sách ngôn ngữ và múi giờ.
- `CTCarrier`: tên nhà mạng, MCC, MNC và mã quốc gia.
- Tùy chọn nâng cao: `uname.machine`, `sysctlbyname("hw.machine")` và `hw.model`.
- Chỉ kích hoạt với bundle ID được nhập trong Settings; mặc định tắt và chỉ chấp nhận app bên thứ ba nằm trong app container.

Không hỗ trợ giả Serial, IMEI/MEID, UDID, ECID, IMSI/ICCID, địa chỉ MAC, APNs token, DeviceCheck/App Attest hoặc định danh do máy chủ tạo. Tweak không xóa app container, keychain hay dữ liệu người dùng.

## Build thủ công

Yêu cầu Theos cùng iOS SDK trên macOS, Linux hoặc WSL:

```sh
export THEOS=/duong-dan/toi/theos
make clean package FINALPACKAGE=1
```

Đây là gói **rootful**, do đó không đặt `THEOS_PACKAGE_SCHEME=rootless`. File `.deb` được tạo trong `packages/`.

## Phát hành qua GitHub Pages

Workflow `.github/workflows/build-and-deploy.yml` thực hiện toàn bộ quy trình khi có commit trên nhánh `main`:

1. Cài Theos bằng installer chính thức.
2. Build package arm64 rootful.
3. Chạy `scripts/build-repo.sh` để tạo `Packages`, các bản nén và `Release` trong `site/`.
4. Deploy thư mục `site/` bằng GitHub Pages Actions.

Trong **Settings → Pages → Build and deployment**, chọn **GitHub Actions** làm source. Có thể chạy lại workflow thủ công từ tab **Actions**.

Khi phát hành bản mới, tăng `Version` trong `control` và tăng `CFBundleShortVersionString` / `CFBundleVersion` trong cả `prefs/Resources/Info.plist` lẫn `app/Resources/Info.plist` trước khi push.

## Cấu hình và khôi phục

Nhập bundle ID chính xác của app mục tiêu; nhiều ID cách nhau bằng dấu phẩy. Profile được nạp khi process khởi động, vì vậy cần đóng hẳn app khỏi App Switcher rồi mở lại.

Ứng dụng cấu hình được cài tại `/Applications/DevicePersona.app`. Gói chạy `uicache` sau khi nâng cấp để biểu tượng xuất hiện. Nếu biểu tượng chưa hiện ngay, hãy respring một lần; không cần gỡ bản cũ trước khi nâng cấp.

Nếu app crash, giữ Volume Up khi mở app nếu tweak loader hỗ trợ chế độ vô hiệu hóa, hoặc gỡ package trong Safe Mode. Nên thử từng nhóm trường; để trống trường nào sẽ giữ nguyên giá trị thật của trường đó.

`DevicePersona.plist` làm dylib được nạp vào process dùng UIKit. Hàm khởi tạo thoát ngay nếu process không thuộc app container bên thứ ba, rồi chỉ bật hook khi bundle ID nằm trong allowlist.

Tweak dùng `HBPreferences` của Cephei để đọc profile từ app sandbox. Phiên bản Cephei 1.x là nhánh dành cho jailbreak rootful; không cài nhầm Cephei 2.x rootless.
