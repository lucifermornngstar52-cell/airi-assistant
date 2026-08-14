#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <string>
#include "flutter_window.h"
#include "runner.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HWND hwnd = ::FindWindow(L"FLUTTER_RUNNER_WINID", L"airi_assistant");
  if (hwnd != nullptr) {
    ::ShowWindow(hwnd, SW_RESTORE);
    ::SetForegroundWindow(hwnd);
    return EXIT_FAILURE;
  }

  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr)) return EXIT_FAILURE;

  flutter::DartProject project(L"data");
  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(420, 800);
  if (!window.CreateAndShow(L"AIRI", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::DispatchMessage(&msg);
  while (window.IsRunning()) {
    MSG msg;
    while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
      if (msg.message == WM_QUIT) {
        window.Destroy();
        break;
      }
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }
    Sleep(16);
  }

  CoUninitialize();
  return EXIT_SUCCESS;
}
