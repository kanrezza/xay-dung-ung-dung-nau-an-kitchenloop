# Feature Specification: Công thức có cấu trúc và chế độ nấu từng bước

**Feature Branch**: `001-structured-recipe-cooking-mode` (chưa dùng git; tên thư mục spec)

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description: "Giai đoạn 1 của KitchenLoop: công thức nấu ăn có cấu trúc (nguyên liệu có tên, số lượng, đơn vị, giá, kcal; các bước nấu tách riêng) và chế độ nấu từng bước (chữ to, vuốt qua lại, giữ màn hình sáng, hẹn giờ), đổi khẩu phần, gắn thẻ, tìm/lọc công thức của mình, chuyển dữ liệu công thức cũ, dùng được khi mất mạng, tiếng Việt trước. Không có mạng xã hội."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Tạo và xem công thức có cấu trúc (Priority: P1)

Người dùng đã đăng nhập tạo một công thức gồm tên món, ảnh (tuỳ chọn), số người ăn, danh sách nguyên liệu (mỗi nguyên liệu có tên, số lượng, đơn vị, và tuỳ chọn giá, kcal) và danh sách các bước nấu theo thứ tự. Người dùng xem lại công thức đó với nguyên liệu và các bước hiển thị rõ ràng, tách riêng nhau.

**Why this priority**: Đây là dữ liệu nền của toàn bộ ứng dụng; mọi tính năng ở các giai đoạn sau (thực đơn, đi chợ, tủ lạnh, thống kê) đều dùng lại nguyên liệu có cấu trúc. Chỉ riêng story này đã là một sổ công thức dùng được.

**Independent Test**: Tạo một công thức mới với 3 nguyên liệu và 3 bước, lưu lại, đóng và mở lại ứng dụng, xác nhận công thức hiển thị đầy đủ, đúng thứ tự.

**Acceptance Scenarios**:

1. **Given** người dùng đã đăng nhập, **When** họ nhập tên món, ít nhất một nguyên liệu và ít nhất một bước rồi lưu, **Then** công thức xuất hiện trong danh sách công thức của họ.
2. **Given** một công thức đã lưu, **When** người dùng mở nó, **Then** nguyên liệu hiển thị với số lượng và đơn vị, các bước hiển thị theo đúng thứ tự đã nhập.
3. **Given** người dùng đang tạo công thức, **When** họ để trống tên món hoặc không có nguyên liệu nào, **Then** hệ thống không cho lưu và báo rõ trường còn thiếu.
4. **Given** một công thức đã lưu, **When** người dùng sửa nguyên liệu, thêm/xoá/đổi thứ tự bước rồi lưu, **Then** các thay đổi được giữ nguyên khi mở lại.
5. **Given** một công thức đã lưu, **When** người dùng xoá nó và xác nhận, **Then** công thức biến mất khỏi danh sách.

---

### User Story 2 - Chế độ nấu từng bước (Priority: P1)

Khi bắt đầu nấu, người dùng vào chế độ nấu: mỗi lần chỉ hiện một bước bằng chữ lớn, dễ đọc từ xa. Người dùng vuốt hoặc bấm để chuyển bước tiếp theo hoặc quay lại. Màn hình không tự tắt trong suốt quá trình nấu. Với bước có thời gian, người dùng bật đồng hồ đếm ngược và được báo khi hết giờ.

**Why this priority**: Đây là điểm khác biệt chính của ứng dụng so với một sổ ghi công thức thông thường, và là lý do người dùng mở app khi đang đứng bếp.

**Independent Test**: Mở một công thức có 4 bước (trong đó 1 bước có thời gian 2 phút), vào chế độ nấu, đi qua cả 4 bước tới lui, bật hẹn giờ ở bước có thời gian và xác nhận có báo khi hết giờ; để yên máy 5 phút và xác nhận màn hình không tắt.

**Acceptance Scenarios**:

1. **Given** một công thức có nhiều bước, **When** người dùng bắt đầu chế độ nấu, **Then** bước đầu tiên hiện bằng chữ lớn cùng chỉ báo "bước X trên Y".
2. **Given** người dùng đang ở một bước giữa, **When** họ vuốt hoặc bấm tiếp/lùi, **Then** hệ thống chuyển đúng sang bước kế/trước; ở bước cuối có lựa chọn hoàn thành, ở bước đầu không thể lùi thêm.
3. **Given** một bước có thời gian, **When** người dùng bật hẹn giờ, **Then** đồng hồ đếm ngược hiển thị rõ và khi về 0 người dùng được báo bằng âm thanh hoặc rung cùng thông báo trên màn hình, kể cả khi đã chuyển sang bước khác.
4. **Given** người dùng đang ở chế độ nấu, **When** không chạm vào máy trong thời gian dài, **Then** màn hình vẫn sáng cho tới khi họ thoát chế độ nấu.
5. **Given** người dùng đang nấu và vô tình thoát, **When** họ mở lại chế độ nấu của cùng công thức, **Then** họ được hỏi có tiếp tục từ bước đang dở hay bắt đầu lại.

