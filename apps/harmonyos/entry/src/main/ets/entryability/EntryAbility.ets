import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { SecurityService } from '../services/SecurityService';
import { vaultStore } from '../state/VaultStore';

export default class EntryAbility extends UIAbility {
  private backgroundAt: number = 0;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void want;
    void launchParam;
    vaultStore.init(this.context.filesDir);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        return;
      }
      windowStage.getMainWindow().then((win) => {
        SecurityService.attachWindow(win);
        SecurityService.setPrivacyMode(vaultStore.privacyMask);
      });
    });
  }

  onBackground(): void {
    this.backgroundAt = Date.now();
  }

  onForeground(): void {
    if (this.backgroundAt > 0) {
      const elapsed = Date.now() - this.backgroundAt;
      this.backgroundAt = 0;
      vaultStore.handleForegroundResume(elapsed);
    }
  }
}
