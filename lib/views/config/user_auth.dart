import 'dart:math';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Split a stored `user:password` entry.
///
/// Splits on the **first** colon so a password may contain colons — which is why
/// the username must not (`usernameCannotContainColon`): otherwise the boundary
/// would be ambiguous and a stored credential could be re-read as a different
/// user.
///
/// An entry with no colon is treated as a username with an empty password rather
/// than discarded, so a hand-edited config still shows up in the dialog.
({String username, String password}) parseAuthEntry(String entry) {
  final colonIdx = entry.indexOf(':');
  if (colonIdx == -1) return (username: entry, password: '');
  return (
    username: entry.substring(0, colonIdx),
    password: entry.substring(colonIdx + 1),
  );
}

/// Join a username and password into the `user:password` form mihomo expects.
///
/// Returns null for a half-filled pair: `user:` with no password would be a
/// credential that authenticates nothing, and writing it out would silently
/// create a broken login.
String? formatAuthEntry(String username, String password) {
  final u = username.trim();
  if (u.isEmpty || password.isEmpty) return null;
  return '$u:$password';
}

/// One `user:password` pair, kept as controllers so the form can validate and
/// re-render without losing what the user typed.
///
/// The password starts obscured and can be revealed per entry. Credentials are
/// only ever held here and written straight into the config — never logged.
class _UserAuthEntry {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  bool obscurePassword;

  _UserAuthEntry({required String username, required String password})
    : obscurePassword = true,
      usernameController = TextEditingController(text: username),
      passwordController = TextEditingController(text: password);

  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
  }
}

/// item 6 (Bettbox 1.19.3) — credentials for the LAN proxy.
///
/// Backs mihomo's own `authentication` / `skip-auth-prefixes`, so nothing here
/// needs core support: the list is written into the generated config.
///
/// Only meaningful while `allow-lan` is on. With it off nothing can reach the
/// proxy over the LAN in the first place, so the dialog says as much rather than
/// letting the user configure something inert.
class UserAuthDialog extends ConsumerStatefulWidget {
  const UserAuthDialog({super.key});

  @override
  ConsumerState<UserAuthDialog> createState() => _UserAuthDialogState();
}

class _UserAuthDialogState extends ConsumerState<UserAuthDialog> {
  final _formKey = GlobalKey<FormState>();
  late List<_UserAuthEntry> _entries;
  late bool _skipLocalAuth;

  @override
  void initState() {
    super.initState();
    final config = ref.read(patchClashConfigProvider);
    final auth = config.authentication;
    if (auth.isEmpty) {
      _entries = [];
    } else {
      _entries = auth.map((item) {
        final parsed = parseAuthEntry(item);
        return _UserAuthEntry(
          username: parsed.username,
          password: parsed.password,
        );
      }).toList();
    }
    _skipLocalAuth =
        auth.isEmpty || config.skipAuthPrefixes.contains('127.0.0.1/8');
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  /// Random credentials for a new entry.
  ///
  /// LAN sharing is usually switched on to let one device through, and asking
  /// the user to invent a password there produces either "123456" or a
  /// password they will have to look up later. Generated values are short
  /// enough to type on a TV remote and use an alphabet without look-alikes
  /// (0/O, 1/l/I).
  static const _alphabet =
      'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String _randomToken(int length) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }

  void _addEntry() {
    setState(() {
      _entries.add(
        _UserAuthEntry(
          username: 'fluxora_${_randomToken(4).toLowerCase()}',
          password: _randomToken(10),
        ),
      );
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index).dispose();
    });
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() != true) return;

    final validUsers = <String>[];
    for (final entry in _entries) {
      final formatted = formatAuthEntry(
        entry.usernameController.text,
        entry.passwordController.text,
      );
      if (formatted != null) validUsers.add(formatted);
    }

    final nextPrefixes = _skipLocalAuth ? defaultSkipAuthPrefixes : <String>[];

    ref
        .read(patchClashConfigProvider.notifier)
        .updateState(
          (state) => state.copyWith(
            authentication: validUsers,
            skipAuthPrefixes: nextPrefixes,
          ),
        );
    globalState.appController.updateClashConfigDebounce();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final allowLan = ref.watch(
      patchClashConfigProvider.select((state) => state.allowLan),
    );
    return CommonDialog(
      title: appLocalizations.userAuth,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(onPressed: _handleSave, child: Text(appLocalizations.save)),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Credentials do nothing while the LAN listener is off. Saying so is
            // cheaper than letting someone fill this in and wonder why it had no
            // effect.
            if (!allowLan)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  appLocalizations.allowLanDesc,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
              ),
            if (_entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(appLocalizations.addUser),
                  ),
                ),
              )
            else ...[
              for (int i = 0; i < _entries.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_entries.length > 1)
                      Text(
                        '${appLocalizations.userAuth} ${i + 1}',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _removeEntry(i),
                      tooltip: appLocalizations.delete,
                    ),
                  ],
                ),
                TextFormField(
                  controller: _entries[i].usernameController,
                  decoration: InputDecoration(
                    labelText: appLocalizations.username,
                    prefixIcon: const Icon(Icons.person_outline),
                    isDense: true,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return appLocalizations.emptyTip(
                        appLocalizations.username,
                      );
                    }
                    // `user:pass` is split on the first colon, so a colon in the
                    // username would silently move the boundary and corrupt the
                    // stored credential.
                    if (trimmed.contains(':')) {
                      return appLocalizations.usernameCannotContainColon;
                    }
                    final hasDuplicate = _entries.asMap().entries.any(
                      (e) =>
                          e.key != i &&
                          e.value.usernameController.text.trim() == trimmed &&
                          trimmed.isNotEmpty,
                    );
                    if (hasDuplicate) {
                      return appLocalizations.existsTip(
                        appLocalizations.username,
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _entries[i].passwordController,
                  // Obscured by default; the toggle is per entry so revealing one
                  // does not expose the rest.
                  obscureText: _entries[i].obscurePassword,
                  decoration: InputDecoration(
                    labelText: appLocalizations.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _entries[i].obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _entries[i].obscurePassword =
                              !_entries[i].obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.emptyTip(
                        appLocalizations.password,
                      );
                    }
                    return null;
                  },
                ),
              ],
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appLocalizations.skipLocalAuth,
                        style: context.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appLocalizations.skipLocalAuthDesc,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _skipLocalAuth,
                  onChanged: (val) {
                    setState(() {
                      _skipLocalAuth = val;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
