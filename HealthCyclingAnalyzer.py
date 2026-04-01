#!/usr/bin/env python3
"""
Apple Health Analyzer — 桌面应用
解析 Apple Health 导出数据，生成交互式分析仪表板
macOS 原生风格 / Windows 11 风格自适应 GUI
"""

import xml.etree.ElementTree as ET
from datetime import datetime
from collections import defaultdict
import json, os, sys, math, threading, webbrowser, platform

APP_NAME = "Apple Health Analyzer"
VERSION = "2.0.0"
IS_MAC = platform.system() == "Darwin"


# ═══════════════════════════════════════════════════
# 数据解析（与 v1 完全一致）
# ═══════════════════════════════════════════════════

def parse_date(s):
    return datetime.strptime(s, "%Y-%m-%d %H:%M:%S %z").replace(tzinfo=None)

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000; p = math.pi / 180
    a = 0.5 - math.cos((lat2 - lat1) * p) / 2 + \
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2
    return 2 * R * math.asin(math.sqrt(a))

def parse_gpx(filepath):
    try:
        tree = ET.parse(filepath); root = tree.getroot()
    except Exception:
        return None
    ns = "{http://www.topografix.com/GPX/1/1}"
    points = []
    for trkpt in root.iter(f"{ns}trkpt"):
        lat = float(trkpt.get("lat", 0)); lon = float(trkpt.get("lon", 0))
        speed_el = trkpt.find(f"{ns}extensions/{ns}speed")
        speed = float(speed_el.text) if speed_el is not None else None
        points.append((lat, lon, speed))
    if not points:
        return None
    speeds = [s for _, _, s in points if s is not None and s > 0.5]
    return {
        "start_lat": points[0][0], "start_lon": points[0][1],
        "end_lat": points[-1][0], "end_lon": points[-1][1],
        "avg_speed_ms": sum(speeds) / len(speeds) if speeds else 0,
    }

TRACKED_RECORDS = {
    "HKQuantityTypeIdentifierRestingHeartRate": "resting_hr",
    "HKQuantityTypeIdentifierHeartRateVariabilitySDNN": "hrv",
    "HKQuantityTypeIdentifierVO2Max": "vo2max",
    "HKQuantityTypeIdentifierBodyMass": "body_mass",
    "HKQuantityTypeIdentifierStepCount": "steps",
    "HKQuantityTypeIdentifierActiveEnergyBurned": "active_energy",
    "HKQuantityTypeIdentifierWalkingHeartRateAverage": "walking_hr",
    "HKQuantityTypeIdentifierHeartRateRecoveryOneMinute": "hr_recovery",
    "HKQuantityTypeIdentifierOxygenSaturation": "spo2",
    "HKQuantityTypeIdentifierRespiratoryRate": "resp_rate",
    "HKQuantityTypeIdentifierDietaryProtein": "protein",
    "HKQuantityTypeIdentifierDietaryEnergyConsumed": "dietary_energy",
    "HKQuantityTypeIdentifierAppleExerciseTime": "exercise_time",
}

WORKOUT_LABELS = {
    "HKWorkoutActivityTypeCycling": "骑行",
    "HKWorkoutActivityTypeTraditionalStrengthTraining": "力量训练",
    "HKWorkoutActivityTypeRunning": "跑步",
    "HKWorkoutActivityTypeWalking": "步行",
    "HKWorkoutActivityTypeSwimming": "游泳",
    "HKWorkoutActivityTypeHighIntensityIntervalTraining": "HIIT",
    "HKWorkoutActivityTypeClimbing": "攀岩",
    "HKWorkoutActivityTypeHiking": "徒步",
    "HKWorkoutActivityTypeBadminton": "羽毛球",
    "HKWorkoutActivityTypeCoreTraining": "核心训练",
    "HKWorkoutActivityTypeElliptical": "椭圆机",
    "HKWorkoutActivityTypeStairs": "爬楼",
    "HKWorkoutActivityTypeOther": "其他",
}

