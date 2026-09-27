// Fluxora Loopback Manager
// Copyright (C) 2026 Fluxora Contributors
//
// GPL-3.0-or-later. See the LICENSE file at the repository root.
//
// Implemented by the Fluxora project against the public Windows Network
// Isolation API. It contains no third-party code.

#include "loopback_manager.h"

#include <commctrl.h>
#include <fcntl.h>
#include <io.h>
#include <shellapi.h>

#include <iostream>
#include <string>
#include <vector>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "advapi32.lib")

using fluxora::loopback::AppContainerEntry;
using fluxora::loopback::Enumeration;
using fluxora::loopback::ExemptionConfig;

namespace {

constexpr wchar_t kTitle[] = L"Fluxora Loopback Manager";

// Control identifiers
constexpr int kIdList = 1001;
constexpr int kIdRefresh = 1002;
constexpr int kIdSelectAll = 1003;
constexpr int kIdApply = 1004;
constexpr int kIdClose = 1005;
constexpr int kIdStatus = 1006;

HWND g_list = nullptr;
HWND g_status = nullptr;

// ---------------------------------------------------------------------------
// Console plumbing: the binary is a GUI-subsystem executable, so CLI commands
// attach to the invoking console instead of opening a new window.
//
// When stdout was already redirected (a pipe or a file) the CRT already holds a
// usable handle - rebinding it to CONOUT$ would send the text to the console
// instead of the caller's pipe, which would make --status unusable from scripts.
// ---------------------------------------------------------------------------
void AttachParentConsole() {
  const HANDLE existing = ::GetStdHandle(STD_OUTPUT_HANDLE);
  const bool hasUsableStdout =
      existing != nullptr && existing != INVALID_HANDLE_VALUE;

  if (!hasUsableStdout) {
    if (::AttachConsole(ATTACH_PARENT_PROCESS) == FALSE) {
      if (::AllocConsole() == FALSE) return;
    }
    FILE* stream = nullptr;
    freopen_s(&stream, "CONOUT$", "w", stdout);
    freopen_s(&stream, "CONOUT$", "w", stderr);
    freopen_s(&stream, "CONIN$", "r", stdin);
  }

  _setmode(_fileno(stdout), _O_U16TEXT);
  _setmode(_fileno(stderr), _O_U16TEXT);
}

void Out(const std::wstring& text) {
  std::wcout << text << L"\n";
}

void ShowUsage() {
  Out(L"Fluxora Loopback Manager");
  Out(L"");
  Out(L"Usage:");
  Out(L"  FluxoraLoopbackManager                 Launch the graphical manager");
  Out(L"  FluxoraLoopbackManager --status        Print the current exemptions");
  Out(L"  FluxoraLoopbackManager --enable <SID>  Add a SID to the exemptions");
  Out(L"  FluxoraLoopbackManager --disable <SID> Remove a SID from the exemptions");
  Out(L"  FluxoraLoopbackManager --help          Show this message");
  Out(L"");
  Out(L"Arguments are AppContainer SIDs (S-1-15-2-...), not package family");
  Out(L"names. Use --status to list the SIDs available on this machine.");
  Out(L"");
  Out(L"Writing exemptions (--enable / --disable) and applying changes in the");
  Out(L"graphical manager require administrator privileges.");
}

void SetStatus(const std::wstring& text) {
  if (g_status != nullptr) ::SetWindowTextW(g_status, text.c_str());
}

// ---------------------------------------------------------------------------
// GUI
// ---------------------------------------------------------------------------
void AddColumn(HWND list, int index, const wchar_t* title, int width) {
  LVCOLUMNW column{};
  column.mask = LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM;
  column.pszText = const_cast<wchar_t*>(title);
  column.cx = width;
  column.iSubItem = index;
  ListView_InsertColumn(list, index, &column);
}

void RefreshList() {
  if (g_list == nullptr) return;
  ListView_DeleteAllItems(g_list);
  SetStatus(L"Reading AppContainers...");

  Enumeration enumeration;
  std::wstring error;
  if (!enumeration.Load(error)) {
    SetStatus(error);
    return;
  }

  ExemptionConfig config;
  if (!config.Load(error)) {
    SetStatus(error);
    return;
  }

  const std::vector<std::wstring>& exempt = config.sidStrings();
  int row = 0;
  for (const AppContainerEntry& entry : enumeration.entries()) {
    bool isExempt = false;
    for (const std::wstring& sid : exempt) {
      if (sid == entry.appContainerSid) {
        isExempt = true;
        break;
      }
    }

    LVITEMW item{};
    item.mask = LVIF_TEXT;
    item.iItem = row;
    item.iSubItem = 0;
    const std::wstring label =
        entry.displayName.empty() ? entry.appContainerName : entry.displayName;
    item.pszText = const_cast<wchar_t*>(label.c_str());
    const int index = ListView_InsertItem(g_list, &item);
    if (index < 0) break;

    ListView_SetItemText(g_list, index, 1,
                         const_cast<wchar_t*>(entry.appContainerSid.c_str()));
    ListView_SetItemText(g_list, index, 2,
                         const_cast<wchar_t*>(isExempt ? L"Exempt" : L"Blocked"));
    ListView_SetCheckState(g_list, index, isExempt ? TRUE : FALSE);
    ++row;
  }

  SetStatus(std::to_wstring(row) + L" AppContainer(s); " +
            std::to_wstring(exempt.size()) + L" exempt.");
}

void ApplySelection() {
  if (g_list == nullptr) return;
  const int count = ListView_GetItemCount(g_list);

  Enumeration enumeration;
  std::wstring error;
  if (!enumeration.Load(error)) {
    SetStatus(error);
    return;
  }

  // Map each row's SID string back to a SID owned by the enumeration buffer.
  std::vector<PSID> selected;
  for (int i = 0; i < count; ++i) {
    if (ListView_GetCheckState(g_list, i) == FALSE) continue;
    wchar_t buffer[256] = {};
    ListView_GetItemText(g_list, i, 1, buffer, ARRAYSIZE(buffer));
    const AppContainerEntry* entry = fluxora::loopback::FindBySid(enumeration, buffer);
    if (entry != nullptr && entry->sid != nullptr) selected.push_back(entry->sid);
  }

  if (!fluxora::loopback::SetExemptions(selected, error)) {
    ::MessageBoxW(nullptr, error.c_str(), kTitle, MB_ICONERROR | MB_OK);
    SetStatus(error);
    return;
  }
  SetStatus(L"Applied " + std::to_wstring(selected.size()) + L" exemption(s).");
  RefreshList();
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam,
                         LPARAM lparam) {
  switch (message) {
    case WM_CREATE: {
      g_list = ::CreateWindowExW(
          WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"",
          WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SHOWSELALWAYS,
          0, 0, 0, 0, hwnd, reinterpret_cast<HMENU>(kIdList), nullptr, nullptr);
      ListView_SetExtendedListViewStyle(
          g_list, LVS_EX_CHECKBOXES | LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES);
      AddColumn(g_list, 0, L"Application", 280);
      AddColumn(g_list, 1, L"SID", 300);
      AddColumn(g_list, 2, L"Loopback", 90);

      const DWORD buttonStyle = WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON;
      ::CreateWindowExW(0, L"BUTTON", L"Refresh", buttonStyle, 0, 0, 0, 0, hwnd,
                        reinterpret_cast<HMENU>(kIdRefresh), nullptr, nullptr);
      ::CreateWindowExW(0, L"BUTTON", L"Select All", buttonStyle, 0, 0, 0, 0,
                        hwnd, reinterpret_cast<HMENU>(kIdSelectAll), nullptr,
                        nullptr);
      ::CreateWindowExW(0, L"BUTTON", L"Apply", buttonStyle, 0, 0, 0, 0, hwnd,
                        reinterpret_cast<HMENU>(kIdApply), nullptr, nullptr);
      ::CreateWindowExW(0, L"BUTTON", L"Close", buttonStyle, 0, 0, 0, 0, hwnd,
                        reinterpret_cast<HMENU>(kIdClose), nullptr, nullptr);
      g_status = ::CreateWindowExW(0, L"STATIC", L"", WS_CHILD | WS_VISIBLE,
                                   0, 0, 0, 0, hwnd,
                                   reinterpret_cast<HMENU>(kIdStatus), nullptr,
                                   nullptr);
      RefreshList();
      return 0;
    }

    case WM_SIZE: {
      const int width = LOWORD(lparam);
      const int height = HIWORD(lparam);
      const int padding = 10;
      const int buttonHeight = 30;
      const int buttonWidth = 100;
      const int statusHeight = 22;
      const int listHeight = height - padding * 3 - buttonHeight - statusHeight;

      ::MoveWindow(g_list, padding, padding,
                   width - padding * 2 > 0 ? width - padding * 2 : 0,
                   listHeight > 0 ? listHeight : 0, TRUE);
      int x = padding;
      const int y = padding * 2 + (listHeight > 0 ? listHeight : 0);
      const int ids[] = {kIdRefresh, kIdSelectAll, kIdApply, kIdClose};
      const wchar_t* labels[] = {L"Refresh", L"Select All", L"Apply", L"Close"};
      (void)labels;
      for (int id : ids) {
        HWND button = ::GetDlgItem(hwnd, id);
        ::MoveWindow(button, x, y, buttonWidth, buttonHeight, TRUE);
        x += buttonWidth + padding;
      }
      ::MoveWindow(g_status, padding, y + buttonHeight + padding / 2,
                   width - padding * 2 > 0 ? width - padding * 2 : 0,
                   statusHeight, TRUE);
      return 0;
    }

    case WM_COMMAND: {
      switch (LOWORD(wparam)) {
        case kIdRefresh:
          RefreshList();
          return 0;
        case kIdSelectAll: {
          const int count = ListView_GetItemCount(g_list);
          const BOOL state = ListView_GetCheckState(g_list, 0) == FALSE;
          for (int i = 0; i < count; ++i) {
            ListView_SetCheckState(g_list, i, state);
          }
          return 0;
        }
        case kIdApply:
          ApplySelection();
          return 0;
        case kIdClose:
          ::DestroyWindow(hwnd);
          return 0;
        default:
          break;
      }
      break;
    }

    case WM_CLOSE:
      ::DestroyWindow(hwnd);
      return 0;

    case WM_DESTROY:
      ::PostQuitMessage(0);
      return 0;

    default:
      break;
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

int RunGui() {
  INITCOMMONCONTROLSEX controls{};
  controls.dwSize = sizeof(controls);
  controls.dwICC = ICC_LISTVIEW_CLASSES;
  ::InitCommonControlsEx(&controls);

  const HINSTANCE instance = ::GetModuleHandleW(nullptr);
  WNDCLASSEXW windowClass{};
  windowClass.cbSize = sizeof(windowClass);
  windowClass.lpfnWndProc = WndProc;
  windowClass.hInstance = instance;
  windowClass.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
  windowClass.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  windowClass.lpszClassName = L"FluxoraLoopbackWindow";
  if (::RegisterClassExW(&windowClass) == 0) return 1;

  HWND window = ::CreateWindowExW(
      0, windowClass.lpszClassName, kTitle, WS_OVERLAPPEDWINDOW, CW_USEDEFAULT,
      CW_USEDEFAULT, 760, 520, nullptr, nullptr, instance, nullptr);
  if (window == nullptr) return 1;

  ::ShowWindow(window, SW_SHOW);
  ::UpdateWindow(window);

  MSG message{};
  while (::GetMessageW(&message, nullptr, 0, 0) > 0) {
    if (::IsDialogMessageW(window, &message)) continue;
    ::TranslateMessage(&message);
    ::DispatchMessageW(&message);
  }
  return 0;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
int RunStatus() {
  ExemptionConfig config;
  std::wstring error;
  if (!config.Load(error)) {
    Out(L"Error: " + error);
    return 2;
  }

  if (config.sidStrings().empty()) {
    Out(L"(no loopback exemptions are currently configured)");
    return 0;
  }

  Enumeration enumeration;
  const bool haveEnumeration = enumeration.Load(error);
  for (const std::wstring& sid : config.sidStrings()) {
    std::wstring label;
    if (haveEnumeration) {
      const AppContainerEntry* entry = fluxora::loopback::FindBySid(enumeration, sid);
      if (entry != nullptr) {
        label = entry->displayName.empty() ? entry->appContainerName
                                           : entry->displayName;
      }
    }
    Out(label.empty() ? sid : (sid + L"\t" + label));
  }
  return 0;
}

int RunChange(const std::wstring& sidText, bool enable) {
  PSID sid = nullptr;
  std::wstring error;
  if (!fluxora::loopback::SidFromString(sidText, &sid, error)) {
    Out(L"Error: " + error);
    Out(L"Arguments are AppContainer SIDs (S-1-15-2-...), not package family names.");
    return 5;
  }

  const bool ok = enable ? fluxora::loopback::EnableSid(sid, error)
                         : fluxora::loopback::DisableSid(sid, error);
  ::LocalFree(sid);

  if (!ok) {
    Out(L"Error: " + error);
    if (error.find(L"access denied") != std::wstring::npos ||
        error.find(L"Administrator") != std::wstring::npos) {
      return 3;
    }
    return 1;
  }
  Out(enable ? L"SID enabled." : L"SID disabled.");
  return 0;
}

}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, LPWSTR, int) {
  int argc = 0;
  LPWSTR* argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) return 1;

  int exitCode = 0;
  if (argc <= 1) {
    exitCode = RunGui();
  } else {
    AttachParentConsole();
    const std::wstring command = argv[1];
    if (command == L"--help" || command == L"-h" || command == L"/?") {
      ShowUsage();
    } else if (command == L"--status") {
      exitCode = RunStatus();
    } else if (command == L"--enable" || command == L"--disable") {
      if (argc < 3) {
        Out(L"Error: " + command + L" requires a SID argument.");
        ShowUsage();
        exitCode = 5;
      } else {
        exitCode = RunChange(argv[2], command == L"--enable");
      }
    } else {
      Out(L"Error: unknown argument \"" + command + L"\".");
      ShowUsage();
      exitCode = 5;
    }
  }

  ::LocalFree(argv);
  return exitCode;
}
