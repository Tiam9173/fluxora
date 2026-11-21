/// Small built-in proxy/group icon presets.
///
/// The values use the existing icon loader's `asset://` form, so the preset
/// works offline and can still be replaced by a user URL in the icon editor.
abstract final class ProxyIconSets {
  static const services = <String, String>{
    r'(?i)chatgpt|openai': 'asset://assets/images/platforms/chatgpt.svg',
    r'(?i)claude|anthropic': 'asset://assets/images/platforms/claude.svg',
    r'(?i)gemini': 'asset://assets/images/platforms/gemini.svg',
    r'(?i)youtube': 'asset://assets/images/platforms/youtube.svg',
    r'(?i)github': 'asset://assets/images/platforms/github.svg',
    r'(?i)gitlab': 'asset://assets/images/platforms/gitlab.svg',
    r'(?i)telegram': 'asset://assets/images/platforms/telegram.svg',
    r'(?i)discord': 'asset://assets/images/platforms/discord.svg',
    r'(?i)netflix': 'asset://assets/images/platforms/netflix.svg',
    r'(?i)spotify': 'asset://assets/images/platforms/spotify.svg',
    r'(?i)tiktok': 'asset://assets/images/platforms/tiktok.svg',
    r'(?i)steam': 'asset://assets/images/platforms/steam.svg',
    r'(?i)reddit': 'asset://assets/images/platforms/reddit.svg',
    r'(?i)bilibili': 'asset://assets/images/platforms/bilibili.svg',
    r'(?i)cloudflare': 'asset://assets/images/platforms/cloudflare.svg',
    r'(?i)paypal': 'asset://assets/images/platforms/paypal.svg',
    r'(?i)coinbase': 'asset://assets/images/platforms/coinbase.svg',
    r'(?i)apple': 'asset://assets/images/platforms/apple.svg',
    r'(?i)stackoverflow': 'asset://assets/images/platforms/stackoverflow.svg',
  };

  static const presets = <String, Map<String, String>>{'services': services};
}
