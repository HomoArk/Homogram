import {
  PhotoPickerComponent,
  PickerController,
  PickerOptions,
  DataType,
  ItemInfo,
  ItemType,
  PhotoBrowserInfo,
  ClickType,
  PickerColorMode,
  MaxSelected,
  MaxCountType,
  ReminderMode,
  PickerOrientation,
  BaseItemInfo,
  PhotoBrowserRange,
  SelectMode,
} from '@ohos.file.PhotoPickerComponent';
import photoAccessHelper from '@ohos.file.photoAccessHelper';

@Component
export struct ChatDetailBottomPhotoPicker {
  // Set parameter information during component initialization.
  pickerOptions: PickerOptions = new PickerOptions();
  // Controls selected component behavior after initialization completes.
  @State pickerController: PickerController = new PickerController();
  @State selectedUris: string[] = [];
  @State currentUri: string = '';
  @State isBlock: boolean = false; // whether to allow opening system camera
  @Link selectedMediaCount: number;
  @Link animate: boolean;
  @Link selectedMedias: Array<string>;

  build() {
    PhotoPickerComponent({
      // Set the component picker options instance.
      pickerOptions: this.pickerOptions,

      // Called when a resource is selected. The returned URI has read-only permission.
      onSelect: (uri: string): void => this.onSelect(uri),

      // Called when a resource is deselected. The returned URI has read-only permission.
      onDeselect: (uri: string): void => this.onDeselect(uri),

      /**
       * Called when a resource is selected. Returns resource information and the selection method.
       * ItemInfo includes itemType, uri, mimeType, width, height, size, and duration.
       * ClickType: SELECTED means checked, DESELECTED means unchecked.
       * A return value of true grants the URL read-only permission.
       */
      onItemClicked: (itemInfo: ItemInfo, clickType: ClickType): boolean => this.onItemClicked(itemInfo, clickType),

      /**
       * Called when entering the full-image page.
       * PhotoBrowserInfo (animatorParams: animation effect).
       */
      onEnterPhotoBrowser: (photoBrowserInfo: PhotoBrowserInfo): boolean => this.onEnterPhotoBrowser(photoBrowserInfo),

      /**
       * Called when exiting the full-image page.
       * PhotoBrowserInfo (animatorParams: animation effect).
       */
      onExitPhotoBrowser: (photoBrowserInfo: PhotoBrowserInfo): boolean => this.onExitPhotoBrowser(photoBrowserInfo),

      /**
       * Called when full-image page content changes.
       * PhotoBrowserInfo (animatorParams: animation effect).
       */
      onPhotoBrowserChanged: (photoBrowserItemInfo: BaseItemInfo): boolean => this.onPhotoBrowserChanged(photoBrowserItemInfo),

      // After this callback, pickerController APIs can send data to the picker.
      onPickerControllerReady: (): void => this.onPickerControllerReady(),

      // Picker controller instance. Apps can use PickerController to control PhotoPickerComponent behavior.
      pickerController: this.pickerController,
    })
  }

  aboutToAppear() {
    // Set the picker grid page data type.
    this.pickerOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;

    // Whether to show the search box. Default is false.
    this.pickerOptions.isSearchSupported = true;

    // Whether photo capture is supported. Default is false.
    this.pickerOptions.isPhotoTakingSupported = true;

    // Whether repeated selection is supported.
    this.pickerOptions.isRepeatSelectSupported = false;

    // Maximum selection count.
    this.pickerOptions.maxSelectNumber = 8; // Maximum selection count.

    // Maximum photo selection count.
    this.pickerOptions.maxPhotoSelectNumber = 8; // Maximum photo selection count.

    // Maximum video selection count.
    this.pickerOptions.maxVideoSelectNumber = 8; // Maximum video selection count.

    // Behavior when the maximum selection count is exceeded.
    this.pickerOptions.maxSelectedReminderMode = ReminderMode.TOAST;

    // Set the full-image background color.
    this.pickerOptions.photoBrowserBackgroundColorMode = PickerColorMode.AUTO;

    // Set the selected checkbox color.
    this.pickerOptions.checkBoxColor = '#000000';

    // Set the checkbox text color.
    this.pickerOptions.checkboxTextColor = '#000000';

    // Set the grid page background color.
    this.pickerOptions.backgroundColor = `#F6F6F6`;

    // Set selection mode. Default: MULTI_SELECT.
    this.pickerOptions.selectMode = SelectMode.MULTI_SELECT;
  }