---

### User Story 3 - Đổi khẩu phần (Priority: P2)

Người dùng thay đổi số người ăn của một công thức; số lượng của mọi nguyên liệu được nhân hoặc chia theo tỉ lệ tương ứng và hiển thị ngay, cả ở màn hình xem công thức lẫn trong chế độ nấu.

**Why this priority**: Giúp dùng một công thức cho nhiều hoàn cảnh (nấu cho 1 người hay cả nhà) và là nền tảng cho việc gộp danh sách đi chợ ở giai đoạn sau.

**Independent Test**: Công thức gốc cho 2 người có 200 g thịt; đổi thành 5 người, xác nhận hiển thị 500 g; đổi về 1 người, xác nhận hiển thị 100 g.

**Acceptance Scenarios**:

1. **Given** công thức gốc cho 2 người, **When** người dùng đổi sang 4 người, **Then** mọi số lượng nguyên liệu tăng gấp đôi.
2. **Given** kết quả quy đổi không tròn, **When** hiển thị, **Then** số lượng được làm tròn dễ đọc (tối đa 2 chữ số thập phân, bỏ phần thập phân thừa).
3. **Given** người dùng đã đổi khẩu phần để xem, **When** họ không bấm lưu, **Then** công thức gốc không bị thay đổi.
4. **Given** số người ăn nhập vào bằng 0 hoặc âm, **When** người dùng xác nhận, **Then** hệ thống từ chối và giữ giá trị cũ.

---

### User Story 4 - Gắn thẻ, tìm và lọc công thức của mình (Priority: P2)

Người dùng gắn một hoặc nhiều thẻ cho công thức (ví dụ "món sinh viên", "nhanh", "ăn kiêng"). Trong danh sách, họ tìm theo tên món hoặc tên nguyên liệu (không phân biệt hoa thường và dấu tiếng Việt) và lọc theo thẻ.

**Why this priority**: Khi số công thức tăng lên, không tìm lại được thì sổ công thức mất giá trị; nhưng app vẫn dùng được nếu thiếu tính năng này.

**Independent Test**: Có 10 công thức, 3 cái gắn thẻ "món sinh viên"; lọc theo thẻ này chỉ còn đúng 3 cái; tìm "ga" (không dấu) ra các món chứa "gà".

**Acceptance Scenarios**:

1. **Given** nhiều công thức, **When** người dùng chọn một thẻ, **Then** danh sách chỉ còn công thức có thẻ đó.
2. **Given** người dùng gõ từ khoá không dấu, **When** tìm kiếm, **Then** kết quả gồm cả công thức có tên hoặc nguyên liệu khớp khi có dấu.
3. **Given** không có công thức nào khớp, **When** tìm kiếm, **Then** hệ thống hiển thị thông báo trống thân thiện kèm gợi ý xoá bộ lọc.
4. **Given** người dùng chọn đồng thời từ khoá và thẻ, **When** xem kết quả, **Then** chỉ hiện công thức thoả cả hai điều kiện.

---

### User Story 5 - Chuyển dữ liệu công thức cũ (Priority: P2)

Người dùng đã có công thức từ phiên bản cũ của ứng dụng (nguyên liệu là các dòng chữ tự do, hướng dẫn là một đoạn dài). Khi mở ứng dụng mới, các công thức này được chuyển sang dạng có cấu trúc mà không mất thông tin nào.

**Why this priority**: Bảo toàn dữ liệu người dùng là bắt buộc, nhưng chỉ ảnh hưởng người đã có dữ liệu cũ.

**Independent Test**: Với một công thức cũ có nguyên liệu "200g thịt bò", "2 quả trứng", "muối" và hướng dẫn nhiều đoạn, chạy chuyển đổi và xác nhận: nguyên liệu tách đúng số lượng/đơn vị/tên khi nhận diện được; dòng không nhận diện được vẫn được giữ nguyên văn; hướng dẫn được tách thành các bước; không công thức nào bị mất.

**Acceptance Scenarios**:

