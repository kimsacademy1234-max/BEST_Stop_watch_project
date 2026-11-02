# sender 버그 주입 사본 만들기 : C:/work/merge_fix2/src (= 팀 FINAL v2) 를 S1 ~ S8 폴더에 복사하고 한 곳씩 바꿈
import shutil, os
SRC = r'C:/work/merge_fix2/src'
OUT = r'C:/work/sender_bug'
SND = 'UART/uart_sender.v'
MUX = 'UART/sender_char_mux.v'
BUGS = {
    'S1': (SND, 'busy 중 send_go 를 받음 (SEND 에서도 새 값 잡기)', [
        ("            SEND: begin\n                if (~i_tx_full) begin",
         "            SEND: begin\n                if (i_send_go) begin n_sel = i_send_sel; n_data = i_send_data; end   // BUG S1\n                if (~i_tx_full) begin")]),
    'S2': (SND, 'TX FIFO full 을 무시하고 push', [
        ("assign o_tx_push   = (c_state == SEND) && (i_tx_full == 0);", "assign o_tx_push   = (c_state == SEND);   // BUG S2"),
        ("                if (~i_tx_full) begin", "                if (1'b1) begin   // BUG S2")]),
    'S3': (SND, 'go 순간 값을 안 잡고 바깥 값을 바로 글자 MUX 로', [
        ("        .i_sel(c_sel),\n        .i_data(c_data),", "        .i_sel(i_send_sel),\n        .i_data(i_send_data),   // BUG S3")]),
    'S4': (SND, '마지막 글자 (LF) 하나 덜 보냄', [
        ("if (c_idx == w_last_idx) begin", "if (c_idx == w_last_idx - 1) begin   // BUG S4")]),
    'S5': (SND, '새 줄 시작 때 글자 번호를 0 으로 안 돌림', [
        ("                    n_idx   = 0;\n", "")]),
    'S6': (MUX, '거리 백의 자리 계산 오류 (÷100 → ÷10 %10)', [
        ("o_char = 8'h30 + w_cm / 100;", "o_char = 8'h30 + (w_cm / 10) % 10;   // BUG S6")]),
    'S7': (MUX, 'v2 거리 상태 무시 (Err 대신 숫자)', [
        ("if (w_dst != 2'b00)", "if (1'b0)")]),
    'S8': (MUX, 'v2 온습도 측정 전 무시 (--%--C 대신 숫자)', [
        ("if (w_hdash)", "if (1'b0)")]),
}
for k, (f, desc, reps) in BUGS.items():
    d = os.path.join(OUT, k, 'src')
    if os.path.exists(d):
        shutil.rmtree(d)
    shutil.copytree(SRC, d)
    p = os.path.join(d, f)
    s = open(p, encoding='utf-8').read()
    for a, b in reps:
        n = s.count(a)
        assert n >= 1, (k, a[:40])
        s = s.replace(a, b)
    open(p, 'w', encoding='utf-8').write(s)
    open(os.path.join(OUT, k, 'BUG.txt'), 'w', encoding='utf-8').write(f'{k} : {desc}\n파일 : {f}\n')
    print(k, f, desc)