  // Full-image page entry callback.
  private onEnterPhotoBrowser(photoBrowserInfo: PhotoBrowserInfo): boolean {
    console.info('onEnterPhotoBrowser' + JSON.stringify(photoBrowserInfo));
    return false;
  }

  // Full-image page exit callback.
  private onExitPhotoBrowser(photoBrowserInfo: PhotoBrowserInfo): boolean {
    console.info('onExitPhotoBrowser' + JSON.stringify(photoBrowserInfo));
    return false;
  }

  // After this callback, pickerController APIs can send data to the picker.
  private onPickerControllerReady(): void {
    console.info('onPickerControllerReady');
  }

  // Handles full-image page image change events.
  private onPhotoBrowserChanged(photoBrowserItemInfo: BaseItemInfo): boolean {
    console.info('onPhotoBrowserChanged' + JSON.stringify(photoBrowserItemInfo));
    this.currentUri = photoBrowserItemInfo.uri ?? '';
    return true;
  }

  // Called when an image or video is selected. The returned URL is read-only and cannot be opened directly.
  private onSelect(uri: string): void {
    if (uri) {
      this.selectedUris.push(uri)
    }
    // Save the URI and keep selections consistent when switching grid components.
    this.pickerOptions.preselectedUris = [...this.selectedUris];
    this.selectedMedias = [...this.selectedUris];
    this.selectedMediaCount = this.selectedUris.length;
    console.info('onSelect' + JSON.stringify(this.selectedUris));
  }

  // Called when an image or video is unchecked. The returned URL is read-only and cannot be opened directly.
  private onDeselect(uri: string): void {
    if (uri) {
      this.selectedUris = this.selectedUris.filter((item: string) => {
        return item !== uri;
      })
    }
    // Remove the unchecked URI and keep selections consistent when switching grid components.
    this.pickerOptions.preselectedUris = [...this.selectedUris];
    this.selectedMedias = [...this.selectedUris];
    this.selectedMediaCount = this.selectedUris.length;
    console.info('onDeselect' + JSON.stringify(this.selectedUris));
  }

  /**
   * Called when an image or video is selected. Returns resource information and the selection method.
   * ItemInfo contains image and video information.
   * ClickType: SELECTED means checked, DESELECTED means unchecked.
   * A return value of true grants the URL read-only permission.
   */
  private onItemClicked(itemInfo: ItemInfo, clickType: ClickType): boolean {
    if (!itemInfo) {
      return false;
    }
    let type: ItemType | undefined = itemInfo.itemType;
    let uri: string | undefined = itemInfo.uri;
    if (type === ItemType.CAMERA) { // Clicked the camera item.
      console.info('onCameraClick');
      if (this.isBlock) {
        return false;
      }
      // Return true to open the system camera. Return false when the app handles it itself.
      return true;
    } else if (type === ItemType.THUMBNAIL) { // Clicked an image or video thumbnail item.
      if (clickType === ClickType.SELECTED) { // Selected.
        if (this.isBlock) {
          return false;
        }
        // Save the URI and keep selections consistent when switching grid components.
        if (uri) {
          this.selectedUris.push(uri)
          this.pickerOptions.preselectedUris = [...this.selectedUris];
          this.selectedMedias = [...this.selectedUris];
        }
      } else { // Deselected.
        if (uri) {
          // Remove the unchecked URI and keep selections consistent when switching grid components.
          this.selectedUris = this.selectedUris.filter((item: string) => {
            return item !== uri;
          })
          this.pickerOptions.preselectedUris = [...this.selectedUris];
          this.selectedMedias = [...this.selectedUris];
        }
      }
    } else {
    }
    console.info('onItemClicked' + JSON.stringify(itemInfo));
    return true;
  }
}
