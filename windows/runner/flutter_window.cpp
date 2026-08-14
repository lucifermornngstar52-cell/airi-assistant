#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <optional>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT message,
                                       WPARAM wparam, LPARAM lparam) {
  if (flutter_controller_) {
    return flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                         lparam);
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}
