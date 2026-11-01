# 보드 확인용 UART 시각 로거 (11/01) — H7 · H9 를 사람 손 대신 PC 가 정확한 간격으로 보내고, 받은 줄마다 시각을 찍음
#   준비 : ComPortMaster 를 닫는다 (포트를 같이 못 씀). 처음 한 번 : py -3.10 -m pip install --user pyserial
#   py -3.10 uart_timing.py h7  [COM7]     /auto 껐다 바로 켜고, 다시 켠 순간부터 첫 줄까지 시간
#   py -3.10 uart_timing.py h9  [COM7]     /get 20 번을 쉬지 않고 보내고 받은 줄 수
#   py -3.10 uart_timing.py log [COM7]     그냥 받은 줄마다 시각 출력 (Ctrl+C 로 끝)
import sys
import time
import serial

mode = sys.argv[1] if len(sys.argv) > 1 else 'log'
port = sys.argv[2] if len(sys.argv) > 2 else 'COM7'
ser = serial.Serial(port, 9600, timeout=0.01)
buf = b''
t0 = time.perf_counter()


def now():
    return (time.perf_counter() - t0) * 1000.0   # ms


def send(text):
    ser.write(text.encode('ascii') + b'\n')
    ser.flush()
    print(f'{now():10.1f} ms  SEND  {text}')


def read_lines(dur_s):
    """dur_s 초 동안 받은 줄을 (시각 ms, 글자) 로 돌려줌"""
    global buf
    out = []
    end = time.perf_counter() + dur_s
    while time.perf_counter() < end:
        b = ser.read(64)
        if b:
            buf += b
            while b'\n' in buf:
                line, buf = buf.split(b'\n', 1)
                s = line.replace(b'\r', b'').decode('ascii', 'replace')
                out.append((now(), s))
                print(f'{now():10.1f} ms  RECV  {s}')
    return out


ser.reset_input_buffer()
if mode == 'h7':
    send('/mod w_hm'); read_lines(0.5)
    send('/auto _sw'); read_lines(0.3)          # 켜고 0.3 초 뒤
    send('/auto off'); read_lines(0.02)
    t_on = now(); send('/auto _sw')            # 바로 다시 켬
    got = read_lines(2.5)
    send('/auto off'); read_lines(0.3)
    if got:
        print(f'\n=> 다시 켠 뒤 첫 줄까지 {got[0][0] - t_on:.0f} ms  (스펙 1000 ms, v2 는 더 짧게 나옴)')
elif mode == 'h9':
    send('/mod w_hm'); read_lines(0.5)
    t_s = now()
    ser.write(b'/get \n' * 20); ser.flush()      # 20 번을 쉬지 않고
    print(f'{t_s:10.1f} ms  SEND  /get x 20 (쉬지 않고)')
    got = read_lines(3.0)
    print(f'\n=> /get 20 번에 받은 줄 {len(got)} 줄  (스펙 20, v2 는 더 적게 나옴)')
else:
    try:
        while True:
            read_lines(1.0)
    except KeyboardInterrupt:
        pass
ser.close()
