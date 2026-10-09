#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include "win32_window.h"

int APIENTRY wWinMain(HINSTANCE instance, HINSTANCE, wchar_t*, int) {
  flutter::DartProject project(L"data");
  auto window = std::make_unique<Win32Window>();
  if (!window->CreateAndShow(L"awesome_safe", {800, 600})) return EXIT_FAILURE;
  flutter::FlutterViewController controller(800, 600, project);
  window->SetChildContent(controller.view()->GetNativeWindow());
  MSG message;
  while (GetMessage(&message, nullptr, 0, 0)) { TranslateMessage(&message); DispatchMessage(&message); }
  return EXIT_SUCCESS;
}
