// Fluxora Loopback Manager
// Copyright (C) 2026 Fluxora Contributors
//
// GPL-3.0-or-later. See the LICENSE file at the repository root.
//
// Implemented by the Fluxora project against the public Windows Network
// Isolation API. It contains no third-party code.

#include "loopback_manager.h"

#include <sddl.h>  // ConvertSidToStringSidW / ConvertStringSidToSidW

#include <string>
#include <vector>

namespace fluxora::loopback {
namespace {

// ---------------------------------------------------------------------------
// Runtime binding of FirewallAPI.dll.
//
// The Windows SDK ships netfw.h (declarations) but no FirewallAPI.lib import
// library, so the four entry points are resolved at run time. This also gives
// us a clean capability check: if the DLL or any entry point is missing we
// report it instead of failing to link or crashing.
// ---------------------------------------------------------------------------

using FnEnumAppContainers = DWORD(WINAPI*)(DWORD, DWORD*,
                                           PINET_FIREWALL_APP_CONTAINER*);
using FnFreeAppContainers = DWORD(WINAPI*)(PINET_FIREWALL_APP_CONTAINER);
using FnGetAppContainerConfig = DWORD(WINAPI*)(DWORD*, PSID_AND_ATTRIBUTES*);
using FnSetAppContainerConfig = DWORD(WINAPI*)(DWORD, PSID_AND_ATTRIBUTES);

struct Api {
  HMODULE module = nullptr;
  FnEnumAppContainers enumAppContainers = nullptr;
  FnFreeAppContainers freeAppContainers = nullptr;
  FnGetAppContainerConfig getAppContainerConfig = nullptr;
  FnSetAppContainerConfig setAppContainerConfig = nullptr;
  std::wstring error;
  bool ok = false;
};

Api& GetApi() {
  static Api api = [] {
    Api result;
    result.module = ::LoadLibraryW(L"FirewallAPI.dll");
    if (result.module == nullptr) {
      result.error =
          L"Required Windows Network Isolation API is unavailable: could not "
          L"load FirewallAPI.dll." +
          Win32ErrorText(::GetLastError());
      return result;
    }

    result.enumAppContainers =
        reinterpret_cast<FnEnumAppContainers>(reinterpret_cast<void*>(
            ::GetProcAddress(result.module, "NetworkIsolationEnumAppContainers")));
    result.freeAppContainers =
        reinterpret_cast<FnFreeAppContainers>(reinterpret_cast<void*>(
            ::GetProcAddress(result.module, "NetworkIsolationFreeAppContainers")));
    result.getAppContainerConfig =
        reinterpret_cast<FnGetAppContainerConfig>(reinterpret_cast<void*>(
            ::GetProcAddress(result.module,
                             "NetworkIsolationGetAppContainerConfig")));
    result.setAppContainerConfig =
        reinterpret_cast<FnSetAppContainerConfig>(reinterpret_cast<void*>(
            ::GetProcAddress(result.module,
                             "NetworkIsolationSetAppContainerConfig")));

    const wchar_t* missing = nullptr;
    if (result.enumAppContainers == nullptr) {
      missing = L"NetworkIsolationEnumAppContainers";
    } else if (result.freeAppContainers == nullptr) {
      missing = L"NetworkIsolationFreeAppContainers";
    } else if (result.getAppContainerConfig == nullptr) {
      missing = L"NetworkIsolationGetAppContainerConfig";
    } else if (result.setAppContainerConfig == nullptr) {
      missing = L"NetworkIsolationSetAppContainerConfig";
    }

    if (missing != nullptr) {
      result.error =
          L"Required Windows Network Isolation API is unavailable: " +
          std::wstring(missing) + L" was not exported by FirewallAPI.dll.";
      return result;
    }

    result.ok = true;
    return result;
  }();
  return api;
}

/// Releases the FirewallAPI.dll reference at process exit.
struct ApiUnloader {
  ~ApiUnloader() {
    Api& api = GetApi();
    if (api.module != nullptr) {
      ::FreeLibrary(api.module);
      api.module = nullptr;
    }
  }
};
ApiUnloader g_unloader;

}  // namespace

// ---------------------------------------------------------------------------
// Error text
// ---------------------------------------------------------------------------

std::wstring Win32ErrorText(DWORD code) {
  if (code == ERROR_SUCCESS) return L"";

  LPWSTR buffer = nullptr;
  const DWORD length = ::FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      reinterpret_cast<LPWSTR>(&buffer), 0, nullptr);

