#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#pragma comment(lib, "user32.lib")

#include <atomic>
#include <chrono>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr DWORD kJobExitCode = 70;
constexpr DWORD kWaitForEmptyMilliseconds = 5000;
constexpr DWORD kPollMilliseconds = 10;

class UniqueHandle {
 public:
  UniqueHandle() = default;
  explicit UniqueHandle(HANDLE value) : value_(value) {}
  UniqueHandle(const UniqueHandle&) = delete;
  UniqueHandle& operator=(const UniqueHandle&) = delete;

  UniqueHandle(UniqueHandle&& other) noexcept : value_(other.release()) {}

  UniqueHandle& operator=(UniqueHandle&& other) noexcept {
    if (this != &other) {
      reset(other.release());
    }
    return *this;
  }

  ~UniqueHandle() {
    reset();
  }

  HANDLE get() const {
    return value_;
  }

  HANDLE release() {
    HANDLE result = value_;
    value_ = nullptr;
    return result;
  }

  void reset(HANDLE value = nullptr) {
    if (value_ != nullptr && value_ != INVALID_HANDLE_VALUE) {
      CloseHandle(value_);
    }
    value_ = value;
  }

  explicit operator bool() const {
    return value_ != nullptr && value_ != INVALID_HANDLE_VALUE;
  }

 private:
  HANDLE value_ = nullptr;
};

class AttributeList {
 public:
  AttributeList() {
    SIZE_T bytes = 0;
    InitializeProcThreadAttributeList(nullptr, 1, 0, &bytes);
    storage_.resize(bytes);
    value_ = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(storage_.data());
    if (!InitializeProcThreadAttributeList(value_, 1, 0, &bytes)) {
      value_ = nullptr;
    }
  }

  AttributeList(const AttributeList&) = delete;
  AttributeList& operator=(const AttributeList&) = delete;

  ~AttributeList() {
    if (value_ != nullptr) {
      DeleteProcThreadAttributeList(value_);
    }
  }

  LPPROC_THREAD_ATTRIBUTE_LIST get() const {
    return value_;
  }

  explicit operator bool() const {
    return value_ != nullptr;
  }

 private:
  std::vector<unsigned char> storage_;
  LPPROC_THREAD_ATTRIBUTE_LIST value_ = nullptr;
};

std::wstring WindowsError(const wchar_t* operation) {
  const DWORD code = GetLastError();
  return std::wstring(operation) + L" failed with Win32 error " +
         std::to_wstring(code);
}

void Report(const std::wstring& message) {
  std::wcerr << L"wphx-windows-service-host: " << message << std::endl;
}

bool HasDirectoryComponent(const std::wstring& value) {
  return value.find(L'\\') != std::wstring::npos ||
         value.find(L'/') != std::wstring::npos ||
         (value.size() >= 2 && value[1] == L':');
}

std::wstring FullPath(const std::wstring& value) {
  const DWORD required = GetFullPathNameW(value.c_str(), 0, nullptr, nullptr);
  if (required == 0) {
    return L"";
  }
  std::vector<wchar_t> buffer(required);
  const DWORD written =
      GetFullPathNameW(value.c_str(), required, buffer.data(), nullptr);
  if (written == 0 || written >= required) {
    return L"";
  }
  return std::wstring(buffer.data(), written);
}

