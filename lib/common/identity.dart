const _useDevIdentity = bool.fromEnvironment('APP_DEV');

class AppIdentity {
  static const isDev = _useDevIdentity;

  static const productName = 'Fluxora';
  static const devSuffix = '-dev';
  static const packageId = 'io.fluxora.app';

  static const compactName = 'Fluxora';
  static const displayName = 'Fluxora';
  static const mainExecutableName = 'Fluxora';
  static const coreExecutableName = 'FluxoraCore';
  static const dataDirName = 'Fluxora';
  static const tunDeviceName = 'Fluxora';
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.19.2.2',
  );
}

class WindowsHelperIdentity {
  static const serviceName = '${AppIdentity.compactName}HelperService';
  static const pipeName = '\\\\.\\pipe\\${AppIdentity.compactName}.Helper';
}
