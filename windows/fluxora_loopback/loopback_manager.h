// Fluxora Loopback Manager
// Copyright (C) 2026 Fluxora Contributors
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <https://www.gnu.org/licenses/>.
//
// Implemented by the Fluxora project against the public Windows Network
// Isolation API. It contains no third-party code.

#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

// Provides INET_FIREWALL_APP_CONTAINER, NETISO_FLAG and the
// NetworkIsolation* declarations used below. Must come after <windows.h>.
#include <netfw.h>

#include <string>
#include <vector>

namespace fluxora::loopback {

/// One AppContainer reported by `NetworkIsolationEnumAppContainers`.
struct AppContainerEntry {
  std::wstring displayName;
  std::wstring appContainerName;
  std::wstring appContainerSid;
  /// SID as reported by the enumeration. Owned by the enumeration buffer and
  /// only valid while the owning `Enumeration` is alive.
  PSID sid = nullptr;
};

/// Owns the buffer returned by `NetworkIsolationEnumAppContainers` and releases
/// it with `NetworkIsolationFreeAppContainers` in its destructor.
class Enumeration {
 public:
  Enumeration() = default;
  ~Enumeration();
  Enumeration(const Enumeration&) = delete;
  Enumeration& operator=(const Enumeration&) = delete;

  /// Enumerates AppContainers. Returns false and fills `error` on failure.
  bool Load(std::wstring& error);

  const std::vector<AppContainerEntry>& entries() const { return entries_; }

 private:
  PINET_FIREWALL_APP_CONTAINER buffer_ = nullptr;
  std::vector<AppContainerEntry> entries_;
};

/// Owns the SID array returned by `NetworkIsolationGetAppContainerConfig` and
/// releases it with `LocalFree` in its destructor.
class ExemptionConfig {
 public:
  ExemptionConfig() = default;
  ~ExemptionConfig();
  ExemptionConfig(const ExemptionConfig&) = delete;
  ExemptionConfig& operator=(const ExemptionConfig&) = delete;

  /// Reads the current loopback exemption configuration.
  bool Load(std::wstring& error);

  /// SID strings currently exempted (one per entry).
  const std::vector<std::wstring>& sidStrings() const { return sidStrings_; }
  /// Raw array, usable directly as the argument of SetAppContainerConfig.
  PSID_AND_ATTRIBUTES raw() const { return sids_; }
  DWORD count() const { return count_; }

 private:
  PSID_AND_ATTRIBUTES sids_ = nullptr;
  DWORD count_ = 0;
  std::vector<std::wstring> sidStrings_;
};

/// True when FirewallAPI.dll and all four Network Isolation entry points loaded.
bool ApiAvailable();
/// Human readable reason when `ApiAvailable()` is false.
const std::wstring& ApiError();

/// Converts a SID to its string form (`S-1-15-2-...`). Returns false on failure.
bool SidToString(PSID sid, std::wstring& out);

/// Parses a SID string into a SID allocated with `LocalAlloc`. The caller frees
/// it with `LocalFree`. Returns false when the string is not a valid SID.
bool SidFromString(const std::wstring& text, PSID* out, std::wstring& error);

/// Writes `sids` as the complete loopback exemption set. Requires elevation.
bool SetExemptions(const std::vector<PSID>& sids, std::wstring& error);

/// Adds `sid` to the exemption set. Idempotent: succeeds without writing when
/// the SID is already exempt. Requires elevation.
bool EnableSid(PSID sid, std::wstring& error);

/// Removes `sid` from the exemption set. Idempotent: succeeds without writing
/// when the SID is not exempt. Requires elevation.
bool DisableSid(PSID sid, std::wstring& error);

/// Finds an AppContainer by SID string. Returns nullptr when not found.
const AppContainerEntry* FindBySid(const Enumeration& enumeration,
                                   const std::wstring& sid);

/// Builds a readable Win32 error suffix such as ` (Win32 error 5: Access is denied.)`.
std::wstring Win32ErrorText(DWORD code);

}  // namespace fluxora::loopback
