"""Generate Vivado .wcfg for tb/03_watch PPT scenario TBs (tb_wt_s1..s5).  usage: python3 gen_scenario_wcfg.py ../tb/03_watch s1 s2 s3 s4 s5"""
import sys
from xml.sax.saxutils import escape

YEL, MAG, CYN = "#FFD700", "#FF00FF", "#00FFFF"


def sig(path, short, typ="logic", label=None, color=None, radix=None):
    return dict(path=path, short=short, typ=typ, label=label, color=color, radix=radix)


def obj_xml(top, s, ind):
    p = " " * ind
    out = [f'{p}<wvobject fp_name="/{top}/{s["path"]}" type="{s["typ"]}">']
    if s["label"]:
        out.append(f'{p}   <obj_property name="DisplayName">label</obj_property>')
    out.append(f'{p}   <obj_property name="ElementShortName">{s["short"]}</obj_property>')
    out.append(f'{p}   <obj_property name="ObjectShortName">{s["short"]}</obj_property>')
    if s["label"]:
        out.append(f'{p}   <obj_property name="label">{escape(s["label"])}</obj_property>')
    if s["radix"]:
        out.append(f'{p}   <obj_property name="Radix">{s["radix"]}</obj_property>')
    if s["color"]:
        out.append(f'{p}   <obj_property name="CustomSignalColor">{s["color"]}</obj_property>')
        out.append(f'{p}   <obj_property name="UseCustomSignalColor">true</obj_property>')
    out.append(f"{p}</wvobject>")
    return out


def wcfg(top, end_ps, markers, items):
    """items: list of signal dicts or ("group label", [signals])."""
    L = ['<?xml version="1.0" encoding="UTF-8"?>', "<wave_config>", "   <wave_state>", "   </wave_state>",
         "   <db_ref_list>", f'      <db_ref path="{top}_behav.wdb" id="1">', "         <top_modules>",
         '            <top_module name="glbl" />', f'            <top_module name="{top}" />',
         "         </top_modules>", "      </db_ref>", "   </db_ref_list>", "   <zoom_setting>",
         '      <ZoomStartTime time="0fs"></ZoomStartTime>',
         f'      <ZoomEndTime time="{end_ps * 1000}fs"></ZoomEndTime>',
         '      <Cursor1Time time="0fs"></Cursor1Time>', "   </zoom_setting>", "   <column_width_setting>",
         '      <NameColumnWidth column_width="204"></NameColumnWidth>',
         '      <ValueColumnWidth column_width="90"></ValueColumnWidth>', "   </column_width_setting>",
         f'   <WVObjectSize size="{len(items)}" />', "   <wave_markers>"]
    for t_ps, lab in markers:
        L.append(f'      <marker time="{t_ps}" label="{escape(lab)}" />')
    L.append("   </wave_markers>")
    g = 0
    for it in items:
        if isinstance(it, tuple):
            g += 1
            L.append(f'   <wvobject fp_name="group{g}" type="group">')
            L.append(f'      <obj_property name="label">{it[0]}</obj_property>')
            L.append('      <obj_property name="DisplayName">label</obj_property>')
            L.append('      <obj_property name="isExpanded"></obj_property>')
            for s in it[1]:
                L += obj_xml(top, s, 6)
            L.append("   </wvobject>")
        else:
            L += obj_xml(top, it, 3)
    L.append("</wave_config>")
    return "\n".join(L) + "\n"


MS = 1_000_000_000  # ps


def buttons(which="RLUD"):
    out = []
    for b in which:
        out.append(sig(f"dut/btn_{b}", f"btn_{b}"))
        out.append(sig(f"dut/U_BD_{b}/o_btn", "o_btn", label=f"{b}_tick", color=YEL))
    return out


def watch_state(updown=True):
    s = [sig("dut/U_WATCH_CONTROL_UNIT/n_state", "n_state[1:0]", "array", color=MAG),
         sig("dut/U_WATCH_CONTROL_UNIT/c_state", "c_state[1:0]", "array", color=MAG),
         sig("dut/U_WATCH_CONTROL_UNIT/o_wt_cursor", "o_wt_cursor[1:0]", "array", color=MAG,
             radix="UNSIGNEDDECRADIX")]
    if updown:
        s += [sig("dut/U_WATCH_CONTROL_UNIT/o_wt_up", "o_wt_up", color=MAG),
              sig("dut/U_WATCH_CONTROL_UNIT/o_wt_down", "o_wt_down", color=MAG)]
    return s


