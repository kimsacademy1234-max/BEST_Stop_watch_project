# final_ppt_v2.pptx 파형 장 : 빨간 테두리 신호 이름 → 알아보기 쉬운 이름 (trig → SR04 trig, W_LINE → UART 송출 화면 …)
# 사용 : python signal_names.py final_ppt_v2.pptx [out.pptx]       (다시 돌려도 됨)
#   - 빨간 테두리 상자 (이름 '신호 이름') 를 그 줄 이름 칸 끝까지 늘려 검은 바탕 + 흰 굵은 글씨, 테두리 빨강 0.75 pt
#   - 같은 도형을 고치므로 도형 id · 애니메이션 그대로
import sys
from PIL import ImageFont
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Emu, Pt

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else SRC
IN = 914400
FONT = ImageFont.truetype("/mnt/c/Windows/Fonts/malgunbd.ttf", 100)

FRIENDLY = {
    "rx": "UART 수신", "c_state": "디코더 상태", "sw": "보드 스위치", "w_uart_mode": "UART 제어 모드",
    "w_disp_sel": "화면 선택", "FND_DATA": "FND 화면", "o_send_sel": "송신 줄 선택", "W_LINE": "UART 송출 화면",
    "trig": "SR04 trig", "echo": "SR04 echo", "w_dist_status": "SR04 오류 상태", "w_distance": "SR04 거리 값",
    "LD9": "오류 LED (LD9)", "w_state": "SR04 측정 단계", "dht11_io": "DHT11 데이터 선", "w_dht_oe": "DHT11 선 잡기",
    "w_dht_status": "DHT11 오류 상태", "W_RX": "수신 글자", "w_handshake": "명령 완료 (handshake)",
    "w_uart_btn_R": "UART 버튼 R", "w_send_go": "송신 시작", "tx": "UART 송신 (tx)",
}
# 장마다 : 이름 칸 오른쪽 끝 (in), 빨간 테두리 위→아래 순서의 신호
CFG = {
    "wave:P1-A": (1.22, ["rx", "c_state", "sw", "w_uart_mode", "w_disp_sel", "FND_DATA"]),
    "wave:P3-A": (1.42, ["o_send_sel", "W_LINE"]),
    "wave:P5-A": (1.70, ["trig", "echo", "w_dist_status", "w_distance", "FND_DATA", "LD9", "W_LINE"]),
    "wave:P5-1": (1.72, ["rx", "W_RX", "c_state", "w_handshake", "w_uart_btn_R", "trig", "echo", "w_state",
                         "w_dist_status", "FND_DATA", "LD9", "w_send_go", "o_send_sel", "tx", "W_LINE"]),
    "wave:P6-A": (1.61, ["dht11_io", "w_dht_oe", "w_dht_status", "FND_DATA", "W_LINE"]),
}

prs = Presentation(SRC)
done = []
for s in prs.slides:
    wave = next((x.name for x in s.shapes if x.name in CFG), None)
    if not wave:
        continue
    xmax, names = CFG[wave]
    boxes = sorted((x for x in s.shapes if x.name == "신호 이름"), key=lambda x: x.top)
    assert len(boxes) == len(names), (wave, len(boxes))
    for b, nm in zip(boxes, names):
        text = FRIENDLY[nm]
        cy = b.top + b.height / 2
        h = max(b.height, int(0.09 * IN))
        b.top, b.height = Emu(int(cy - h / 2)), Emu(h)
        b.width = Emu(int(xmax * IN) - b.left)
        b.fill.solid()
        b.fill.fore_color.rgb = RGBColor(0, 0, 0)
        b.line.color.rgb = RGBColor(0xFF, 0x00, 0x00)
        b.line.width = Pt(0.75)
        tf = b.text_frame
        tf.margin_left, tf.margin_right, tf.margin_top, tf.margin_bottom = 20000, 0, 0, 0
        tf.word_wrap = False
        tf.vertical_anchor = MSO_ANCHOR.MIDDLE
        p = tf.paragraphs[0]
        for extra in tf.paragraphs[1:]:
            extra._p.getparent().remove(extra._p)
        for r in list(p.runs):
            p._p.remove(r._r)
        p.alignment = PP_ALIGN.LEFT
        pt = 6.5
        while pt > 4.5 and FONT.getlength(text) / 100 * pt / 72 * IN > b.width - 40000:
            pt -= 0.25
        # 각주 표시 '*' 가 이 줄에 있으면 글자 바로 뒤로
        for star in s.shapes:
            if star.has_text_frame and star.text_frame.text.strip() == "*" and abs(star.top + star.height / 2 - cy) < 0.06 * IN:
                star.left = Emu(int(min(b.left + 20000 + FONT.getlength(text) / 100 * pt / 72 * IN * 1.12 + 10000,
                                        b.left + b.width - star.width)))
        r = p.add_run()
        r.text = text
        r.font.size, r.font.bold, r.font.name = Pt(pt), True, "Malgun Gothic"
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        rpr = r._r.get_or_add_rPr()
        if rpr.find(qn("a:ea")) is None:
            rpr.append(rpr.makeelement(qn("a:ea"), {"typeface": "Malgun Gothic"}))
    done.append(wave)

prs.save(OUT)
print("저장", OUT, done)
