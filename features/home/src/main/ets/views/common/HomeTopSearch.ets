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

import { BaseConstants } from '@ohos/base';
import {
  ChatFolderBar,
  HeaderGradientBlur,
  HeaderIconButton,
  HeaderSearchBar,
  HeaderSearchInput,
  HeaderTitleCapsule,
  HeaderTextButton,
  HdsHeaderMetrics,
  rootHeaderTopPadding
} from './HdsHeaderPrimitives';

@Component
export struct HomeTopSearch {
  @StorageProp('topRectHeight') topRectHeight: number = 0;
  @Prop title: ResourceStr = 'Chats';
  @Link isCompact: boolean;
  @Link isSearchExpanded: boolean;
  @Link searchValue: string;
  @Prop searchCollapseProgress: number = 0;

  @Builder
  SearchInput() {
    HeaderSearchInput({ searchValue: $searchValue })
  }

  @Builder
  HeaderRow() {
    Row() {
      HeaderTextButton({ text: 'Edit' })
        .width(96)

      HeaderTitleCapsule({
        title: this.title,
        capsuleWidth: BaseConstants.FULL_WIDTH,
        capsuleHeight: HdsHeaderMetrics.ROOT_ACTION_SIZE,
        titleFontSize: HdsHeaderMetrics.ROOT_TITLE_FONT_SIZE,
      })
        .layoutWeight(BaseConstants.LAYOUT_WEIGHT_ONE)
        .margin({ left: 8, right: 8 })

      Row({ space: HdsHeaderMetrics.ROOT_ACTION_GAP }) {
        HeaderIconButton({
          icon: $r('sys.symbol.plus_square'),
          buttonSize: HdsHeaderMetrics.ROOT_ACTION_SIZE,
          iconSize: 22,
        })
      }
      .width(96)
      .justifyContent(FlexAlign.End)
    }
    .alignItems(VerticalAlign.Center)
    .width(BaseConstants.FULL_WIDTH)
  }

  @Builder
  CollapsingSearchBar() {
    Column() {
      HeaderSearchBar({ placeholder: 'Search' })
        .onClick(() => {
          if (this.getSearchVisibleFraction() > 0.25) {
            this.isSearchExpanded = true;
          }
        })
    }
    .width(BaseConstants.FULL_WIDTH)
    .height(this.getCollapsedSearchHeight())
    .opacity(this.getSearchVisibleFraction())
    .scale({ x: 1, y: this.getSearchScaleY() })
    .clip(true)
    .margin({ top: this.getCollapsedSearchTopMargin() })
  }

  @Builder
  ExpandedSearchRow() {
    Row({ space: 10 }) {
      this.SearchInput()
      HeaderTextButton({ text: 'Cancel', fontSize: 16 })
        .onClick(() => {
          this.isSearchExpanded = false;
          this.searchValue = '';
        })
    }
    .alignItems(VerticalAlign.Center)
    .width(BaseConstants.FULL_WIDTH)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      HeaderGradientBlur({ materialHeight: this.getTopGradientHeight() })

      Column() {
        if (this.isSearchExpanded) {
          this.ExpandedSearchRow()
        } else {
          this.HeaderRow()

          this.CollapsingSearchBar()

          ChatFolderBar()
            .margin({ top: HdsHeaderMetrics.ROOT_FOLDER_TOP_MARGIN })
        }
      }
      .width(BaseConstants.FULL_WIDTH)
      .padding({
        left: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
        right: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
        top: rootHeaderTopPadding(this.topRectHeight),
        bottom: HdsHeaderMetrics.ROOT_BOTTOM_PADDING,
      })
    }
    .expandSafeArea([SafeAreaType.SYSTEM])
    .width(BaseConstants.FULL_WIDTH)
    .backgroundColor(Color.Transparent)
  }

  private getNormalizedSearchProgress(): number {
    return Math.min(1, Math.max(0, this.searchCollapseProgress));
  }

  private getSearchVisibleFraction(): number {
    return 1 - this.getNormalizedSearchProgress();
  }

  private getCollapsedSearchHeight(): number {
    return HdsHeaderMetrics.ROOT_SEARCH_HEIGHT * this.getSearchVisibleFraction();
  }

  private getCollapsedSearchTopMargin(): number {
    return HdsHeaderMetrics.ROOT_SEARCH_TOP_MARGIN * this.getSearchVisibleFraction();
  }

  private getSearchScaleY(): number {
    return Math.max(0.12, this.getSearchVisibleFraction());
  }

  private getTopGradientHeight(): number {
    return rootHeaderTopPadding(this.topRectHeight) + HdsHeaderMetrics.ROOT_ACTION_SIZE + 20;
  }
}