def watch_time(fields=("hour", "min", "sec", "msec")):
    w = {"hour": "[4:0]", "min": "[5:0]", "sec": "[5:0]", "msec": "[6:0]"}
    return [sig(f"dut/U_WATCH_DATAPATH/o_wt_{f}", f"o_wt_{f}{w[f]}", "array", color=CYN,
                radix="UNSIGNEDDECRADIX") for f in fields]


SCEN = {
    "s1": dict(
        top="tb_wt_s1_cursor_fsm", end_ps=190 * MS,
        markers=[(1_000_000, "1"), (10 * MS, "2"), (60 * MS, "3"), (70 * MS, "4"),
                 (110 * MS, "5"), (150 * MS, "6"), (180 * MS, "7")],
        items=[sig("clk", "clk"), sig("rst", "rst"),
               ("INPUT_SWITCH", [sig("set_sw2", "set_sw2")]),
               ("Button", buttons()),
               ("WATCH_STATE", watch_state()),
               ("WATCH_TIME_OUT", watch_time(("hour", "min")))]),
    "s2": dict(
        top="tb_wt_s2_btn_simul", end_ps=50 * MS,
        markers=[(1_000_000, "1"), (10 * MS, "2"), (20 * MS, "3"), (30 * MS, "4"), (40 * MS, "5")],
        items=[sig("clk", "clk"), sig("rst", "rst"),
               ("INPUT_SWITCH", [sig("set_sw2", "set_sw2")]),
               ("Button", buttons()),
               ("WATCH_STATE", watch_state()),
               ("WATCH_TIME_OUT", watch_time(("hour", "min")))]),
    "s3": dict(
        top="tb_wt_s3_one_sec", end_ps=2050 * MS,
        markers=[(1_000_000, "1"), (10_000_995_000, "2"), (1_000_001_015_000, "3"),
                 (2_000_001_015_000, "4")],
        items=[sig("rst", "rst"),
               ("INPUT_SWITCH", [sig("display_mode_sw1", "display_mode_sw1")]),
               ("TICK", [sig("dut/U_TICK_GEN_100HZ/o_tick_10ms", "o_tick_10ms", color=CYN),
                         sig("dut/U_WATCH_DATAPATH/U_MSEC_COUNTER/o_tick", "o_tick", label="sec_tick",
                             color=CYN)]),
               ("WATCH_TIME_OUT", watch_time())]),
    "s4": dict(
        top="tb_wt_s4_min_boundary", end_ps=50 * MS,
        markers=[(1_000_000, "1"), (10 * MS, "2"), (20 * MS, "3"), (30 * MS, "4"), (40 * MS, "5")],
        items=[sig("clk", "clk"), sig("rst", "rst"),
               ("INPUT_SWITCH", [sig("set_sw2", "set_sw2")]),
               ("Button", buttons("UD")),
               ("WATCH_STATE", watch_state()),
               ("WATCH_TIME_OUT", watch_time(("hour", "min")) +
                [sig("dut/U_WATCH_DATAPATH/U_MIN_COUNTER/o_tick", "o_tick", label="min_carry", color=CYN)])]),
    "s5": dict(
        top="tb_wt_s5_fnd_blink", end_ps=4000 * MS,
        markers=[(1_000_000, "1"), (1000 * MS, "2"), (2000 * MS, "3"), (3005 * MS, "4")],
        items=[sig("rst", "rst"),
               ("INPUT_SWITCH", [sig("display_mode_sw1", "display_mode_sw1"), sig("set_sw2", "set_sw2")]),
               ("Button", buttons("L")),
               ("WATCH_STATE", watch_state(updown=False)),
               ("WATCH_TIME_OUT", watch_time(("hour", "min", "msec"))),
               ("BLINK", [sig("dut/U_FND_CONTROLLER/U_DOT/o_blink_off", "o_blink_off", color=YEL)] +
                [sig(f"dut/U_FND_CONTROLLER/U_ANODE_CHOICE_TO_MUX2/o_an{i}", f"o_an{i}[3:0]", "array",
                     color=YEL, radix="HEXRADIX") for i in (3, 2, 1, 0)]),
               ("FND_OUT", [sig("mon/disp_bcd", "disp_bcd[15:0]", "array", label="FND_screen",
                                radix="HEXRADIX"),
                            sig("fnd_com", "fnd_com[3:0]", "array", radix="BINARYRADIX"),
                            sig("fnd_font", "fnd_font[7:0]", "array", radix="HEXRADIX")])]),
}

if __name__ == "__main__":
    outdir = sys.argv[1]
    for key in sys.argv[2:]:
        c = SCEN[key]
        path = f"{outdir}/{c['top']}_behav.wcfg"
        with open(path, "w", encoding="utf-8", newline="\r\n") as f:
            f.write(wcfg(c["top"], c["end_ps"], c["markers"], c["items"]))
        print("wrote", path)
