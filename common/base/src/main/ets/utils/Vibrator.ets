import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class Vibrator {
  public static async kata() {
    let effect = vibrator.EffectId.EFFECT_CLOCK_TIMER;
    try {
      // Query whether the selected haptic effect is supported.
      vibrator.isSupportEffect(effect, (err: BusinessError, state: boolean) => {
        if (err) {
          console.error(`Failed to query effect. Code: ${err.code}, message: ${err.message}`);
          return;
        }
        console.info('Succeed in querying effect');
        if (state) {
          try {
            // Trigger haptic vibration.
            vibrator.startVibration({
              type: 'preset',
              effectId: effect,
              count: 1,
              intensity: 100,
            }, {
              usage: 'unknown'
            }, (error: BusinessError) => {
              if (error) {
                console.error(`Failed to start vibration. Code: ${error.code}, message: ${error.message}`);
              } else {
                console.info('Succeed in starting vibration');
              }
            });
          } catch (error) {
            let e: BusinessError = error as BusinessError;
            console.error(`An unexpected error occurred. Code: ${e.code}, message: ${e.message}`);
          }
        }
      })
    } catch (error) {
      let e: BusinessError = error as BusinessError;
      console.error(`An unexpected error occurred. Code: ${e.code}, message: ${e.message}`);
    }
  }
}