  std::wstring text;
  if (length != 0 && buffer != nullptr) {
    text.assign(buffer, length);
    while (!text.empty() && (text.back() == L'\r' || text.back() == L'\n' ||
                             text.back() == L' ')) {
      text.pop_back();
    }
  } else {
    text = L"unknown error";
  }
  if (buffer != nullptr) ::LocalFree(buffer);

  return L" (Win32 error " + std::to_wstring(code) + L": " + text + L")";
}

bool ApiAvailable() { return GetApi().ok; }
const std::wstring& ApiError() { return GetApi().error; }

// ---------------------------------------------------------------------------
// SID helpers
// ---------------------------------------------------------------------------

bool SidToString(PSID sid, std::wstring& out) {
  if (sid == nullptr || !::IsValidSid(sid)) return false;
  LPWSTR text = nullptr;
  if (!::ConvertSidToStringSidW(sid, &text)) return false;
  out.assign(text);
  ::LocalFree(text);
  return true;
}

bool SidFromString(const std::wstring& text, PSID* out, std::wstring& error) {
  *out = nullptr;
  if (text.empty()) {
    error = L"empty SID";
    return false;
  }
  PSID sid = nullptr;
  if (!::ConvertStringSidToSidW(text.c_str(), &sid)) {
    error = L"\"" + text + L"\" is not a valid SID string" +
            Win32ErrorText(::GetLastError());
    return false;
  }
  if (!::IsValidSid(sid)) {
    ::LocalFree(sid);
    error = L"\"" + text + L"\" parsed but is not a valid SID";
    return false;
  }
  *out = sid;
  return true;
}

// ---------------------------------------------------------------------------
// Enumeration
// ---------------------------------------------------------------------------

Enumeration::~Enumeration() {
  if (buffer_ != nullptr) {
    // The buffer must be released through the owning API, never with free().
    GetApi().freeAppContainers(buffer_);
    buffer_ = nullptr;
  }
}

bool Enumeration::Load(std::wstring& error) {
  entries_.clear();
  if (buffer_ != nullptr) {
    GetApi().freeAppContainers(buffer_);
    buffer_ = nullptr;
  }

  if (!ApiAvailable()) {
    error = ApiError();
    return false;
  }

  DWORD count = 0;
  PINET_FIREWALL_APP_CONTAINER buffer = nullptr;
  const DWORD result =
      GetApi().enumAppContainers(0, &count, &buffer);
  if (result != ERROR_SUCCESS) {
    error = L"failed to enumerate AppContainers" + Win32ErrorText(result);
    return false;
  }

  buffer_ = buffer;
  entries_.reserve(count);
  for (DWORD i = 0; i < count; ++i) {
    const INET_FIREWALL_APP_CONTAINER& item = buffer_[i];
    AppContainerEntry entry;
    if (item.displayName != nullptr) entry.displayName = item.displayName;
    if (item.appContainerName != nullptr) {
      entry.appContainerName = item.appContainerName;
    }
    SidToString(item.appContainerSid, entry.appContainerSid);
    entry.sid = item.appContainerSid;
    entries_.push_back(std::move(entry));
  }
  return true;
}

// ---------------------------------------------------------------------------
// Exemption configuration
// ---------------------------------------------------------------------------

ExemptionConfig::~ExemptionConfig() {
  if (sids_ != nullptr) {
    // NetworkIsolationGetAppContainerConfig allocates one block holding both
    // the array and the SIDs, released with LocalFree.
    ::LocalFree(sids_);
    sids_ = nullptr;
  }
}