def find_xml(export_dir):
    for name in ["导出.xml", "export.xml"]:
        p = os.path.join(export_dir, name)
        if os.path.exists(p):
            return p
    for f in os.listdir(export_dir):
        if f.endswith(".xml") and "cda" not in f.lower():
            return os.path.join(export_dir, f)
    return None

def parse_health_data(xml_path, export_dir, progress_cb=None):
    cycling, strength, other = [], [], []
    records = {v: [] for v in TRACKED_RECORDS.values()}
    gpx_dir = os.path.join(export_dir, "workout-routes")
    depth = 0
    context = ET.iterparse(xml_path, events=("start", "end"))
    count = 0

    for event, elem in context:
        if event == "start":
            depth += 1; continue
        depth -= 1; tag = elem.tag

        if tag == "Workout" and depth == 1:
            wtype = elem.get("workoutActivityType", "")
            start_str = elem.get("startDate", "")
            if not start_str: elem.clear(); continue
            try: start = parse_date(start_str)
            except Exception: elem.clear(); continue
            duration = float(elem.get("duration", 0))
            stats = {}
            for ws in elem.iter("WorkoutStatistics"):
                stats[ws.get("type", "")] = {
                    "average": ws.get("average"), "minimum": ws.get("minimum"),
                    "maximum": ws.get("maximum"), "sum": ws.get("sum"),
                }
            metadata = {}
            for me in elem.iter("MetadataEntry"):
                metadata[me.get("key", "")] = me.get("value", "")
            route_path = None
            for fr in elem.iter("FileReference"):
                route_path = fr.get("path", "")
            hr = stats.get("HKQuantityTypeIdentifierHeartRate", {})
            active_cal = stats.get("HKQuantityTypeIdentifierActiveEnergyBurned", {})
            type_label = WORKOUT_LABELS.get(wtype, wtype.split("Type")[-1])
            w = {
                "type": wtype, "label": type_label,
                "date": start.strftime("%Y-%m-%d"), "weekday": start.isoweekday(),
                "start_hour": start.hour, "duration_min": round(duration, 2),
                "avg_hr": float(hr["average"]) if hr.get("average") else None,
                "max_hr": float(hr["maximum"]) if hr.get("maximum") else None,
                "min_hr": float(hr["minimum"]) if hr.get("minimum") else None,
                "active_cal": float(active_cal.get("sum", 0)) if active_cal.get("sum") else 0,
                "route_path": route_path,
            }
            if "Cycling" in wtype:
                dc = stats.get("HKQuantityTypeIdentifierDistanceCycling", {})
                dist = float(dc.get("sum", 0)) if dc.get("sum") else 0
                w["distance_km"] = round(dist, 3)
                w["avg_speed_kmh"] = round((dist / (duration / 60)) if duration > 0 and dist > 0 else 0, 2)
                w["elevation_cm"] = float(metadata.get("HKElevationAscended", "0 cm").split()[0]) if "HKElevationAscended" in metadata else 0
                w["avg_mets"] = float(metadata.get("HKAverageMETs", "0 kcal").split()[0]) if "HKAverageMETs" in metadata else 0
                cycling.append(w)
            elif "StrengthTraining" in wtype:
                w["avg_mets"] = float(metadata.get("HKAverageMETs", "0 kcal").split()[0]) if "HKAverageMETs" in metadata else 0
                strength.append(w)
            else:
                dw = stats.get("HKQuantityTypeIdentifierDistanceWalkingRunning", {})
                ds = stats.get("HKQuantityTypeIdentifierDistanceSwimming", {})
                w["distance_km"] = round((float(dw.get("sum", 0)) if dw.get("sum") else 0) + (float(ds.get("sum", 0)) if ds.get("sum") else 0), 3)
                other.append(w)
            elem.clear(); count += 1
            if progress_cb and count % 200 == 0:
                progress_cb(f"已处理 {count} 条运动记录…")
            continue

        if tag == "Record" and depth == 1:
            rtype = elem.get("type", "")
            bucket = TRACKED_RECORDS.get(rtype)
            if bucket:
                try: start = parse_date(elem.get("startDate", ""))
                except Exception: elem.clear(); continue
                val = elem.get("value")
                if val:
                    try: records[bucket].append({"date": start.strftime("%Y-%m-%d"), "value": float(val)})
                    except ValueError: pass
            elem.clear(); continue
        if depth <= 1: elem.clear()

    if progress_cb:
        progress_cb(f"XML 解析完成: {len(cycling)} 骑行 · {len(strength)} 力训 · {len(other)} 其他")
        progress_cb("正在解析 GPX 路线…")

    for w in cycling:
        if w.get("route_path") and os.path.isdir(gpx_dir):
            gpx_file = os.path.join(export_dir, w["route_path"].lstrip("/"))
            if os.path.exists(gpx_file):
                g = parse_gpx(gpx_file)
                if g:
                    w["gpx_avg_speed_kmh"] = round(g["avg_speed_ms"] * 3.6, 2)
                    w["start_lat"] = g["start_lat"]; w["start_lon"] = g["start_lon"]
                    w["end_lat"] = g["end_lat"]; w["end_lon"] = g["end_lon"]

    if progress_cb: progress_cb("正在识别通勤路线…")
    routes_with_gpx = [w for w in cycling if w.get("start_lat")]
    clusters = []
    for w in routes_with_gpx:
        matched = False
        for c in clusters:
            ref = c["ref"]
            d1 = haversine(w["start_lat"], w["start_lon"], ref[0], ref[1])
            d2 = haversine(w["end_lat"], w["end_lon"], ref[2], ref[3])
            d1r = haversine(w["start_lat"], w["start_lon"], ref[2], ref[3])
            d2r = haversine(w["end_lat"], w["end_lon"], ref[0], ref[1])
            if (d1 < 800 and d2 < 800) or (d1r < 800 and d2r < 800):
                c["dates"].append(w["date"]); matched = True; break
        if not matched:
            clusters.append({"ref": (w["start_lat"], w["start_lon"], w["end_lat"], w["end_lon"]), "dates": [w["date"]]})
    clusters.sort(key=lambda c: len(c["dates"]), reverse=True)
    route_labels = {}
    for i, c in enumerate(clusters):
        for d in c["dates"]: route_labels.setdefault(d, []).append(i)
    for w in cycling:
        w["route_cluster"] = route_labels.get(w["date"], [-1])[0] if w["date"] in route_labels else -1
    for w in cycling:
        for k in ("start_lat", "start_lon", "end_lat", "end_lon", "route_path"): w.pop(k, None)

    def daily_avg(rec_list):
        d = defaultdict(list)
        for r in rec_list: d[r["date"]].append(r["value"])
        return {dt: round(sum(v)/len(v), 1) for dt, v in d.items()}
    def daily_sum(rec_list):
        d = defaultdict(float)
        for r in rec_list: d[r["date"]] += r["value"]
        return {dt: round(v, 1) for dt, v in d.items()}

    commute_id = 0 if clusters else -1
    return {
        "generated_at": datetime.now().isoformat(),
        "cycling": cycling,
        "strength": [{k: w[k] for k in ("type","label","date","weekday","start_hour","duration_min","avg_hr","max_hr","min_hr","active_cal","avg_mets")} for w in strength],
        "other": [{k: w.get(k) for k in ("type","label","date","weekday","start_hour","duration_min","distance_km","avg_hr","max_hr","active_cal")} for w in other],
        "route_clusters": [{"id":i,"count":len(c["dates"]),"dates":c["dates"]} for i,c in enumerate(clusters[:10])],
        "commute_cluster_id": commute_id,
        "resting_hr": daily_avg(records["resting_hr"]),
        "hrv": daily_avg(records["hrv"]),
        "vo2max": daily_avg(records["vo2max"]),
        "body_mass": daily_avg(records["body_mass"]),
        "steps": daily_sum(records["steps"]),
        "active_energy": daily_sum(records["active_energy"]),
        "walking_hr": daily_avg(records["walking_hr"]),
        "hr_recovery": daily_avg(records["hr_recovery"]),
        "spo2": daily_avg(records["spo2"]),
        "protein": daily_sum(records["protein"]),
        "dietary_energy": daily_sum(records["dietary_energy"]),
        "exercise_time": daily_sum(records["exercise_time"]),
    }


