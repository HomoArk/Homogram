import {
  MessageEntityType
} from '../../api';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { promptAction, LengthMetrics } from '@kit.ArkUI';
import { Logger } from '@ohos/base';
import { MessageEntity } from '../../entities/Message';

/**
 * Apply the corresponding style for the entity type.
 * @param text Raw text content.
  * @param styledString |inout| Mutable styled string.
 * @throws BusinessError
 */
export function applyEntityStyle(text: string, styledString: MutableStyledString, entity: MessageEntity): void {
  const start = entity.offset;
  const length = entity.length;

  // Ensure the range is valid.
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
            // Copy the code segment to the clipboard.
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
      // Hyperlink style: blue with underline.
      // Prefer entity.url; otherwise try to detect a URL from the text segment.
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
      // URL and email style: blue.
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.Mention:
    case MessageEntityType.MentionName:
      // @ mention style: blue.
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color'), fontWeight: FontWeight.Medium })
      });
      break;

    case MessageEntityType.Hashtag:
    case MessageEntityType.Cashtag:
      // Hashtag and cashtag style: blue.
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.BotCommand:
      // Bot command style: blue.
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.Spoiler:
      // Spoiler style: gray background. Blur effects need special handling.
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
      // Blockquote style: gray background and left inset.
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
      // Phone number style.
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.CustomEmoji:
      // Custom emoji is not handled yet. It requires loading emoji images.
      break;

    default:
      // Unknown type: do nothing.
      break;
  }
}

/**
 * Roughly check whether text may be a URL.
 */
function isLikelyUrl(text: string): boolean {
  if (!text) return false;
  // Simple checks for common prefixes or domain-like structures.
  const lower = text.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) return true;
  if (lower.startsWith('www.')) return true;
  // Simple domain match, such as example.com or sub.domain.io/path.
  const domainLike = /^(?:[a-z0-9-]+\.)+[a-z]{2,}(?:[/:?#].*)?$/i;
  return domainLike.test(text);
}

/**
 * Normalize URLs, such as by adding the default protocol.
 */
function normalizeUrl(url: string): string {
  const trimmed = (url || '').trim();
  if (trimmed.length === 0) return url;
  const lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  // Add the default protocol for values like `www.example.com` or bare domains.
  return `https://${trimmed}`;
}



