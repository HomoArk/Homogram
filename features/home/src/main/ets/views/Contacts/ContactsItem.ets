/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { BaseConstants, BreakpointConstants } from '@ohos/base';
import { HomeConstants } from '../../constants/HomeConstants';
import { SeenChat } from '../../entities/SeenChat';

@Component
export struct ContactsItem {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  private contact?: SeenChat;
  private icon: Resource = HomeConstants.DEFAULT_AVATAR;

  build() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween }) {
      Column() {
        Image(this.icon)
          .height($r('app.float.avatar_image_size'))
          .width($r('app.float.avatar_image_size'))
      }
      .width($r('app.float.avatar_image_size'))
      .margin({ left: $r('app.float.icon_margin_two'), right: $r('app.float.icon_margin_one') })

      Column() {
        Text(this.contact?.fullName || this.contact?.firstName || '')
          .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
          .fontWeight(BaseConstants.FONT_WEIGHT_FIVE)
          .lineHeight($r('app.float.text_line_height_two'))
          .fontFamily(BaseConstants.FONT_FAMILY_MEDIUM)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle().length > 0) {
          Text(this.subtitle())
            .fontSize(BaseConstants.FONT_SIZE_TWELVE)
            .fontColor(Color.Grey)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .flexShrink(BaseConstants.FLEX_SHRINK_ONE)
      .margin({ left: $r('app.float.icon_margin_one') })

      Blank()
    }
    .height(64)
    .width(BaseConstants.FULL_WIDTH)
    .hoverEffect(HoverEffect.Highlight)
  }

  private subtitle(): string {
    if (this.contact?.username && this.contact.username.length > 0) {
      return '@' + this.contact.username;
    }
    if (this.contact?.phone && this.contact.phone.length > 0) {
      return this.contact.phone;
    }
    return '';
  }
}