bool ExemptionConfig::Load(std::wstring& error) {
  sidStrings_.clear();
  if (sids_ != nullptr) {
    ::LocalFree(sids_);
    sids_ = nullptr;
  }
  count_ = 0;

  if (!ApiAvailable()) {
    error = ApiError();
    return false;
  }

  DWORD count = 0;
  PSID_AND_ATTRIBUTES sids = nullptr;
  const DWORD result = GetApi().getAppContainerConfig(&count, &sids);
  if (result != ERROR_SUCCESS) {
    error = L"failed to read the loopback exemption configuration" +
            Win32ErrorText(result);
    return false;
  }

  sids_ = sids;
  count_ = count;
  sidStrings_.reserve(count);
  for (DWORD i = 0; i < count; ++i) {
    std::wstring text;
    if (SidToString(sids_[i].Sid, text)) sidStrings_.push_back(std::move(text));
  }
  return true;
}

bool SetExemptions(const std::vector<PSID>& sids, std::wstring& error) {
  if (!ApiAvailable()) {
    error = ApiError();
    return false;
  }

  std::vector<SID_AND_ATTRIBUTES> array;
  array.reserve(sids.size());
  for (PSID sid : sids) {
    SID_AND_ATTRIBUTES item{};
    item.Sid = sid;
    item.Attributes = SE_GROUP_ENABLED;
    array.push_back(item);
  }

  // An empty set clears every exemption; count 0 with a null array expresses
  // that. (Verified against a real configuration in the implementation report.)
  const DWORD count = static_cast<DWORD>(array.size());
  PSID_AND_ATTRIBUTES data = array.empty() ? nullptr : array.data();

  const DWORD result = GetApi().setAppContainerConfig(count, data);
  if (result == ERROR_ACCESS_DENIED) {
    error =
        L"access denied while writing the loopback exemption configuration. "
        L"Administrator privileges are required.";
    return false;
  }
  if (result != ERROR_SUCCESS) {
    error = L"failed to write the loopback exemption configuration" +
            Win32ErrorText(result);
    return false;
  }
  return true;
}

bool EnableSid(PSID sid, std::wstring& error) {
  std::wstring target;
  if (!SidToString(sid, target)) {
    error = L"the supplied SID is not valid";
    return false;
  }

  ExemptionConfig current;
  if (!current.Load(error)) return false;

  // Idempotent: already exempt -> nothing to do.
  for (const std::wstring& existing : current.sidStrings()) {
    if (existing == target) return true;
  }

  std::vector<PSID> updated;
  updated.reserve(current.count() + 1);
  for (DWORD i = 0; i < current.count(); ++i) {
    updated.push_back(current.raw()[i].Sid);
  }
  updated.push_back(sid);

  return SetExemptions(updated, error);
}

bool DisableSid(PSID sid, std::wstring& error) {
  std::wstring target;
  if (!SidToString(sid, target)) {
    error = L"the supplied SID is not valid";
    return false;
  }

  ExemptionConfig current;
  if (!current.Load(error)) return false;

  std::vector<PSID> updated;
  updated.reserve(current.count());
  bool found = false;
  for (DWORD i = 0; i < current.count(); ++i) {
    std::wstring text;
    if (!SidToString(current.raw()[i].Sid, text)) continue;
    if (text == target) {
      found = true;
      continue;  // drop it
    }
    updated.push_back(current.raw()[i].Sid);
  }

  // Idempotent: not exempt -> nothing to do.
  if (!found) return true;

  return SetExemptions(updated, error);
}

const AppContainerEntry* FindBySid(const Enumeration& enumeration,
                                   const std::wstring& sid) {
  for (const AppContainerEntry& entry : enumeration.entries()) {
    if (entry.appContainerSid == sid) return &entry;
  }
  return nullptr;
}

}  // namespace fluxora::loopback
