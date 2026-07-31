#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <process.h>

#include <cstdlib>
#include <iostream>
#include <vector>

int wmain(int argc, wchar_t* argv[]) {
  size_t script_length = 0;
  _wgetenv_s(&script_length, nullptr, 0, L"WPHX_WINDOWS_FAKE_HAXE_SCRIPT");
  if (script_length == 0) {
    std::wcerr << L"WPHX_WINDOWS_FAKE_HAXE_SCRIPT is required" << std::endl;
    return 64;
  }
  std::vector<wchar_t> script_storage(script_length);
  _wgetenv_s(&script_length, script_storage.data(), script_storage.size(),
             L"WPHX_WINDOWS_FAKE_HAXE_SCRIPT");

  std::vector<const wchar_t*> arguments;
  arguments.reserve(static_cast<size_t>(argc) + 2);
  arguments.push_back(L"node.exe");
  arguments.push_back(script_storage.data());
  for (int index = 1; index < argc; ++index) {
    arguments.push_back(argv[index]);
  }
  arguments.push_back(nullptr);

  const intptr_t result =
      _wspawnvp(_P_WAIT, L"node.exe", arguments.data());
  if (result == -1) {
    std::wcerr << L"could not start exact Node fake Haxe fixture: "
               << GetLastError() << std::endl;
    return 69;
  }
  return static_cast<int>(result);
}
