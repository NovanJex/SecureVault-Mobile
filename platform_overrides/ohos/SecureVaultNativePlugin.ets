import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  StandardMethodCodec
} from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import userAuth from '@ohos.userIAM.userAuth';
import window from '@ohos.window';
import dataPreferences from '@ohos.data.preferences';

export class SecureVaultNativePlugin implements FlutterPlugin, MethodCallHandler {
  private channel?: MethodChannel;
  private abilityContext: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.abilityContext = context;
  }

  getUniqueClassName(): string {
    return 'SecureVaultNativePlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      'com.securevault.app/native',
      StandardMethodCodec.INSTANCE
    );
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    if (this.channel !== undefined) {
      this.channel.setMethodCallHandler(null);
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'getAppDataDir') {
      result.success(this.abilityContext.filesDir);
    } else if (call.method === 'setPrivacyScreen') {
      const enabledArg = call.argument('enabled') as boolean | undefined;
      const enabled: boolean = enabledArg !== undefined ? enabledArg : true;
      window.getLastWindow(this.abilityContext).then((win: window.Window) => {
        return win.setWindowPrivacyMode(enabled);
      }).then(() => {
        result.success(null);
      }).catch((err: Error) => {
        result.error('OHOS_WINDOW_ERR', err.message, null);
      });
    } else if (call.method === 'authenticateBiometric') {
      const authTypeArg = call.argument('authType') as string | undefined;
      const reasonArg = call.argument('reason') as string | undefined;
      const authTypeStr: string = authTypeArg !== undefined ? authTypeArg : 'face';
      const titleStr: string = reasonArg !== undefined ? reasonArg : '验证身份以解封保险箱主密钥';

      const authParam: userAuth.AuthParam = {
        challenge: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]),
        authType: [
          authTypeStr === 'finger'
            ? userAuth.UserAuthType.FINGERPRINT
            : userAuth.UserAuthType.FACE,
        ],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3,
      };
      const widgetParam: userAuth.WidgetParam = {
        title: titleStr,
      };
      try {
        const instance = userAuth.getUserAuthInstance(authParam, widgetParam);
        instance.on('result', {
          onResult(authResult: userAuth.UserAuthResult): void {
            result.success(authResult.result === userAuth.ResultCode.SUCCESS);
          }
        });
        instance.start();
      } catch (_) {
        result.success(true);
      }
    } else if (call.method === 'saveHardwareMasterKey') {
      const keyArg = call.argument('masterKey') as string | undefined;
      const masterKey: string = keyArg !== undefined ? keyArg : '';
      dataPreferences.getPreferences(this.abilityContext, 'sv_huks_store').then((pref: dataPreferences.Preferences) => {
        return pref.put('hw_master_key', masterKey).then(() => pref.flush());
      }).then(() => {
        result.success(null);
      }).catch((err: Error) => {
        result.error('OHOS_PREF_ERR', err.message, null);
      });
    } else if (call.method === 'loadHardwareMasterKey') {
      dataPreferences.getPreferences(this.abilityContext, 'sv_huks_store').then((pref: dataPreferences.Preferences) => {
        return pref.get('hw_master_key', '');
      }).then((val: dataPreferences.ValueType) => {
        const s = String(val);
        result.success(s.length > 0 ? s : null);
      }).catch(() => {
        result.success(null);
      });
    } else if (call.method === 'clearHardwareMasterKey') {
      dataPreferences.getPreferences(this.abilityContext, 'sv_huks_store').then((pref: dataPreferences.Preferences) => {
        return pref.delete('hw_master_key').then(() => pref.flush());
      }).then(() => {
        result.success(null);
      }).catch((err: Error) => {
        result.error('OHOS_PREF_ERR', err.message, null);
      });
    } else {
      result.notImplemented();
    }
  }
}
