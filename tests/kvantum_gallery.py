"""Render a Dolphin-like widget gallery with the generated Opal Kvantum theme.

Usage: python3 tests/kvantum_gallery.py OUT_DIR. It writes gallery-dark.png and gallery-light.png. Nothing outside a temporary HOME is touched.
"""
import os
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DARK = {'primary': '#c7cc79', 'onPrimary': '#303300', 'primaryContainer': '#464a02', 'onPrimaryContainer': '#e3e892', 'secondary': '#c8c9a6',
        'tertiary': '#a3d0bf', 'base': '#14140c', 'surface': '#202018', 'surfaceHigh': '#2a2a22', 'text': '#e5e3d6', 'subtext': '#c9c7b6', 'error': '#ffb4ab'}
LIGHT = {'primary': '#5e621b', 'onPrimary': '#ffffff', 'primaryContainer': '#e3e892', 'onPrimaryContainer': '#1b1d00', 'secondary': '#5f6044',
         'tertiary': '#3c6659', 'base': '#fcfaec', 'surface': '#f1eee1', 'surfaceHigh': '#ebe8db', 'text': '#1c1c14', 'subtext': '#47473b', 'error': '#ba1a1a'}


def render(out):
    """Child process: build the widgets and grab them."""
    from PySide6 import QtCore, QtGui, QtWidgets
    app = QtWidgets.QApplication([])
    win = QtWidgets.QMainWindow()
    win.resize(980, 620)
    bar = win.addToolBar('Main')
    style = app.style()
    for icon, text in ((QtWidgets.QStyle.SP_ArrowBack, ''), (QtWidgets.QStyle.SP_ArrowForward, ''), (QtWidgets.QStyle.SP_FileDialogDetailedView, 'View')):
        action = bar.addAction(style.standardIcon(icon), text)
    crumb = QtWidgets.QLineEdit('/ home / melissa / Music')
    bar.addWidget(crumb)
    split = bar.addAction(style.standardIcon(QtWidgets.QStyle.SP_TitleBarNormalButton), 'Split')
    split.setCheckable(True)
    split.setChecked(True)
    bar.setToolButtonStyle(QtCore.Qt.ToolButtonTextBesideIcon)
    body = QtWidgets.QSplitter()
    places = QtWidgets.QListWidget()
    for name in ('Home', 'Desktop', 'Documents', 'Downloads', 'Music', 'Pictures', 'Videos', 'Wastebin'):
        places.addItem(QtWidgets.QListWidgetItem(style.standardIcon(QtWidgets.QStyle.SP_DirIcon), name))
    places.setCurrentRow(4)
    places.setMaximumWidth(220)
    body.addWidget(places)
    right = QtWidgets.QWidget()
    grid = QtWidgets.QVBoxLayout(right)
    tabs = QtWidgets.QTabWidget()
    files = QtWidgets.QTreeWidget()
    files.setHeaderLabels(['Name', 'Size', 'Modified'])
    for i, name in enumerate(('Albums', 'Playlists', 'snowfall.flac', 'cover.png', 'notes.txt')):
        QtWidgets.QTreeWidgetItem(files, [name, '%d MiB' % (i * 7 + 3), 'Today'])
    files.setCurrentItem(files.topLevelItem(2))
    tabs.addTab(files, 'Music')
    tabs.addTab(QtWidgets.QWidget(), 'Downloads')
    grid.addWidget(tabs)
    row = QtWidgets.QHBoxLayout()
    for text, default in (('Cancel', False), ('Open', True)):
        b = QtWidgets.QPushButton(text)
        b.setDefault(default)
        row.addWidget(b)
    combo = QtWidgets.QComboBox()
    combo.addItems(['Icons', 'Details'])
    row.addWidget(combo)
    check = QtWidgets.QCheckBox('Hidden files')
    check.setChecked(True)
    row.addWidget(check)
    radio = QtWidgets.QRadioButton('Sort by name')
    radio.setChecked(True)
    row.addWidget(radio)
    spin = QtWidgets.QSpinBox()
    spin.setValue(42)
    row.addWidget(spin)
    grid.addLayout(row)
    body.addWidget(right)
    win.setCentralWidget(body)
    status = win.statusBar()
    status.addWidget(QtWidgets.QLabel('11 folders, 12 files (191.7 MiB)'))
    zoom = QtWidgets.QSlider(QtCore.Qt.Horizontal)
    zoom.setValue(35)
    zoom.setFixedWidth(160)
    status.addPermanentWidget(QtWidgets.QLabel('Zoom:'))
    status.addPermanentWidget(zoom)
    free = QtWidgets.QProgressBar()
    free.setValue(62)
    free.setFormat('576 GiB free')
    free.setFixedWidth(160)
    status.addPermanentWidget(free)
    win.show()
    app.processEvents()
    win.grab().save(out)


def main():
    if len(sys.argv) == 3 and sys.argv[1] == '--child':
        render(sys.argv[2])
        return
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    out.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(ROOT / 'src'))
    import theme_export
    for name, colors, light in (('dark', DARK, False), ('light', LIGHT, True)):
        with tempfile.TemporaryDirectory() as home:
            theme_export.export(colors, ('qt',), home=home, runner=lambda args: None, which=lambda name: None, kvantum=lambda: True, options={'light': light})
            env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=home + '/.config', QT_QPA_PLATFORM='offscreen', QT_STYLE_OVERRIDE='kvantum')
            env.pop('QT_QPA_PLATFORMTHEME', None)
            subprocess.run([sys.executable, __file__, '--child', str(out / ('gallery-%s.png' % name))], env=env, check=True)
    print(out)


if __name__ == '__main__':
    main()
