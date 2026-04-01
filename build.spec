# -*- mode: python ; coding: utf-8 -*-
import os
import customtkinter

block_cipher = None
work_dir = os.path.dirname(os.path.abspath(SPEC))
ctk_path = os.path.dirname(customtkinter.__file__)

a = Analysis(
    [os.path.join(work_dir, 'HealthCyclingAnalyzer.py')],
    pathex=[work_dir],
    binaries=[],
    datas=[
        (os.path.join(work_dir, 'dashboard.html'), '.'),
        (ctk_path, 'customtkinter'),
    ],
    hiddenimports=[
        'tkinter', 'tkinter.filedialog', 'tkinter.messagebox',
        'customtkinter', 'darkdetect',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='HealthCyclingAnalyzer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=True,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='HealthCyclingAnalyzer',
)

app = BUNDLE(
    coll,
    name='Apple Health Analyzer.app',
    icon=None,
    bundle_identifier='com.health.analyzer',
    info_plist={
        'NSHighResolutionCapable': True,
        'CFBundleShortVersionString': '2.0.0',
        'CFBundleName': 'Apple Health Analyzer',
    },
)
