# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trần Đức Quân  Mã học viên: 2A202602922

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Đúng cái mình gặp khi deploy CP5: lúc mới `railway add --service agent` xong, mình deploy code lên mà quên set `AGENT_API_KEY` trước. Container không lên được — log báo `ValidationError: agent_api_key Field required` và service dừng ngay ở bước khởi động, `/health` cũng không trả lời. Mình thấy lỗi ngay trên dashboard, sửa bằng cách `railway variables --set AGENT_API_KEY=...` rồi deploy lại — mất 2 phút. Nếu `agent_api_key` có default `"changeme"`, app vẫn khởi động bình thường, `/health` vẫn xanh, mọi thứ trông như thành công. Nhưng lúc đó endpoint `/ask` public trên Internet lại được bảo vệ bằng một khóa mà bất kỳ ai đọc source code trên GitHub cũng biết. Mình sẽ không phát hiện ra cho tới khi nhận hóa đơn LLM tăng bất thường hoặc bị lạm dụng — tức là phát hiện sau, bằng thiệt hại thật, thay vì phát hiện ngay lúc deploy bằng một dòng log.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")` không làm được.

> Dòng log thật lấy từ lúc mình gọi `/ask` khi test lại app:
>
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T09:55:31.066422+00:00", "user_id": "exercise-demo", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}
> ```
>
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
>
> 1. **Truy vấn và tổng hợp theo trường.** Vì mỗi dòng là một JSON object có field cố định, mình có thể chạy kiểu `jq 'select(.event=="ask_completed") | .cost_usd' logs.json | awk '{s+=$1} END {print s}'` để cộng tổng chi phí trong ngày theo từng `user_id`, hoặc lọc riêng `level: "error"`. `print` chỉ ra một chuỗi tự do — muốn biết ai tốn bao nhiêu tiền thì phải tự viết regex mò trong text, dễ vỡ khi câu chữ đổi.
> 2. **Cảnh báo tự động (alerting).** Vì có field `cost_usd` và `timestamp` tách riêng, một hệ thống như Datadog/Railway log filter có thể đặt rule "cost_usd > X trong 5 phút thì báo Slack" mà không cần hiểu tiếng Việt trong log. `print("đã trả lời xong")` không có cấu trúc nào để máy dựa vào — nó chỉ có giá trị khi có người đang nhìn màn hình terminal.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 288 MB |
| Multi-stage | 273 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Chênh lệch ~15 MB, ít hơn mình tưởng lúc đầu. Lý do: base image `python:3.11-slim` vốn đã không có compiler (gcc, make...) nên multi-stage ở đây không cắt được phần "build tool" to như ví dụ Node/Go thường thấy. Phần 15 MB bị cắt chủ yếu là: (1) layer `COPY requirements.txt .` và các file trung gian của stage `builder` không bị copy sang runtime — chỉ có `/install` (kết quả cài đặt) và `/app` được `COPY --from=builder` sang; (2) mọi thứ nằm ngoài `WORKDIR /app` ở stage builder (cache pip nội bộ trong quá trình cài, dù đã `--no-cache-dir`, `.dist-info` phụ, layer metadata của stage đầu) không tồn tại trong stage cuối. Bài học rút ra: multi-stage vẫn đáng làm cho tính an toàn/gọn gàng (image cuối không có `requirements.txt`, không có gì thừa để debug), nhưng đừng kỳ vọng nó luôn cắt được nhiều nếu base image đã "slim" sẵn — lợi ích lớn nhất của multi-stage là khi stage build cần compiler nặng (gcc, các thư viện native) mà runtime không cần.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt `COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Mình thêm một dòng comment vào `app/main.py` rồi build lại, output thật:
>
> ```
> [builder 2/5] WORKDIR /app                                    CACHED
> [builder 3/5] COPY requirements.txt .                          CACHED
> [builder 4/5] RUN pip install --no-cache-dir --prefix=/install CACHED
> [builder 5/5] COPY . .                                         (chạy lại)
> [stage-1 3/5] COPY --from=builder /install /usr/local          CACHED
> [stage-1 4/5] COPY --from=builder /app /app                    (chạy lại)
> [stage-1 5/5] RUN useradd ... && chown -R appuser:appuser /app (chạy lại)
> ```
>
> Vì `COPY requirements.txt .` đứng riêng trước `RUN pip install`, và `requirements.txt` không đổi, Docker so khớp checksum layer đó giống hệt lần trước → dùng cache cho cả bước cài dependency (bước tốn thời gian nhất, tải + cài hàng chục package). Chỉ có `COPY . .` (đổi vì `main.py` đổi) và mọi thứ *sau* nó trong Dockerfile phải chạy lại — kể cả bước cuối `RUN useradd` ở stage runtime, dù nó chẳng liên quan gì tới code, chỉ vì nó nằm sau layer đã invalidate. Đây là quy tắc: cache Docker theo layer *tuần tự*, một layer đổi thì mọi layer phía sau nó trong cùng chuỗi cũng invalidate.
>
> Nếu đổi thành đặt `COPY . .` lên trước `RUN pip install`: mỗi lần mình sửa dù chỉ một dòng trong `app/main.py` (mà không đụng gì tới `requirements.txt`), layer `COPY . .` sẽ invalidate, kéo theo `RUN pip install` phía sau nó cũng phải chạy lại — cài lại toàn bộ dependency từ đầu mỗi lần sửa code, dù dependency không hề đổi. Build sẽ chậm hẳn trong vòng lặp code → build → test.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: (1) một dependency trong `requirements.txt` (hoặc chính code `app/main.py`) có lỗ hổng cho phép remote code execution — ví dụ một thư viện parse JSON/YAML có bug deserialization. (2) Kẻ tấn công gửi payload qua `/ask` khai thác lỗ hổng đó, chạy được lệnh shell tùy ý *bên trong*
> container. (3) Nếu process Uvicorn đang chạy bằng UID 0 (root) như mặc định của image `python:3.11-slim`, lệnh shell đó cũng chạy với quyền root *bên trong* container — có thể ghi đè bất kỳ file nào trong container, cài thêm tool, hoặc dò tìm cấu hình nhạy cảm. (4) Nếu container engine có misconfiguration (chạy `--privileged`, mount `/var/run/docker.sock`, hoặc một lỗ hổng container-escape trong runtime), root bên trong container có thể leo thang thành root trên host — vì UID 0 trong container ánh xạ thẳng tới UID 0 trên host theo mặc định (không dùng user namespace remapping).
>
> `USER appuser` trong Dockerfile của mình (dòng 34) cắt đứt chuỗi này ngay ở bước (3): dù kẻ tấn công khai thác được lỗ hổng ở bước (1)-(2) và chạy được lệnh tùy ý, lệnh đó chỉ chạy với quyền của `appuser` — không ghi được vào hầu hết filesystem hệ thống (`chown -R appuser:appuser /app` chỉ cấp quyền đúng thư mục app), và quan trọng nhất: dù có container-escape, UID không phải 0 nghĩa là không tự động có quyền root trên host. `USER` không sửa được lỗ hổng gốc trong code, nhưng nó giới hạn "bán kính nổ" (blast radius) nếu lỗ hổng đó bị khai thác thật.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêurequest trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được con số đó.

