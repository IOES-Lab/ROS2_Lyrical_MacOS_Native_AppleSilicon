#include <QApplication>
#include <QLabel>
#include <QMainWindow>
#include <QTimer>

int main(int argc, char **argv)
{
  QApplication app(argc, argv);
  QMainWindow window;
  window.setWindowTitle("Codex Qt plain control");
  window.setCentralWidget(new QLabel("Plain Qt 6.11.1 QMainWindow", &window));
  window.resize(640, 480);
  window.show();
  QTimer::singleShot(30000, &app, &QApplication::quit);
  return app.exec();
}
