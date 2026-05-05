import BuildProfile from '../../../../BuildProfile';

const UITEST_BUILD_MODE: string = 'uitest';
const FIXTURE_URI_MARKER: string = 'homogram-uitest';

let telegramFixtureMode: boolean = BuildProfile.BUILD_MODE_NAME === UITEST_BUILD_MODE;

export function isTelegramFixtureMode(): boolean {
  return telegramFixtureMode;
}

export function setTelegramFixtureMode(enabled: boolean): boolean {
  if (!BuildProfile.DEBUG && BuildProfile.BUILD_MODE_NAME !== UITEST_BUILD_MODE) {
    return false;
  }
  telegramFixtureMode = enabled;
  return true;
}

export function applyTelegramFixtureModeFromUri(uri: string | undefined): boolean {
  if (!uri) {
    return false;
  }
  if (uri.indexOf(FIXTURE_URI_MARKER) >= 0 || uri.indexOf('fixture=1') >= 0) {
    return setTelegramFixtureMode(true);
  }
  return false;
}

export function telegramFixtureModeDescription(): string {
  return telegramFixtureMode ? 'telegram-fixture' : 'telegram-native';
}
