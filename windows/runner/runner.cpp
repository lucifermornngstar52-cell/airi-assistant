#include "runner.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <Objbase.h>
#include <sapi.h>
#include <string>
#include <vector>
#include <algorithm>

Runner::Runner(flutter::FlutterEngine* engine) : engine_(engine) {
  RegisterMethodChannels();
}

void Runner::RegisterMethodChannels() {
  // App launcher channel — Windows version
  auto launcher_channel = flutter::MethodChannel(
      engine_->messenger(), "com.airi.assistant/launcher",
      &flutter::StandardMethodCodec::GetInstance());

  launcher_channel.SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& args = std::get<flutter::EncodableMap>(call.arguments());
        
        if (call.method_name() == "launchApp") {
          auto it = args.find(flutter::EncodableValue("package"));
          if (it == args.end()) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          std::string pkg = std::get<std::string>(it->second);
          
          // На Windows "package" = путь к exe или имя приложения
          // Пробуем ShellExecute
          std::wstring wpkg(pkg.begin(), pkg.end());
          HINSTANCE h = ShellExecuteW(nullptr, L"open", wpkg.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
          if ((intptr_t)h > 32) {
            result->Success(flutter::EncodableValue(true));
          } else {
            // Пробуем через CreateProcess
            STARTUPINFOW si = {sizeof(si)};
            PROCESS_INFORMATION pi;
            std::wstring cmd = L"\"" + wpkg + L"\"";
            if (CreateProcessW(nullptr, &cmd[0], nullptr, nullptr, FALSE,
                              0, nullptr, nullptr, &si, &pi)) {
              CloseHandle(pi.hProcess);
              CloseHandle(pi.hThread);
              result->Success(flutter::EncodableValue(true));
            } else {
              result->Success(flutter::EncodableValue(false));
            }
          }
        } else if (call.method_name() == "launchUrl") {
          auto it = args.find(flutter::EncodableValue("url"));
          if (it == args.end()) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          std::string url = std::get<std::string>(it->second);
          std::wstring wurl(url.begin(), url.end());
          HINSTANCE h = ShellExecuteW(nullptr, L"open", wurl.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
          result->Success(flutter::EncodableValue((intptr_t)h > 32));
        } else if (call.method_name() == "findAndLaunch") {
          auto it = args.find(flutter::EncodableValue("name"));
          if (it == args.end()) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          std::string name = std::get<std::string>(it->second);
          // Ищем в Start Menu и Desktop
          std::wstring wname(name.begin(), name.end());
          
          // Пробуем ShellExecute с "open" и именем
          HINSTANCE h = ShellExecuteW(nullptr, L"open", wname.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
          if ((intptr_t)h > 32) {
            result->Success(flutter::EncodableValue(true));
          } else {
            // Пробуем найти .lnk в Start Menu
            wchar_t startMenuPath[MAX_PATH];
            if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_PROGRAMS, nullptr, 0, startMenuPath))) {
              std::wstring searchPath = startMenuPath;
              // TODO: recursive search for .lnk files matching name
            }
            result->Success(flutter::EncodableValue(false));
          }
        } else if (call.method_name() == "isInstalled") {
          // На Windows всегда true (не можем проверить)
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "getInstalledApps") {
          // Возвращаем пустой список на Windows (нет аналога)
          result->Success(flutter::EncodableValue(std::vector<flutter::EncodableValue>()));
        } else {
          result->NotImplemented();
        }
      });
}