1. **Given** nguyên liệu cũ dạng "số + đơn vị + tên", **When** chuyển đổi, **Then** được tách thành số lượng, đơn vị và tên tương ứng.
2. **Given** dòng nguyên liệu không tách được (ví dụ "muối, tuỳ khẩu vị"), **When** chuyển đổi, **Then** giữ nguyên văn làm tên nguyên liệu, số lượng để trống, và không bị bỏ.
3. **Given** hướng dẫn cũ là một đoạn dài nhiều dòng, **When** chuyển đổi, **Then** mỗi dòng hoặc đoạn có đánh số trở thành một bước theo thứ tự.
4. **Given** quá trình chuyển đổi bị gián đoạn giữa chừng, **When** chạy lại, **Then** không tạo bản sao trùng và không làm hỏng công thức đã chuyển.
5. **Given** chuyển đổi hoàn tất, **When** người dùng cần đối chiếu, **Then** nội dung gốc ban đầu vẫn còn và xem lại được ngay trong màn hình chi tiết công thức.
6. **Given** một công thức cũ không có nguyên liệu, không có hướng dẫn, hoặc có tên rỗng/quá dài, **When** chuyển đổi, **Then** công thức vẫn được chuyển (dùng dòng/bước giữ chỗ hoặc cắt tên cho hợp lệ), không bị bỏ qua, và nội dung gốc đầy đủ vẫn được giữ lại.

---

### User Story 6 - Dùng khi mất mạng (Priority: P3)

Người dùng đang đứng bếp mà mất mạng vẫn xem được các công thức đã từng tải về và dùng chế độ nấu đầy đủ (chuyển bước, hẹn giờ, đổi khẩu phần).

**Why this priority**: Rất quan trọng với trải nghiệm trong bếp nhưng là yêu cầu bổ trợ cho các story trên.

**Independent Test**: Mở danh sách công thức khi có mạng, tắt mạng, mở một công thức và chạy chế độ nấu đến hết; xác nhận không có lỗi chặn người dùng.

**Acceptance Scenarios**:

1. **Given** công thức đã từng được xem khi có mạng, **When** thiết bị mất mạng, **Then** công thức vẫn mở và chế độ nấu hoạt động bình thường.
2. **Given** người dùng sửa công thức khi mất mạng, **When** mạng trở lại, **Then** thay đổi được đồng bộ mà không mất dữ liệu.
3. **Given** mất mạng, **When** người dùng cố tải ảnh lên, **Then** hệ thống báo cần có mạng cho thao tác này và không làm mất các phần còn lại của công thức đang nhập.

---

### Edge Cases

