#!/usr/bin/env python3
"""
健康骑行数据分析器 - 桌面应用
解析 Apple Health 导出数据，生成交互式分析仪表板
支持 macOS / Windows
"""

import xml.etree.ElementTree as ET
from datetime import datetime
from collections import defaultdict
import json
import os
import sys
import math
import tempfile
import webbrowser

APP_NAME = "健康骑行数据分析器"
VERSION = "1.0.0"

# ── GUI: 选择目录 ──

def select_directory():
    """弹出目录选择对话框"""
    try:
        import tkinter as tk
        from tkinter import filedialog, messagebox
        root = tk.Tk()
        root.withdraw()
        root.attributes('-topmost', True)
        
        messagebox.showinfo(APP_NAME, 
            "请选择 Apple Health 导出目录\n"
            "（包含 导出.xml 或 export.xml 的文件夹）")
        
        dir_path = filedialog.askdirectory(
            title="选择 Apple Health 导出目录",
            mustexist=True
        )
        root.destroy()
        return dir_path if dir_path else None
    except Exception:
        return None

def find_xml(export_dir):
    """在导出目录中找到主 XML 文件"""
    candidates = ["导出.xml", "export.xml"]
    for name in candidates:
        p = os.path.join(export_dir, name)
        if os.path.exists(p):
            return p
    for f in os.listdir(export_dir):
        if f.endswith(".xml") and "cda" not in f.lower():
            return os.path.join(export_dir, f)
    return None

# ── 数据解析 ──

def parse_date(s):
    return datetime.strptime(s, "%Y-%m-%d %H:%M:%S %z").replace(tzinfo=None)

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    p = math.pi / 180
    a = 0.5 - math.cos((lat2 - lat1) * p) / 2 + \
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2
    return 2 * R * math.asin(math.sqrt(a))

def parse_gpx(filepath):
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()
    except Exception:
        return None
    points = []
    for trkpt in root.iter("{http://www.topografix.com/GPX/1/1}trkpt"):
        lat = float(trkpt.get("lat", 0))
        lon = float(trkpt.get("lon", 0))
        speed_el = trkpt.find("{http://www.topografix.com/GPX/1/1}extensions/{http://www.topografix.com/GPX/1/1}speed")
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

