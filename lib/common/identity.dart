const _useDevIdentity = bool.fromEnvironment('APP_DEV');

class AppIdentity {
  static const isDev = _useDevIdentity;

  static const productName = 'bettbox+';
  static const devSuffix = '+';
  static const packageId = 'com.appshub.bettbox.plus';

  static const compactName = 'BettboxPlus';
  static const displayName = 'bettbox+';
  static const mainExecutableName = 'Bettbox+';
  static const coreExecutableName = 'BettboxCore';
  static const dataDirName = 'BettboxPlus';
  static const tunDeviceName = 'BettboxPlus';
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.19.2.2',
  );
}

class WindowsHelperIdentity {
  static const serviceName = '${AppIdentity.compactName}HelperService';
  static const pipeName = '\\\\.\\pipe\\${AppIdentity.compactName}.Helper';
}