- Công thức có rất nhiều nguyên liệu hoặc bước (ví dụ 50 mục): danh sách vẫn cuộn mượt và thao tác thêm/xoá/đổi thứ tự vẫn dùng được.
- Số lượng nguyên liệu là phân số hoặc số thập phân ("1/2", "0,5"): được nhận cả dấu phẩy và dấu chấm thập phân.
- Nguyên liệu không có số lượng ("muối vừa đủ"): được phép để trống số lượng và không bị nhân khi đổi khẩu phần.
- Giá hoặc kcal để trống: công thức vẫn lưu được; các giá trị này tuỳ chọn.
- Bước có thời gian bằng 0 hoặc âm: bị từ chối khi lưu.
- Đang hẹn giờ thì thoát chế độ nấu, hoặc ứng dụng chạy nền: bộ đếm vẫn báo đúng lúc hết giờ khi người dùng quay lại.
- Hai thiết bị cùng sửa một công thức: giữ lại bản được lưu sau cùng và không làm hỏng dữ liệu.
- Tìm kiếm với ký tự đặc biệt hoặc chuỗi rỗng: không gây lỗi, chuỗi rỗng hiện toàn bộ danh sách.
- Người dùng đăng xuất: dữ liệu công thức của người dùng đó không còn hiển thị trên máy cho người dùng khác, và các hẹn giờ đang chạy của họ bị huỷ.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST cho phép người dùng đã đăng nhập tạo, xem, sửa và xoá công thức của chính mình.
- **FR-002**: Mỗi công thức MUST có tên món, số người ăn gốc, ít nhất một nguyên liệu và ít nhất một bước nấu; ảnh, thẻ, ghi chú là tuỳ chọn.
- **FR-003**: Mỗi nguyên liệu MUST gồm tên; số lượng, đơn vị, giá và kcal là tuỳ chọn; số lượng nếu có MUST là số không âm.
- **FR-004**: Mỗi bước nấu MUST có nội dung; ảnh và thời gian (tính bằng phút/giây) là tuỳ chọn; thời gian nếu có MUST lớn hơn 0.
- **FR-005**: Người dùng MUST có thể thêm, xoá và đổi thứ tự nguyên liệu cũng như các bước.
- **FR-006**: Hệ thống MUST cho phép đổi số người ăn khi xem và tự quy đổi số lượng nguyên liệu theo tỉ lệ, không làm thay đổi công thức gốc nếu người dùng không lưu.
- **FR-007**: Nguyên liệu không có số lượng MUST không bị thay đổi khi quy đổi khẩu phần.
- **FR-008**: Hệ thống MUST cung cấp chế độ nấu hiển thị một bước mỗi lần bằng chữ lớn kèm vị trí bước hiện tại và tổng số bước.
- **FR-009**: Trong chế độ nấu, người dùng MUST có thể chuyển bước tiếp theo và quay lại bằng thao tác vuốt hoặc nút bấm.
- **FR-010**: Hệ thống MUST giữ màn hình luôn sáng trong suốt thời gian ở chế độ nấu và trả lại hành vi bình thường khi thoát.
- **FR-011**: Với bước có thời gian, hệ thống MUST cho phép bật, tạm dừng và đặt lại hẹn giờ đếm ngược, và MUST báo khi hết giờ bằng âm thanh hoặc rung kèm thông báo hiển thị.
- **FR-012**: Hệ thống MUST cho phép xem lại danh sách nguyên liệu đã quy đổi ngay trong chế độ nấu.
- **FR-013**: Người dùng MUST có thể gắn nhiều thẻ cho công thức và lọc danh sách theo thẻ.
- **FR-014**: Hệ thống MUST hỗ trợ tìm theo tên món và tên nguyên liệu, không phân biệt hoa thường và dấu tiếng Việt, và cho phép kết hợp với bộ lọc thẻ.
- **FR-015**: Mỗi người dùng MUST chỉ thấy và chỉnh sửa được công thức của chính mình; không công thức nào hiển thị cho người khác.
- **FR-016**: Hệ thống MUST NOT có chức năng theo dõi người dùng khác, bình luận, đánh giá của người khác hoặc cộng đồng chia sẻ công thức.
- **FR-017**: Hệ thống MUST chuyển các công thức dạng cũ sang dạng có cấu trúc mà không làm mất nội dung; dòng nguyên liệu không phân tích được MUST được giữ nguyên văn.
- **FR-018**: Việc chuyển đổi dữ liệu MUST có thể chạy lại an toàn (không tạo bản sao, không làm hỏng dữ liệu đã chuyển) và MUST giữ lại nội dung gốc để đối chiếu, đồng thời cho người dùng xem lại nội dung gốc đó trong màn hình chi tiết công thức.
- **FR-019**: Công thức đã từng được xem khi có mạng MUST xem được và dùng được chế độ nấu khi không có mạng; chỉnh sửa khi mất mạng MUST được đồng bộ khi có mạng trở lại.
- **FR-020**: Mọi văn bản hiển thị cho người dùng MUST có tiếng Việt và tiếng Anh, tiếng Việt là mặc định.
- **FR-021**: Hệ thống MUST báo lỗi rõ ràng, thân thiện khi lưu thất bại hoặc dữ liệu nhập không hợp lệ và không làm mất dữ liệu người dùng đang nhập.
- **FR-022**: Việc chuyển đổi MUST vẫn chuyển được công thức cũ thiếu nguyên liệu, thiếu hướng dẫn hoặc có tên rỗng/quá dài (dùng dòng/bước giữ chỗ hoặc cắt tên), và MUST NOT bỏ qua hay làm mất công thức nào.
- **FR-023**: Hệ thống MUST có màn hình tài khoản tối thiểu cho phép xem email đang đăng nhập, đổi ngôn ngữ giao diện giữa tiếng Việt và tiếng Anh, và đăng xuất; khi đăng xuất, mọi hẹn giờ đang chạy của tài khoản đó MUST bị huỷ và công thức của tài khoản đó MUST NOT hiển thị cho tài khoản đăng nhập tiếp theo.

### Key Entities

