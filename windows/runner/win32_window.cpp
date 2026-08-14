#include "win32_window.h"

#include <windowsx.h>
#include <dwmapi.h>

namespace {
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WINID";
constexpr const wchar_t kWindowTitle[] = L"AIRI";

constexpr const int kTitleBarHeight = 32;

void EnableBorderlessWindow(HWND hwnd) {
  DWORD style = GetWindowLong(hwnd, GWL_STYLE);
  style |= WS_POPUP;
  SetWindowLong(hwnd, GWL_STYLE, style);
}

LRESULT CALLBACK CustomTitleBarProc(HWND hwnd, UINT message, WPARAM wparam,
                                    LPARAM lparam, UINT_PTR id, DWORD_PTR ref) {
  return 0;
}
}

Win32Window::Win32Window() {}
Win32Window::~Win32Window() { Destroy(); }

bool Win32Window::CreateAndShow(const std::wstring& title, const Point& origin,
                                const Size& size) {
  WNDCLASS wc = {};
  wc.hInstance = GetModuleHandle(nullptr);
  wc.lpszClassName = kWindowClassName;
  wc.lpfnWndProc = WndProc;
  RegisterClass(&wc);

  window_handle_ = CreateWindow(
      kWindowClassName, title.c_str(),
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      origin.x(), origin.y(), size.width(), size.height(),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (window_handle_ == nullptr) return false;

  running_ = true;
  return true;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

void Win32Window::Destroy() {
  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  running_ = false;
}

bool Win32Window::IsRunning() const { return running_; }

void Win32Window::SetChildContent(HWND child_content) {
  child_content_ = child_content;
  RECT frame;
  GetClientRect(window_handle_, &frame);
  MoveWindow(child_content, frame.left, 0, frame.right - frame.left,
             frame.bottom, true);
}

LRESULT Win32Window::MessageHandler(HWND hwnd, UINT message, WPARAM wparam,
                                    LPARAM lparam) {
  switch (message) {
    case WM_SIZE:
      if (child_content_ != nullptr) {
        RECT frame;
        GetClientRect(hwnd, &frame);
        MoveWindow(child_content_, 0, 0, frame.right - frame.left,
                   frame.bottom, true);
      }
      return 0;
    case WM_DESTROY:
      running_ = false;
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;
    default:
      return DefWindowProc(hwnd, message, wparam, lparam);
  }
}

LRESULT CALLBACK Win32Window::WndProc(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam) {
  if (message == WM_NCCREATE) {
    auto cs = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(cs->lpCreateParams));
    auto that = static_cast<Win32Window*>(cs->lpCreateParams);
    return that->MessageHandler(hwnd, message, wparam, lparam);
  }
  auto that = reinterpret_cast<Win32Window*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (that) return that->MessageHandler(hwnd, message, wparam, lparam);
  return DefWindowProc(hwnd, message, wparam, lparam);
}

bool Win32Window::OnCreate() { return true; }
void Win32Window::OnDestroy() {}