> Tối đa **20 request trong 2 giây**. Cách đạt được: gửi 10 request lúc `10:00:59` — bộ đếm của phút `10:00` mới ghi nhận 10/10, vẫn hợp lệ. Ngay khi đồng hồ sang `10:01:00`, bộ đếm reset về 0 vì đây là phút mới, nên gửi tiếp 10 request nữa lúc `10:01:00`–`10:01:01` cũng hợp lệ (0/10 → 10/10 của phút mới). Kết quả: 20 request lọt qua trong khoảng 2 giây quanh mốc `59` → `00` → `01`, dù giới hạn công bố là "10/phút".

> Đây chính xác là điều `docstring` ở đầu `app/rate_limiter.py` cảnh báo, và là lý do code hiện tại của dùng dùng ZSET với `zremrangebyscore(key, 0, now - WINDOW_SECONDS)` — cửa sổ luôn trượt theo `now` thực tế của từng request, nên tại bất kỳ thời điểm nào, tổng số request trong 60 giây gần nhất trước đó không thể vượt quá 10, không có "khe hở" ở ranh giới phút.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua nhưng cost guard phải chặn, và một tình huống ngược lại.

> Khác nhau ở đơn vị đo: `RateLimiter` đếm **số lượng request** trong 60 giây gần nhất (bất kể request nặng hay nhẹ), còn `CostGuard` cộng dồn **số tiền** đã chi trong tháng (bất kể chi bằng bao nhiêu request). Một cái giới hạn tần suất, một cái giới hạn ngân sách — độc lập với nhau, xem
> `app/cost_guard.py` dòng 3-4.
>
> - **Rate limit cho qua, cost guard chặn:** user chỉ gửi 3 request trong phút này (dưới hạn mức 10/phút), nhưng mỗi câu hỏi rất dài (gần 2000 ký tự, đúng giới hạn `max_length` của `AskRequest`) khiến `tokens_in`/ `tokens_out` lớn, chi phí mỗi request cao. Tổng chi trong tháng (`spent(user_id)`) đã vượt `monthly_budget_usd` → `guard.check()` raise 402 dù rate limit chẳng có ý kiến gì.
> - **Rate limit chặn, cost guard cho qua:** user gửi câu hỏi rất ngắn ("hi", "ok"...) liên tục — 15 request/phút, mỗi request tốn gần như 0 đồng. Cost guard thấy `spent + estimated_cost` vẫn còn rất xa ngân sách 10 USD nên không chặn, nhưng `limiter.check()` đã raise 429 từ request thứ 11 vì vượt 10/phút — vấn đề ở đây không phải tiền, mà là tải lên server (spam nhỏ giọt vẫn có thể làm nghẽn tài nguyên).
>
> Trong `app/main.py` cả hai được gọi tuần tự (`limiter.check()` rồi `guard.check()`) trước khi tốn tiền gọi LLM thật — đúng thứ tự "chặn rẻ trước, chặn đắt sau".

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm 3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Giả sử endpoint gộp được dùng làm cả liveness lẫn readiness probe (cách
> dùng phổ biến khi chỉ có một endpoint). Thứ tự sự kiện:
>
> 1. **t=0s:** Redis mất kết nối. Cả 3 container vẫn đang chạy khỏe mạnh — process không hề crash, chỉ có `store.ping()` (trong `app/store.py`) bắt đầu raise exception và bị bắt lại thành `return False`.
> 2. **t=0s → lần poll kế tiếp:** cả 3 orchestrator probe (thường mỗi vài giây/chục giây) gọi endpoint gộp trên cả 3 container gần như đồng thời, vì cùng phụ thuộc một Redis. Endpoint trả 503 ở cả 3 nơi cùng lúc — khác với việc chỉ `/ready` báo lỗi, ở đây nó còn đóng vai liveness.
> 3. **Orchestrator diễn giải 503 là "process chết"**, không phải "process sống nhưng tạm thời chưa sẵn sàng". Sau vài lần probe liên tiếp thất bại (ví dụ 3 lần theo `HEALTHCHECK --retries=3` trong Dockerfile), nó bắt đầu **restart cả 3 container** — dù process Python chưa bao giờ thật sự crash.
> 4. **Cả 3 container restart gần như cùng lúc** vì lỗi bắt nguồn từ cùng một Redis dùng chung (đây chính là điều CP4 nhấn mạnh: mọi instance nhìn chung một Redis). Trong lúc restart, không còn container nào nhận  request → **toàn bộ service down hoàn toàn**, dù đáng lẽ chỉ cần rút 3 container này ra khỏi load balancer (không restart) và đợi Redis hồi.
> 5. **t=30s:** Redis kết nối lại được. Các container đã restart xong sẽ bắt đầu pass health check trở lại, service phục hồi — nhưng đã có một khoảng downtime hoàn toàn không cần thiết, cộng thêm thời gian container khởi động lại (nạp lại process, warm up) dài hơn 30 giây gốc của sự cố.
>
> Nếu tách riêng như hiện tại: `/health` (liveness) không đụng tới Redis nên vẫn 200 suốt — orchestrator không restart gì cả. Chỉ `/ready` (readiness) báo 503, load balancer tạm ngừng đẩy traffic mới vào 3 container đó nhưng **không giết chúng**, và ngay khi Redis hồi ở t=30s, `/ready` tự quay lại 200 mà không cần restart — đúng như phần "Không sập khi bạn deploy bản mới" mà README nhắc tới.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một `X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Chạy đúng lệnh `docker compose up -d --scale agent=3` như guide, mình gặp ngay một lỗi thật trước cả khi đo được gì:
>
> ```
> Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint ...-agent-2:
> Bind for 0.0.0.0:8000 failed: port is already allocated
> ```
>
> Lý do: `docker-compose.yml` map cứng `"8000:8000"` cho service `agent`. Khi scale lên 3, cả 3 container đều cố bind cùng cổng host 8000 — chỉ container đầu tiên thắng, hai container sau bị Docker từ chối khởi động networking. Đây chính là lý do `LAB_GUIDE.md` nhắc tới việc thêm `nginx` để load balance qua cổng 80: không có nó, gọi `curl localhost:8000` lặp lại thật ra luôn trúng **cùng một** container, không hề đổi instance.
>
> Để thật sự kiểm chứng nhiều container cùng nhìn một Redis, mình chạy thêm một container agent thủ công nối cùng network của compose nhưng không công bố cổng ra host (`docker run --network ..._default ... agent-image`), rồi gọi xen kẽ: 2 request qua container do compose quản lý (cổng host 8000), 1 request `docker exec` thẳng vào container thủ công (gọi nội bộ `localhost:8000` bên trong nó), rồi quay lại container đầu. Cùng một `X-User-Id`, kết quả `history_length` thật đo được: **0 → 2 → 4 → 6** — tăng liên tục xuyên suốt dù đổi container, vì cả hai cùng đọc/ghi chung một Redis (`ConversationStore` trong `app/store.py`). Nếu lịch sử nằm trong một `dict` Python trong process thay vì Redis: mỗi container có bộ nhớ riêng, không container nào thấy dict của container khác. Kết quả sẽ là **0 → 2 → 0 → 2** (hoặc bất kỳ số nhỏ nào) thay vì tăng dần — mỗi lần request rơi vào một container "lạ", agent như bị mất trí nhớ giữa chừng, dù với người dùng nhìn từ ngoài thì họ vẫn đang nói chuyện với "một agent" duy nhất qua một URL duy nhất.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lúc deploy lên Railway, mình cần xóa và tạo lại service Redis (vì lần đầu vô tình deploy nhầm code app đè lên chính service Redis — một lỗi thao tác khác). Sau khi tạo Redis service mới, `/ready` vẫn trả 503. Xem log runtime của service agent thì thấy traceback thật:
>
> ```
> File "app/store.py", line 33, in get_redis_client
>     return redis.from_url(url, decode_responses=True)
> ...
> ValueError: Redis URL must specify one of the following schemes
> (redis://, rediss://, unix://)
> ```
>
> Nguyên nhân: biến `REDIS_URL` trên service `agent` được đặt bằng cú pháp tham chiếu `${{Redis.REDIS_URL}}` — trỏ tới service Redis theo *ID* nội bộ. Khi mình xóa service Redis cũ và tạo service Redis mới (ID mới, dù tên vẫn là "Redis"), tham chiếu cũ trên service `agent` không tự cập nhật mà rã ra thành chuỗi rỗng (`railway variables --service agent` in ra `REDIS_URL` dài 0 ký tự) — tức là biến vẫn "tồn tại" nhưng vô nghĩa, nên `redis.from_url("")` parse thất bại đúng như traceback.
>
> Cách sửa: đặt lại biến bằng đúng cú pháp tham chiếu (`railway variables --service agent --set 'REDIS_URL=${{Redis.REDIS_URL}}'`) để nó trỏ tới service Redis *hiện tại*, rồi `railway redeploy --service agent` để process khởi động lại và đọc giá trị mới (biến môi trường chỉ được đọc một lần lúc `Settings()` khởi tạo, sửa xong mà không restart thì vẫn dùng giá trị cũ). Sau đó `curl <URL>/ready` trả về `{"status":"ready","redis":true}`.
> Bài học: một biến tham chiếu tới service khác không phải "vĩnh viễn đúng" — nó gãy âm thầm (thành rỗng, không phải lỗi rõ ràng) ngay khi service đích bị xóa/tạo lại, nên sau bất kỳ thao tác nào đụng tới service đó, phải kiểm tra lại `/ready` chứ không chỉ tin vào dashboard hiển thị "Online".
