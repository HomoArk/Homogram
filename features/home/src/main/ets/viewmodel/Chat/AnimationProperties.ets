// AnimationProperties.ets
// Shared-element transition animation wrapper.
import { componentUtils, curves } from '@kit.ArkUI';
import { RectInfoInPx } from '@ohos/base';
import { WindowUtil } from '@ohos/base';
import { ChatPhotoNodeController } from './ChatPhotoNodeController';

const TAG: string = 'AnimationProperties';

const DEVICE_BORDER_RADIUS: number = 34;

@Observed
class AnimationProperties {
  public isExpandPageShow: boolean = false;
  // Controls whether the component responds to click events.
  public isEnabled: boolean = true;
  // Expanded card index.
  public curIndex: number = -1;
  public translateX: number = 0;
  public translateY: number = 0;
  public positionX: number = 0;
  public positionY: number = 0;
  public changedHeight: boolean = false;
  private calculatedTranslateX: number = 0;
  private calculatedTranslateY: number = 0;
  // Position of the expanded card relative to the parent component.
  private expandTranslateX: number = 0;
  private expandTranslateY: number = 0;

  public expandAnimation(index: number): void {
    // Record the expanded card index.
    if (index != undefined) {
      this.curIndex = index;
    }
    // Calculate the collapsed card position relative to the parent component.
    this.calculateData(index.toString());
    // Mount the expanded card.
    this.isExpandPageShow = true;
    // Property animation for expanding the card.
    animateTo({
      curve: curves.springMotion(0.6, 0.9)
    }, () => {
      this.translateX = this.calculatedTranslateX;
      this.translateY = this.calculatedTranslateY;
      this.changedHeight = true;
    })
  }

  // Get the migrating component position and the common parent node positions before and after migration to calculate animation parameters.
  public calculateData(key: string): void {
    let clickedImageInfo = this.getRectInfoById(key);
    let rootStackInfo = this.getRectInfoById('rootStack');
    this.positionX = px2vp(clickedImageInfo.left - rootStackInfo.left);
    this.positionY = px2vp(clickedImageInfo.top - rootStackInfo.top);
    this.calculatedTranslateX = px2vp(rootStackInfo.left - clickedImageInfo.left) + this.expandTranslateX;
    this.calculatedTranslateY = px2vp(rootStackInfo.top - clickedImageInfo.top) + this.expandTranslateY;
  }

  // Get component position information by component id.
  private getRectInfoById(id: string): RectInfoInPx {
    let componentInfo: componentUtils.ComponentInfo = componentUtils.getRectangleById(id);

    if (!componentInfo) {
      throw Error('object is empty');
    }

    let rstRect: RectInfoInPx = new RectInfoInPx();
    const widthScaleGap = componentInfo.size.width * (1 - componentInfo.scale.x) / 2;
    const heightScaleGap = componentInfo.size.height * (1 - componentInfo.scale.y) / 2;
    rstRect.left = componentInfo.translate.x + componentInfo.windowOffset.x + widthScaleGap;
    rstRect.top = componentInfo.translate.y + componentInfo.windowOffset.y + heightScaleGap;
    rstRect.right =
      componentInfo.translate.x + componentInfo.windowOffset.x + componentInfo.size.width - widthScaleGap;
    rstRect.bottom =
      componentInfo.translate.y + componentInfo.windowOffset.y + componentInfo.size.height - heightScaleGap;
    rstRect.width = rstRect.right - rstRect.left;
    rstRect.height = rstRect.bottom - rstRect.top;

    return {
      left: rstRect.left,
      right: rstRect.right,
      top: rstRect.top,
      bottom: rstRect.bottom,
      width: rstRect.width,
      height: rstRect.height
    }
  }
}