# ═══════════════════════════════════════════════════
# HTML 模板
# ═══════════════════════════════════════════════════

def _find_dashboard():
    candidates = [
        os.path.join(getattr(sys, '_MEIPASS', ''), "dashboard.html"),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "dashboard.html"),
    ]
    for p in candidates:
        if os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return f.read()
    return ""

DASHBOARD_HTML = _find_dashboard()

def generate_standalone_html(data_json):
    if not DASHBOARD_HTML:
        return "<html><body><h1>Error: dashboard.html not found</h1></body></html>"
    return DASHBOARD_HTML.replace(
        "fetch('analysis_data.json')\n  .then(r => r.json())\n  .then(d => { DATA = d; normalizeData(); init(); })\n  .catch(e => { document.getElementById('loading').textContent = '加载失败: ' + e.message; });",
        f"DATA = {data_json};\nnormalizeData();\ninit();"
    )


# ═══════════════════════════════════════════════════
# GUI — customtkinter
# ═══════════════════════════════════════════════════

def run_gui():
    import customtkinter as ctk

    ctk.set_appearance_mode("light")
    ctk.set_default_color_theme("blue")

    # Platform-aware colors & fonts
    if IS_MAC:
        BG = "#f5f5f7"
        CARD = "#ffffff"
        BORDER = "#d2d2d7"
        DROP_BG = "#fafafa"
        ACCENT = "#0071e3"
        TEXT = "#1d1d1f"
        TEXT_DIM = "#86868b"
        FONT_FAMILY = "Helvetica Neue"
        FONT_BODY = "Helvetica Neue"
        WIN_W, WIN_H = 580, 520
    else:
        BG = "#f3f3f3"
        CARD = "#ffffff"
        BORDER = "#e0e0e0"
        DROP_BG = "#f9f9f9"
        ACCENT = "#0067c0"
        TEXT = "#1a1a1a"
        TEXT_DIM = "#616161"
        FONT_FAMILY = "Segoe UI"
        FONT_BODY = "Segoe UI"
        WIN_W, WIN_H = 580, 520

    root = ctk.CTk()
    root.title(APP_NAME)
    root.geometry(f"{WIN_W}x{WIN_H}")
    root.resizable(False, False)
    root.configure(fg_color=BG)

    # State
    selected_path = ctk.StringVar(value="")
    is_analyzing = False

    # ── Header ──
    header = ctk.CTkFrame(root, fg_color=CARD, corner_radius=0, height=72)
    header.pack(fill="x")
    header.pack_propagate(False)

    title_frame = ctk.CTkFrame(header, fg_color="transparent")
    title_frame.pack(expand=True)

    ctk.CTkLabel(title_frame, text="♥", font=(FONT_FAMILY, 28),
                 text_color=ACCENT).pack(side="left", padx=(0, 8))
    ctk.CTkLabel(title_frame, text=APP_NAME, font=(FONT_FAMILY, 20, "bold"),
                 text_color=TEXT).pack(side="left")
    ctk.CTkLabel(title_frame, text=f"v{VERSION}", font=(FONT_BODY, 11),
                 text_color=TEXT_DIM).pack(side="left", padx=(8, 0), pady=(6, 0))

    # Subtle separator
    ctk.CTkFrame(root, fg_color=BORDER, height=1).pack(fill="x")

    # ── Content area ──
    content = ctk.CTkFrame(root, fg_color=BG, corner_radius=0)
    content.pack(fill="both", expand=True, padx=24, pady=20)

    # ── Drop zone ──
    drop_frame = ctk.CTkFrame(content, fg_color=DROP_BG, corner_radius=16,
                              border_width=2, border_color=BORDER)
    drop_frame.pack(fill="both", expand=True)

    drop_inner = ctk.CTkFrame(drop_frame, fg_color="transparent")
    drop_inner.place(relx=0.5, rely=0.45, anchor="center")

    folder_icon_label = ctk.CTkLabel(drop_inner, text="📁", font=(FONT_FAMILY, 48))
    folder_icon_label.pack()

    drop_title = ctk.CTkLabel(
        drop_inner, text="将 Apple Health 导出文件夹拖放到此处",
        font=(FONT_FAMILY, 15, "bold"), text_color=TEXT)
    drop_title.pack(pady=(8, 4))

    drop_subtitle = ctk.CTkLabel(
        drop_inner, text="或点击下方按钮手动选择文件夹",
        font=(FONT_BODY, 12), text_color=TEXT_DIM)
    drop_subtitle.pack()

    path_label = ctk.CTkLabel(
        drop_frame, text="", font=(FONT_BODY, 11), text_color=ACCENT,
        wraplength=WIN_W - 100)
    path_label.place(relx=0.5, rely=0.78, anchor="center")

    # ── Loading overlay (hidden by default) ──
    loading_frame = ctk.CTkFrame(content, fg_color=CARD, corner_radius=16,
                                 border_width=1, border_color=BORDER)

    loading_inner = ctk.CTkFrame(loading_frame, fg_color="transparent")
    loading_inner.place(relx=0.5, rely=0.4, anchor="center")

    spinner_var = ctk.StringVar(value="⏳")
    spinner_label = ctk.CTkLabel(loading_inner, textvariable=spinner_var,
                                 font=(FONT_FAMILY, 36))
    spinner_label.pack()

    loading_title = ctk.CTkLabel(loading_inner, text="正在分析健康数据…",
                                 font=(FONT_FAMILY, 16, "bold"), text_color=TEXT)
    loading_title.pack(pady=(12, 6))

    progress_var = ctk.StringVar(value="准备中…")
    progress_label = ctk.CTkLabel(loading_inner, textvariable=progress_var,
                                  font=(FONT_BODY, 12), text_color=TEXT_DIM,
                                  wraplength=WIN_W - 120)
    progress_label.pack()

    progress_bar = ctk.CTkProgressBar(loading_frame, width=WIN_W - 120,
                                       mode="indeterminate",
                                       progress_color=ACCENT)
    progress_bar.place(relx=0.5, rely=0.72, anchor="center")

    # ── Success overlay (hidden) ──
    success_frame = ctk.CTkFrame(content, fg_color=CARD, corner_radius=16,
                                 border_width=1, border_color=BORDER)

    success_inner = ctk.CTkFrame(success_frame, fg_color="transparent")
    success_inner.place(relx=0.5, rely=0.35, anchor="center")

    ctk.CTkLabel(success_inner, text="✅", font=(FONT_FAMILY, 48)).pack()
    ctk.CTkLabel(success_inner, text="分析完成！",
                 font=(FONT_FAMILY, 18, "bold"), text_color=TEXT).pack(pady=(10, 4))

    result_var = ctk.StringVar(value="")
    ctk.CTkLabel(success_inner, textvariable=result_var,
                 font=(FONT_BODY, 12), text_color=TEXT_DIM,
                 wraplength=WIN_W - 120).pack()

    report_path_var = ctk.StringVar(value="")

    def open_report():
        p = report_path_var.get()
        if p and os.path.exists(p):
            webbrowser.open(f"file://{p}")

    def reset_ui():
        nonlocal is_analyzing
        is_analyzing = False
        success_frame.place_forget()
        loading_frame.place_forget()
        drop_frame.pack(fill="both", expand=True)
        selected_path.set("")
        path_label.configure(text="")
        btn_analyze.configure(state="disabled")

    btn_row_success = ctk.CTkFrame(success_frame, fg_color="transparent")
    btn_row_success.place(relx=0.5, rely=0.72, anchor="center")

    ctk.CTkButton(btn_row_success, text="打开报告", font=(FONT_BODY, 14, "bold"),
                  fg_color=ACCENT, hover_color="#005bb5" if IS_MAC else "#005a9e",
                  corner_radius=10, height=40, width=140,
                  command=open_report).pack(side="left", padx=8)

    ctk.CTkButton(btn_row_success, text="重新选择", font=(FONT_BODY, 14),
                  fg_color="transparent", hover_color=BORDER, text_color=TEXT_DIM,
                  border_width=1, border_color=BORDER,
                  corner_radius=10, height=40, width=140,
                  command=reset_ui).pack(side="left", padx=8)

    # ── Bottom button bar ──
    btn_bar = ctk.CTkFrame(root, fg_color=BG, corner_radius=0, height=60)
    btn_bar.pack(fill="x", padx=24, pady=(0, 16))
    btn_bar.pack_propagate(False)

    def browse_folder():
        from tkinter import filedialog
        d = filedialog.askdirectory(title="选择 Apple Health 导出文件夹", mustexist=True)
        if d:
            set_path(d)

    def set_path(p):
        p = p.strip().strip("'\"")
        if os.path.isdir(p):
            xml = find_xml(p)
            if xml:
                selected_path.set(p)
                short = p if len(p) < 60 else "…" + p[-55:]
                path_label.configure(text=f"✓ {short}")
                btn_analyze.configure(state="normal")
                drop_title.configure(text="已选择数据目录")
                drop_subtitle.configure(text="点击「开始分析」生成报告")
                folder_icon_label.configure(text="✅")
            else:
                path_label.configure(text="⚠ 该文件夹中未找到 导出.xml")
                btn_analyze.configure(state="disabled")

    btn_browse = ctk.CTkButton(
        btn_bar, text="选择文件夹", font=(FONT_BODY, 14),
        fg_color="transparent", hover_color=BORDER, text_color=TEXT,
        border_width=1, border_color=BORDER,
        corner_radius=10, height=40, width=130,
        command=browse_folder)
    btn_browse.pack(side="left")

    def start_analysis():
        nonlocal is_analyzing
        if is_analyzing:
            return
        is_analyzing = True

        drop_frame.pack_forget()
        loading_frame.place(relx=0, rely=0, relwidth=1, relheight=1)
        progress_bar.start()
        progress_var.set("准备中…")
        btn_analyze.configure(state="disabled")
        btn_browse.configure(state="disabled")

        spinner_frames = ["⏳", "🔄", "📊", "🔍", "💓", "🏋️", "🚴", "📈"]
        spin_idx = [0]

        def animate_spinner():
            if is_analyzing:
                spin_idx[0] = (spin_idx[0] + 1) % len(spinner_frames)
                spinner_var.set(spinner_frames[spin_idx[0]])
                root.after(400, animate_spinner)

        animate_spinner()

        def worker():
            try:
                export_dir = selected_path.get()
                xml_path = find_xml(export_dir)

                def update_progress(msg):
                    root.after(0, lambda: progress_var.set(msg))

                update_progress("正在解析 XML 数据（可能需要 1-2 分钟）…")
                data = parse_health_data(xml_path, export_dir, update_progress)

                update_progress("正在生成报告…")
                output_dir = os.path.dirname(export_dir) if os.path.isdir(os.path.dirname(export_dir)) else os.path.expanduser("~/Desktop")
                data_json = json.dumps(data, ensure_ascii=False, default=str)

                json_path = os.path.join(output_dir, "analysis_data.json")
                with open(json_path, "w", encoding="utf-8") as f:
                    f.write(data_json)

                html = generate_standalone_html(data_json)
                html_path = os.path.join(output_dir, "report.html")
                with open(html_path, "w", encoding="utf-8") as f:
                    f.write(html)

                root.after(0, lambda: on_success(data, html_path))
            except Exception as e:
                root.after(0, lambda: on_error(str(e)))

        threading.Thread(target=worker, daemon=True).start()

    def on_success(data, html_path):
        nonlocal is_analyzing
        is_analyzing = False
        progress_bar.stop()
        loading_frame.place_forget()

        n_cyc = len(data["cycling"])
        n_str = len(data["strength"])
        n_oth = len(data["other"])
        result_var.set(f"骑行 {n_cyc} 次 · 力量训练 {n_str} 次 · 其他运动 {n_oth} 次\n报告已保存至: {html_path}")
        report_path_var.set(html_path)

        success_frame.place(relx=0, rely=0, relwidth=1, relheight=1)
        btn_browse.configure(state="normal")

    def on_error(msg):
        nonlocal is_analyzing
        is_analyzing = False
        progress_bar.stop()
        loading_frame.place_forget()
        drop_frame.pack(fill="both", expand=True)
        path_label.configure(text=f"❌ 分析失败: {msg}")
        btn_analyze.configure(state="normal")
        btn_browse.configure(state="normal")

    btn_analyze = ctk.CTkButton(
        btn_bar, text="开始分析", font=(FONT_BODY, 14, "bold"),
        fg_color=ACCENT, hover_color="#005bb5" if IS_MAC else "#005a9e",
        corner_radius=10, height=40, width=130,
        state="disabled", command=start_analysis)
    btn_analyze.pack(side="right")

    # ── Drag & Drop support ──
    try:
        from tkinterdnd2 import DND_FILES, TkinterDnD
        # Recreate as TkinterDnD-capable window
        # Since root is already created with CTk, we register DnD on it
        root.drop_target_register(DND_FILES)

        def on_drop(event):
            path = event.data.strip().strip("{}")
            if path:
                set_path(path)

        root.dnd_bind("<<Drop>>", on_drop)

        def on_drag_enter(event):
            drop_frame.configure(border_color=ACCENT)

        def on_drag_leave(event):
            drop_frame.configure(border_color=BORDER)

        root.dnd_bind("<<DragEnter>>", on_drag_enter)
        root.dnd_bind("<<DragLeave>>", on_drag_leave)
    except Exception:
        drop_subtitle.configure(text="点击下方按钮选择文件夹")

    # Auto-detect local data
    local = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apple_health_export")
    if not getattr(sys, '_MEIPASS', None) and os.path.isdir(local):
        set_path(local)

    root.mainloop()


