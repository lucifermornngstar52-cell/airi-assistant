#ifndef WIN32_WINDOW_H_
#define WIN32_WINDOW_H_

#include <string>
#include <windows.h>

class Win32Window {
 public:
  class Size {
   public:
    Size(unsigned int width, unsigned int height) : width_(width), height_(height) {}
    unsigned int width() const { return width_; }
    unsigned int height() const { return height_; }
   private:
    unsigned int width_;
    unsigned int height_;
  };

  class Point {
   public:
    Point(int x, int y) : x_(x), y_(y) {}
    int x() const { return x_; }
    int y() const { return y_; }
   private:
    int x_;
    int y_;
  };

  Win32Window();
  virtual ~Win32Window();

  bool CreateAndShow(const std::wstring& title, const Point& origin, const Size& size);
  void SetQuitOnClose(bool quit_on_close);
  void Destroy();
  bool IsRunning() const;

 protected:
  virtual bool OnCreate();
  virtual void OnDestroy();
  void SetChildContent(HWND child_content);
  LRESULT MessageHandler(HWND window, UINT message, WPARAM wparam, LPARAM lparam);

 private:
  HWND window_handle_ = nullptr;
  HWND child_content_ = nullptr;
  bool quit_on_close_ = true;
  bool running_ = false;

  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam);
};

#endif  // WIN32_WINDOW_H_
