#include <QApplication>
#include <QMainWindow>
#include <QOpenGLWindow>
#include <QTimer>
#include <QWidget>

class GlWindow : public QOpenGLWindow
{
protected:
  void initializeGL() override
  {
    glClearColor(0.6f, 0.2f, 0.1f, 1.0f);
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
  window.setWindowTitle("Codex QOpenGLWindow container control");
  auto * child = new GlWindow;
  child->setMinimumSize(QSize(320, 240));
  window.setCentralWidget(QWidget::createWindowContainer(child, &window));
  window.resize(640, 480);
  window.show();
  QTimer::singleShot(30000, &app, &QApplication::quit);
  return app.exec();
}