# ═══════════════════════════════════════════════════
# CLI fallback
# ═══════════════════════════════════════════════════

def run_cli():
    print(f"\n{'='*50}")
    print(f"  {APP_NAME} v{VERSION}")
    print(f"{'='*50}\n")

    export_dir = sys.argv[1] if len(sys.argv) > 1 else None
    if not export_dir:
        local = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apple_health_export")
        if os.path.isdir(local):
            export_dir = local
        else:
            print("用法: python HealthCyclingAnalyzer.py [apple_health_export目录]")
            sys.exit(1)

    xml_path = find_xml(export_dir)
    if not xml_path:
        print(f"错误: 在 {export_dir} 中找不到 XML 文件"); sys.exit(1)

    data = parse_health_data(xml_path, export_dir, lambda m: print(f"  {m}"))
    output_dir = os.path.dirname(export_dir) if os.path.isdir(os.path.dirname(export_dir)) else os.path.expanduser("~/Desktop")
    data_json = json.dumps(data, ensure_ascii=False, default=str)

    with open(os.path.join(output_dir, "analysis_data.json"), "w", encoding="utf-8") as f:
        f.write(data_json)
    html = generate_standalone_html(data_json)
    html_path = os.path.join(output_dir, "report.html")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"\n  报告已生成: {html_path}")
    webbrowser.open(f"file://{html_path}")


# ═══════════════════════════════════════════════════
# 入口
# ═══════════════════════════════════════════════════

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--cli":
        run_cli()
    else:
        try:
            run_gui()
        except Exception:
            run_cli()