std::wstring SearchExecutable(const std::wstring& executable) {
  if (HasDirectoryComponent(executable)) {
    const std::wstring resolved = FullPath(executable);
    if (resolved.empty()) {
      return L"";
    }
    const DWORD attributes = GetFileAttributesW(resolved.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES ||
        (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
      SetLastError(ERROR_FILE_NOT_FOUND);
      return L"";
    }
    return resolved;
  }

  const bool has_extension =
      executable.find_last_of(L'.') != std::wstring::npos;
  const wchar_t* extension = has_extension ? nullptr : L".exe";
  const DWORD required =
      SearchPathW(nullptr, executable.c_str(), extension, 0, nullptr, nullptr);
  if (required == 0) {
    return L"";
  }
  std::vector<wchar_t> buffer(required + 1);
  const DWORD written = SearchPathW(nullptr, executable.c_str(), extension,
                                    static_cast<DWORD>(buffer.size()),
                                    buffer.data(), nullptr);
  if (written == 0 || written >= static_cast<DWORD>(buffer.size())) {
    return L"";
  }
  return std::wstring(buffer.data(), written);
}

std::wstring QuoteArgument(const std::wstring& argument) {
  if (!argument.empty() &&
      argument.find_first_of(L" \t\n\v\"") == std::wstring::npos) {
    return argument;
  }

  std::wstring result = L"\"";
  size_t backslashes = 0;
  for (const wchar_t character : argument) {
    if (character == L'\\') {
      ++backslashes;
      continue;
    }
    if (character == L'\"') {
      result.append(backslashes * 2 + 1, L'\\');
      result.push_back(L'\"');
      backslashes = 0;
      continue;
    }
    result.append(backslashes, L'\\');
    backslashes = 0;
    result.push_back(character);
  }
  result.append(backslashes * 2, L'\\');
  result.push_back(L'\"');
  return result;
}

std::wstring CommandLine(const std::wstring& executable, int argc,
                         wchar_t* argv[]) {
  std::wstring result = QuoteArgument(executable);
  for (int index = 2; index < argc; ++index) {
    result.push_back(L' ');
    result.append(QuoteArgument(argv[index]));
  }
  return result;
}

UniqueHandle DuplicateForInheritance(HANDLE source) {
  if (source == nullptr || source == INVALID_HANDLE_VALUE) {
    SetLastError(ERROR_INVALID_HANDLE);
    return UniqueHandle();
  }
  HANDLE duplicate = nullptr;
  if (!DuplicateHandle(GetCurrentProcess(), source, GetCurrentProcess(),
                       &duplicate, 0, TRUE, DUPLICATE_SAME_ACCESS)) {
    return UniqueHandle();
  }
  return UniqueHandle(duplicate);
}

BOOL WINAPI IgnoreOwnedConsoleSignal(DWORD signal) {
  if (signal == CTRL_C_EVENT || signal == CTRL_BREAK_EVENT) {
    return TRUE;
  }
  return FALSE;
}

bool AllocatePrivateConsole() {
  // Node/libuv starts detached Windows children with DETACHED_PROCESS, which
  // deliberately provides no console. Allocate one before starting the
  // payload so this live helper can be the isolated CTRL+BREAK group owner.
  if (!AllocConsole()) {
    return false;
  }
  const HWND console_window = GetConsoleWindow();
  if (console_window != nullptr) {
    ShowWindow(console_window, SW_HIDE);
  }
  return true;
}

bool WaitForEmptyJob(HANDLE job) {
  const auto deadline = std::chrono::steady_clock::now() +
                        std::chrono::milliseconds(kWaitForEmptyMilliseconds);
  while (std::chrono::steady_clock::now() < deadline) {
    JOBOBJECT_BASIC_ACCOUNTING_INFORMATION accounting{};
    if (!QueryInformationJobObject(job, JobObjectBasicAccountingInformation,
                                   &accounting, sizeof(accounting), nullptr)) {
      return false;
    }
    if (accounting.ActiveProcesses == 0) {
      return true;
    }
    Sleep(kPollMilliseconds);
  }
  SetLastError(WAIT_TIMEOUT);
  return false;
}

int Run(int argc, wchar_t* argv[]) {
  if (argc < 2) {
    Report(L"usage: wphx-windows-service-host.exe <executable> [arguments...]");
    return 64;
  }
  if (!AllocatePrivateConsole()) {
    Report(WindowsError(L"AllocConsole"));
    return 70;
  }
  if (!SetConsoleCtrlHandler(IgnoreOwnedConsoleSignal, TRUE)) {
    Report(WindowsError(L"SetConsoleCtrlHandler"));
    return 70;
  }

  const std::wstring executable = SearchExecutable(argv[1]);
  if (executable.empty()) {
    Report(WindowsError(L"resolve executable"));
    return 69;
  }

  // The process owns this handle until exit. Deliberately keeping the last Job
  // handle live makes process exit itself a fail-safe descendant cleanup path.
  const HANDLE job = CreateJobObjectW(nullptr, nullptr);
  if (job == nullptr) {
    Report(WindowsError(L"CreateJobObjectW"));
    return 70;
  }

  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits,
                               sizeof(limits))) {
    Report(WindowsError(L"SetInformationJobObject"));
    CloseHandle(job);
    return 70;
  }

  SECURITY_ATTRIBUTES null_security{};
  null_security.nLength = sizeof(null_security);
  null_security.bInheritHandle = TRUE;
  UniqueHandle null_input(CreateFileW(
      L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, &null_security,
      OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
  UniqueHandle standard_output =
      DuplicateForInheritance(GetStdHandle(STD_OUTPUT_HANDLE));
  UniqueHandle standard_error =
      DuplicateForInheritance(GetStdHandle(STD_ERROR_HANDLE));
  if (!null_input || !standard_output || !standard_error) {
    Report(WindowsError(L"prepare inherited standard handles"));
    CloseHandle(job);
    return 70;
  }

  HANDLE inherited_handles[] = {null_input.get(), standard_output.get(),
                                standard_error.get()};
  AttributeList attributes;
  if (!attributes) {
    Report(WindowsError(L"InitializeProcThreadAttributeList"));
    CloseHandle(job);
    return 70;
  }
  if (!UpdateProcThreadAttribute(
          attributes.get(), 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
          inherited_handles, sizeof(inherited_handles), nullptr, nullptr)) {
    Report(WindowsError(L"UpdateProcThreadAttribute"));
    CloseHandle(job);
    return 70;
  }

  STARTUPINFOEXW startup{};
  startup.StartupInfo.cb = sizeof(startup);
  startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  startup.StartupInfo.hStdInput = null_input.get();
  startup.StartupInfo.hStdOutput = standard_output.get();
  startup.StartupInfo.hStdError = standard_error.get();
  startup.lpAttributeList = attributes.get();

  std::wstring command_line = CommandLine(executable, argc, argv);
  std::vector<wchar_t> mutable_command(command_line.begin(),
                                       command_line.end());
  mutable_command.push_back(L'\0');

  PROCESS_INFORMATION process{};
  const DWORD creation_flags =
      CREATE_SUSPENDED | CREATE_UNICODE_ENVIRONMENT |
      EXTENDED_STARTUPINFO_PRESENT;
  if (!CreateProcessW(executable.c_str(), mutable_command.data(), nullptr,
                      nullptr, TRUE, creation_flags, nullptr, nullptr,
                      &startup.StartupInfo, &process)) {
    Report(WindowsError(L"CreateProcessW"));
    CloseHandle(job);
    return 69;
  }

  UniqueHandle process_handle(process.hProcess);
  UniqueHandle thread_handle(process.hThread);
  if (!AssignProcessToJobObject(job, process_handle.get())) {
    const std::wstring error = WindowsError(L"AssignProcessToJobObject");
    TerminateProcess(process_handle.get(), kJobExitCode);
    WaitForSingleObject(process_handle.get(), kWaitForEmptyMilliseconds);
    Report(error);
    CloseHandle(job);
    return 70;
  }
  if (ResumeThread(thread_handle.get()) == static_cast<DWORD>(-1)) {
    const std::wstring error = WindowsError(L"ResumeThread");
    TerminateJobObject(job, kJobExitCode);
    WaitForEmptyJob(job);
    Report(error);
    CloseHandle(job);
    return 70;
  }
  thread_handle.reset();

  std::atomic<bool> forced{false};
  std::thread([job, &forced]() {
    std::string command;
    while (std::getline(std::cin, command)) {
      if (command == "graceful") {
        GenerateConsoleCtrlEvent(CTRL_BREAK_EVENT, GetCurrentProcessId());
      } else if (command == "force") {
        forced.store(true);
        TerminateJobObject(job, kJobExitCode);
        return;
      }
    }
    forced.store(true);
    TerminateJobObject(job, kJobExitCode);
  }).detach();

  const DWORD wait = WaitForSingleObject(process_handle.get(), INFINITE);
  DWORD payload_exit = kJobExitCode;
  if (wait != WAIT_OBJECT_0 ||
      !GetExitCodeProcess(process_handle.get(), &payload_exit)) {
    Report(WindowsError(L"wait for payload"));
  }

  // The payload may leave workers behind. A service is not finished until its
  // complete Job is empty, whether the root exited normally or was forced.
  if (!forced.load()) {
    TerminateJobObject(job, kJobExitCode);
  }
  if (!WaitForEmptyJob(job)) {
    Report(WindowsError(L"wait for empty Job Object"));
    ExitProcess(70);
  }

  // Do not close the last Job handle while the detached control thread can
  // still observe its private stdin. Process exit closes it atomically.
  ExitProcess(payload_exit);
}

}  // namespace

int wmain(int argc, wchar_t* argv[]) {
  return Run(argc, argv);
}
