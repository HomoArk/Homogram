import {
  MessageEntityType
} from '../../api';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { promptAction, LengthMetrics } from '@kit.ArkUI';
import { Logger } from '@ohos/base';
import { MessageEntity } from '../../entities/Message';

/**
 * 鏍规嵁瀹炰綋绫诲瀷搴旂敤瀵瑰簲鐨勬牱寮?
 * @param text 鍘熷鏂囨湰鍐呭
  * @param styledString |inout| 鍙彉鏍峰紡瀛楃涓?
 * @throws BusinessError
 */
export function applyEntityStyle(text: string, styledString: MutableStyledString, entity: MessageEntity): void {
  const start = entity.offset;
  const length = entity.length;

  // 纭繚鑼冨洿鏈夋晥
  if (start < 0 || start >= text.length || length <= 0) {
    return;
  }

  const actualLength = Math.min(length, text.length - start);

  switch (entity.entityType) {
    case MessageEntityType.Bold:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontWeight: FontWeight.Bold })
      });
      break;

    case MessageEntityType.Italic:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontStyle: FontStyle.Italic })
      });
      break;

    case MessageEntityType.Underline:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.DECORATION,
        styledValue: new DecorationStyle({ type: TextDecorationType.Underline, color: $r('app.color.message_decoration_color') })
      });
      break;

    case MessageEntityType.Strike:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.DECORATION,
        styledValue: new DecorationStyle({ type: TextDecorationType.LineThrough, color: $r('app.color.message_decoration_color') })
      });
      break;

    case MessageEntityType.Code:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontFamily: 'monospace' })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.BACKGROUND_COLOR,
        styledValue: new BackgroundColorStyle({ color: $r('app.color.message_code_background_color'), radius: 4 })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.GESTURE,
        styledValue: new GestureStyle({
          onLongPress: () => {
            // 澶嶅埗浠ｇ爜鐗囨鍒板壀璐存澘
            const codeText = text.substring(start, start + actualLength);
            const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, codeText);
            const systemPasteboard = pasteboard.getSystemPasteboard();
            systemPasteboard.setData(pasteData).then(() => {
              promptAction.showToast({
                message: $r('app.string.message_code_copied'),
                duration: 2000
              });
            }).catch((err: BusinessError) => {
              Logger.error(`Failed to copy code to clipboard: ${err.message}`);
            });
          }
        })
      });
      break;

    case MessageEntityType.Pre:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontFamily: 'monospace' })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.BACKGROUND_COLOR,
        styledValue: new BackgroundColorStyle({ color: $r('app.color.message_pre_background_color'), radius: 4 })
      });
      break;

    case MessageEntityType.TextUrl:
      // 瓒呴摼鎺ユ牱寮忥細钃濊壊 + 涓嬪垝绾?
      // 浼樺厛浣跨敤 entity.url锛屽惁鍒欏皾璇曚粠鏂囨湰鐗囨璇嗗埆 URL
      const textUrlRawText = text.substring(start, start + actualLength);
      const textUrlLink = entity.url ?? (isLikelyUrl(textUrlRawText.trim()) ? normalizeUrl(textUrlRawText.trim()) : undefined);

      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.DECORATION,
        styledValue: new DecorationStyle({ type: TextDecorationType.Underline, color: $r('app.color.message_link_color') })
      });
      if (textUrlLink) {
        styledString.setStyle({
          start: start,
          length: actualLength,
          styledKey: StyledStringKey.URL,
          styledValue: new UrlStyle(textUrlLink)
        });
      }
      break;

    case MessageEntityType.Url:
    case MessageEntityType.Email:
      // URL 鍜岄偖绠辨牱寮忥細钃濊壊
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.Mention:
    case MessageEntityType.MentionName:
      // @ 鎻愬強鏍峰紡锛氳摑鑹?
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color'), fontWeight: FontWeight.Medium })
      });
      break;

    case MessageEntityType.Hashtag:
    case MessageEntityType.Cashtag:
      // 鏍囩鏍峰紡锛氳摑鑹?
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.BotCommand:
      // Bot 鍛戒护鏍峰紡锛氳摑鑹?
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.Spoiler:
      // 鍓ч€忔牱寮忥細鐏拌壊鑳屾櫙锛堟ā绯婃晥鏋滈渶瑕佺壒娈婂鐞嗭級
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.BACKGROUND_COLOR,
        styledValue: new BackgroundColorStyle({ color: $r('app.color.message_spoiler_color'), radius: 4 })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_spoiler_color') })
      });
      break;

    case MessageEntityType.Blockquote:
      // 寮曠敤鍧楁牱寮忥細鐏拌壊鑳屾櫙 + 宸﹁竟璺?
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.BACKGROUND_COLOR,
        styledValue: new BackgroundColorStyle({ color: $r('app.color.message_blockquote_background_color'), radius: 4 })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_blockquote_text_color') })
      });
      break;

    case MessageEntityType.Phone:
      // 鐢佃瘽鍙风爜鏍峰紡
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.CustomEmoji:
      // 鑷畾涔夎〃鎯咃細鏆備笉澶勭悊锛岄渶瑕佸姞杞借〃鎯呭浘鐗?
      break;

    default:
      // 鏈煡绫诲瀷锛屼笉澶勭悊
      break;
  }
}

/**
 * 绮楃暐鍒ゆ柇鏂囨湰鏄惁鍙兘涓?URL
 */
function isLikelyUrl(text: string): boolean {
  if (!text) return false;
  // 甯歌鍓嶇紑鎴栧煙鍚嶇粨鏋勭殑绠€鍗曞垽鏂?
  const lower = text.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) return true;
  if (lower.startsWith('www.')) return true;
  // 绠€鍗曠殑鍩熷悕鍖归厤锛屽 example.com 鎴?sub.domain.io/path
  const domainLike = /^(?:[a-z0-9-]+\.)+[a-z]{2,}(?:[/:?#].*)?$/i;
  return domainLike.test(text);
}

/**
 * 瑙勮寖鍖?URL锛氳ˉ鍏ㄥ崗璁瓑
 */
function normalizeUrl(url: string): string {
  const trimmed = (url || '').trim();
  if (trimmed.length === 0) return url;
  const lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  // 涓哄儚 `www.example.com` 鎴栬８鍩熷悕琛ュ叏榛樿鍗忚
  return `https://${trimmed}`;
}



