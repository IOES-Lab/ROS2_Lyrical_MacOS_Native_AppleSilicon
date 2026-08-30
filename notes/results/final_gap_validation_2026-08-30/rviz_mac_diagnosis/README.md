# Native macOS RViz window diagnosis

RViz initializes Qt/Cocoa, OGRE 1.12.10 and Apple-M2 OpenGL, stays alive, and reaches
render/expose callbacks. Nevertheless CoreGraphics reports its 640×508 layer-0 main
window as `onscreen=false`, while Accessibility reports zero windows.

## Controls and rejected explanations

Plain Qt controls using a QMainWindow, QOpenGLWidget, QWindow container and
QOpenGLWindow container all map on screen. RViz still fails with sanitized configuration,
fullscreen, scale/layer toggles, `QT_OPENGL=software`, `LIBGL_ALWAYS_SOFTWARE=1`, splash
removal, early/deferred `show()`, and native `NSWindow orderFront` experiments. The native
call can make the NSWindow visible/key/active-space, yet the matching CoreGraphics window
remains offscreen.

The failure is therefore narrowed to the RViz/OGRE Cocoa external-NSView integration in
this native Apple-Silicon build. No candidate in this audit produced a visible RViz main
window, so the issue remains open and no unverified workaround is documented.

Related upstream context:

- <https://github.com/ros2/rviz/issues/929>
- <https://github.com/ros2/rviz/issues/943>
- <https://doc.qt.io/qt-6/qwindow.html>

`final_experimental_overlay_state.diff` is empty: all source experiments were restored.
