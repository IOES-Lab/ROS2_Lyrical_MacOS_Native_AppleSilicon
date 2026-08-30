#include <QApplication>
#include <QMainWindow>
#include <QTimer>
#include <QWindow>
#include <QWidget>

int main(int argc, char **argv)
{
  QApplication app(argc, argv);
  QMainWindow window;
  window.setWindowTitle("Codex QWindow container control");
  auto * child = new QWindow;
  child->setTitle("embedded QWindow");
  child->setMinimumSize(QSize(320, 240));
  window.setCentralWidget(QWidget::createWindowContainer(child, &window));
  window.resize(640, 480);
  window.show();
  QTimer::singleShot(30000, &app, &QApplication::quit);
  return app.exec();
}