- **Công thức**: một món ăn của một người dùng. Gồm tên, ảnh, số người ăn gốc, thẻ, ghi chú, thời điểm tạo/sửa, và chủ sở hữu. Có nhiều nguyên liệu và nhiều bước.
- **Nguyên liệu**: một dòng nguyên liệu thuộc một công thức. Gồm tên, số lượng, đơn vị, giá, kcal (số lượng, giá, kcal tuỳ chọn). Là mô hình dùng chung cho các giai đoạn sau.
- **Bước nấu**: một bước theo thứ tự trong công thức. Gồm số thứ tự, nội dung, ảnh tuỳ chọn, thời gian tuỳ chọn.
- **Thẻ**: nhãn do người dùng đặt để phân loại công thức; một công thức có nhiều thẻ.
- **Phiên nấu**: trạng thái nấu đang dở của một công thức (bước hiện tại, số người ăn đang chọn, các hẹn giờ đang chạy), dùng để tiếp tục khi quay lại.
- **Công thức dạng cũ**: bản ghi từ phiên bản trước, nguyên liệu là chuỗi tự do và hướng dẫn là một đoạn văn; là nguồn của việc chuyển đổi dữ liệu.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng mới tạo xong một công thức 5 nguyên liệu và 5 bước trong dưới 3 phút ở lần dùng đầu tiên.
- **SC-002**: Từ danh sách công thức, người dùng vào được bước nấu đầu tiên trong tối đa 2 lần chạm.
- **SC-003**: Khi đổi số người ăn, số lượng nguyên liệu cập nhật tức thì (người dùng không nhận thấy độ trễ) và chính xác 100% trong các phép tính kiểm thử.
- **SC-004**: Trong 30 phút ở chế độ nấu, màn hình không tự tắt trong 100% lần thử.
- **SC-005**: Hẹn giờ báo hết giờ sai lệch không quá 2 giây so với thời gian đã đặt trong mọi lần thử, kể cả khi ứng dụng chạy nền.
- **SC-006**: Tìm kiếm trả kết quả hiển thị trong dưới 1 giây với ít nhất 200 công thức.
- **SC-007**: 100% công thức dạng cũ được chuyển đổi mà không mất nội dung; tối thiểu 90% dòng nguyên liệu dạng "số + đơn vị + tên" được tách đúng cấu trúc, phần còn lại được giữ nguyên văn.
- **SC-008**: Công thức đã xem trước đó mở được và chạy chế độ nấu đến hết khi không có mạng trong 100% lần thử.
- **SC-009**: Không có người dùng nào xem hoặc sửa được công thức của người dùng khác trong mọi kiểm thử quyền truy cập.

## Assumptions

- Người dùng sử dụng ứng dụng trên điện thoại (Android/iOS) và đăng nhập bằng cơ chế tài khoản hiện có của ứng dụng; không làm lại luồng đăng ký/đăng nhập ở giai đoạn này.
- Công thức là riêng tư theo từng người dùng. Việc chia sẻ công thức cho người khác nằm ngoài phạm vi giai đoạn 1.
- Danh sách đơn vị là một tập có sẵn thông dụng (g, kg, ml, l, quả, củ, muỗng, thìa, bát, chén, nhúm, tép, ...) và người dùng vẫn nhập được đơn vị tự do khi không có trong danh sách.
- Giá và kcal của nguyên liệu chỉ được lưu để dùng cho các giai đoạn sau; giai đoạn 1 không tổng hợp hay hiển thị thống kê dựa trên chúng.
- Ảnh công thức và ảnh bước nấu cần có mạng để tải lên; việc xem ảnh đã tải trước đó có thể dùng bản đã lưu tạm.
- Thông báo hết giờ cần người dùng cho phép thông báo trên thiết bị; nếu bị từ chối, ứng dụng vẫn báo bằng âm thanh/rung và hiển thị trong ứng dụng khi đang mở.
- Dữ liệu công thức cũ được chuyển đổi một lần cho mỗi người dùng khi họ mở bản mới; nội dung gốc được giữ lại.
- Các công thức do quản trị viên tạo trong phiên bản cũ (món "nổi bật"/khám phá) nằm ngoài phạm vi giai đoạn 1; chỉ các món có tác giả là chính người dùng đang đăng nhập được chuyển.
- Vai trò quản trị viên và các màn hình quản trị cũ (quản lý người dùng, quản lý món ăn, thống kê) không còn trong giai đoạn 1; mọi tài khoản đều vào thẳng danh sách công thức của chính mình.
- Màn hình tài khoản ở giai đoạn 1 chỉ gồm email, đổi ngôn ngữ và đăng xuất; đổi mật khẩu, sửa hồ sơ và ảnh đại diện của phiên bản cũ nằm ngoài phạm vi (có thể bổ sung sau).
- Ngoài phạm vi giai đoạn 1: thực đơn tuần, danh sách đi chợ, tủ lạnh và gợi ý món, thống kê calo/chi tiêu, chia sẻ công thức, mạng xã hội (theo dõi, bình luận, đánh giá, cộng đồng), nhập công thức từ liên kết web.
