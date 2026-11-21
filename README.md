# Luyện thi trắc nghiệm

Web luyện trắc nghiệm giao diện kiểu phần mềm thi (FPT EOS), nhiều môn — chọn bộ đề ở ô **Server**.

| Mã | Môn | Số câu |
|----|-----|--------|
| VNR202 | Lịch sử Đảng | 438 |
| PRM393 | Flutter | 158 |

## Chạy
Mở `index.html` bằng trình duyệt (double-click là được, không cần server).

## Phím tắt
- ← / → (hoặc ↑ / ↓): chuyển câu
- Space: hiện / ẩn đáp án
- A–D hoặc 1–4: chọn đáp án

## Cấu trúc
- `index.html` — giao diện + logic (HTML/CSS/JS thuần, không thư viện); danh sách môn ở mảng `SUBJECTS`
- `data/<MÃ>.js` — bộ đề từng môn, dạng `(window.BANKS = window.BANKS || {})['MÃ'] = [...]`
- `tools/parse_pdf.py` — script tách câu hỏi từ file PDF Quizlet (dùng cho VNR202)
- `tools/apkg_to_js.ps1` — chuyển bộ thẻ Anki `.apkg` thành `data/<MÃ>.js` (dùng cho PRM393)

Mỗi câu: `[id, câu hỏi, [các phương án], "đáp án (a/b/c/d, nhiều chữ nếu chọn nhiều)", "ghi chú"]`.
Tiến độ làm bài lưu riêng từng môn trong trình duyệt (localStorage `eos-<mã>-v1`).

## Thêm môn mới
1. Tạo `data/<MÃ>.js`, ví dụ từ file Anki:
   ```
   powershell -ExecutionPolicy Bypass -File tools\apkg_to_js.ps1 D:\path\to\deck.apkg MÃMÔN
   ```
   (Note Anki cần các field `Question`, `Options`, `Answer`; `Information` nếu có thì lấy phần giải thích ngắn.)
2. Thêm một dòng vào `SUBJECTS` trong `index.html`:
   `{code: 'MÃMÔN', name: 'Tên ngắn', file: 'data/MÃMÔN.js'},`

## Tạo lại bộ đề VNR202 từ PDF
```
pip install pdfplumber
python tools/parse_pdf.py VNR202.pdf      # tạo questions.json (dạng đầy đủ)
```
Sau đó chuyển sang dạng gọn: mỗi câu thành mảng `[id, q, opts, ans, note]`,
và lưu thành `data/VNR202.js` với tiền tố `(window.BANKS = window.BANKS || {})['VNR202'] = `.