def parse_health_data(xml_path, export_dir, progress_cb=None):
    """解析 Apple Health XML，返回分析数据 dict"""
    cycling = []
    strength = []
    other = []
    records = {v: [] for v in TRACKED_RECORDS.values()}

    gpx_dir = os.path.join(export_dir, "workout-routes")

    depth = 0
    context = ET.iterparse(xml_path, events=("start", "end"))
    count = 0

    for event, elem in context:
        if event == "start":
            depth += 1
            continue
        depth -= 1
        tag = elem.tag

        if tag == "Workout" and depth == 1:
            wtype = elem.get("workoutActivityType", "")
            start_str = elem.get("startDate", "")
            if not start_str:
                elem.clear(); continue
            try:
                start = parse_date(start_str)
            except Exception:
                elem.clear(); continue

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
                "date": start.strftime("%Y-%m-%d"),
                "weekday": start.isoweekday(), "start_hour": start.hour,
                "duration_min": round(duration, 2),
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
                dist_w = float(dw.get("sum", 0)) if dw.get("sum") else 0
                dist_s = float(ds.get("sum", 0)) if ds.get("sum") else 0
                w["distance_km"] = round(dist_w + dist_s, 3)
                other.append(w)

            elem.clear()
            count += 1
            if progress_cb and count % 200 == 0:
                progress_cb(f"已处理 {count} 条运动记录…")
            continue

        if tag == "Record" and depth == 1:
            rtype = elem.get("type", "")
            bucket = TRACKED_RECORDS.get(rtype)
            if bucket:
                try:
                    start = parse_date(elem.get("startDate", ""))
                except Exception:
                    elem.clear(); continue
                val = elem.get("value")
                if val:
                    try:
                        records[bucket].append({"date": start.strftime("%Y-%m-%d"), "value": float(val)})
                    except ValueError:
                        pass
            elem.clear(); continue

        if depth <= 1:
            elem.clear()

    if progress_cb:
        progress_cb(f"XML解析完成: {len(cycling)}骑行 + {len(strength)}力训 + {len(other)}其他")

    # GPX
    if progress_cb:
        progress_cb("正在解析 GPX 路线…")
    for w in cycling:
        if w.get("route_path") and os.path.isdir(gpx_dir):
            gpx_file = os.path.join(export_dir, w["route_path"].lstrip("/"))
            if os.path.exists(gpx_file):
                g = parse_gpx(gpx_file)
                if g:
                    w["gpx_avg_speed_kmh"] = round(g["avg_speed_ms"] * 3.6, 2)
                    w["start_lat"] = g["start_lat"]
                    w["start_lon"] = g["start_lon"]
                    w["end_lat"] = g["end_lat"]
                    w["end_lon"] = g["end_lon"]

    # 路线聚类
    if progress_cb:
        progress_cb("正在识别通勤路线…")
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
            clusters.append({"ref": (w["start_lat"], w["start_lon"], w["end_lat"], w["end_lon"]),
                             "dates": [w["date"]]})

    clusters.sort(key=lambda c: len(c["dates"]), reverse=True)
    route_labels = {}
    for i, c in enumerate(clusters):
        for d in c["dates"]:
            route_labels.setdefault(d, []).append(i)
    for w in cycling:
        w["route_cluster"] = route_labels.get(w["date"], [-1])[0] if w["date"] in route_labels else -1
    commute_id = 0 if clusters else -1

    for w in cycling:
        for k in ("start_lat", "start_lon", "end_lat", "end_lon", "route_path"):
            w.pop(k, None)

    def daily_avg(rec_list):
        d = defaultdict(list)
        for r in rec_list:
            d[r["date"]].append(r["value"])
        return {dt: round(sum(v)/len(v), 1) for dt, v in d.items()}

    def daily_sum(rec_list):
        d = defaultdict(float)
        for r in rec_list:
            d[r["date"]] += r["value"]
        return {dt: round(v, 1) for dt, v in d.items()}

    return {
        "generated_at": datetime.now().isoformat(),
        "cycling": cycling,
        "strength": [{k: w[k] for k in ("type","label","date","weekday","start_hour",
                       "duration_min","avg_hr","max_hr","min_hr","active_cal","avg_mets")} for w in strength],
        "other": [{k: w.get(k) for k in ("type","label","date","weekday","start_hour",
                    "duration_min","distance_km","avg_hr","max_hr","active_cal")} for w in other],
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


# ── HTML 模板 ──

def _find_dashboard():
    """查找 dashboard.html，兼容 PyInstaller 打包后的路径"""
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
    """生成嵌入数据的独立 HTML"""
    if not DASHBOARD_HTML:
        return "<html><body><h1>Error: dashboard.html not found</h1></body></html>"
    
    html = DASHBOARD_HTML.replace(
        "fetch('analysis_data.json')\n  .then(r => r.json())\n  .then(d => { DATA = d; normalizeData(); init(); })\n  .catch(e => { document.getElementById('loading').textContent = '加载失败: ' + e.message; });",
        f"DATA = {data_json};\nnormalizeData();\ninit();"
    )
    return html


# ── 主入口 ──

def main():
    print(f"\n{'='*50}")
    print(f"  {APP_NAME} v{VERSION}")
    print(f"{'='*50}\n")

    # 1. 确定数据目录
    export_dir = None
    
    if len(sys.argv) > 1:
        export_dir = sys.argv[1]
    else:
        # 先检查当前目录
        local = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apple_health_export")
        if os.path.isdir(local):
            export_dir = local
            print(f"发现本地数据: {export_dir}")
        else:
            print("未找到本地数据，弹出选择对话框…")
            export_dir = select_directory()

    if not export_dir:
        print("未选择目录，退出。")
        sys.exit(0)

    xml_path = find_xml(export_dir)
    if not xml_path:
        print(f"错误: 在 {export_dir} 中找不到 XML 文件")
        sys.exit(1)

    print(f"数据目录: {export_dir}")
    print(f"XML文件:  {xml_path}")
    print()

    # 2. 解析数据
    def progress(msg):
        print(f"  {msg}")

    data = parse_health_data(xml_path, export_dir, progress)
    
    print(f"\n  骑行: {len(data['cycling'])} 条")
    print(f"  力训: {len(data['strength'])} 条")
    print(f"  其他: {len(data['other'])} 条")

    # 3. 确定输出目录（优先导出目录的父目录，其次桌面）
    output_dir = os.path.dirname(export_dir) if os.path.isdir(os.path.dirname(export_dir)) else os.path.expanduser("~/Desktop")
    
    json_path = os.path.join(output_dir, "analysis_data.json")
    data_json = json.dumps(data, ensure_ascii=False, default=str)
    with open(json_path, "w", encoding="utf-8") as f:
        f.write(data_json)
    print(f"\n  JSON 已保存: {json_path}")

    # 4. 生成独立 HTML
    html = generate_standalone_html(data_json)
    html_path = os.path.join(output_dir, "report.html")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"  报告已生成: {html_path}")

    # 5. 打开浏览器
    print(f"\n正在打开浏览器…")
    webbrowser.open(f"file://{html_path}")
    print("完成！")


if __name__ == "__main__":
    main()
