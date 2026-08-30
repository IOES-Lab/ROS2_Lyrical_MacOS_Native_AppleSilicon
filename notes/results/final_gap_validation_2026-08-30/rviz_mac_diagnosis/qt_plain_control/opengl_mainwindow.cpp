#include <QApplication>
#include <QMainWindow>
#include <QOpenGLWidget>
#include <QTimer>

class GlWidget : public QOpenGLWidget
{
protected:
  void initializeGL() override
  {
    glClearColor(0.1f, 0.3f, 0.6f, 1.0f);
  }

  void paintGL() override
  {
    glClear(GL_COLOR_BUFFER_BIT);
  }
};

int main(int argc, char **argv)
{
  QApplication app(argc, argv);
  QMainWindow window;
  window.setWindowTitle("Codex Qt OpenGL control");
  window.setCentralWidget(new GlWidget);
  window.resize(640, 480);
  window.show();
  QTimer::singleShot(30000, &app, &QApplication::quit);
  return app.exec();
}
