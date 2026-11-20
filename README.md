# Luyện thi trắc nghiệm VNR202

Web luyện trắc nghiệm giao diện kiểu phần mềm thi, 438 câu VNR202.

## Chạy
Mở `index.html` bằng trình duyệt (double-click là được, không cần server).

## Phím tắt
- ← / → (hoặc ↑ / ↓): chuyển câu
- Space: hiện / ẩn đáp án
- A–D hoặc 1–4: chọn đáp án

## Cấu trúc
- `index.html` — giao diện + logic (HTML/CSS/JS thuần, không thư viện)
- `questions.js` — bộ đề nhúng sẵn (`window.QUESTIONS`), dùng khi mở bằng file://
- `questions.json` — bộ đề dạng JSON (dự phòng, dùng khi chạy qua web server)
- `tools/parse_pdf.py` — script tách câu hỏi từ file PDF Quizlet

Mỗi câu: `[id, câu hỏi, [các phương án], "đáp án (a/b/c/d, nhiều chữ nếu chọn nhiều)", "ghi chú"]`

## Tạo lại bộ đề từ PDF
```
pip install pdfplumber
python tools/parse_pdf.py VNR202.pdf      # tạo questions.json (dạng đầy đủ)
```
Sau đó chuyển sang dạng gọn: mỗi câu thành mảng `[id, q, opts, ans, note]`,
và tạo `questions.js` bằng cách thêm `window.QUESTIONS = ` vào đầu file JSON gọn.
