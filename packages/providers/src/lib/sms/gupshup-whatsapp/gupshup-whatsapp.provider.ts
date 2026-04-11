import { SmsProviderIdEnum } from '@novu/shared';
import { ChannelTypeEnum, ISendMessageSuccessResponse, ISmsOptions, ISmsProvider } from '@novu/stateless';
import axios from 'axios';
import { BaseProvider, CasingEnum } from '../../../base.provider';
import { WithPassthrough } from '../../../utils/types';

export class GupshupWhatsappProvider extends BaseProvider implements ISmsProvider {
  id = SmsProviderIdEnum.GupshupWhatsapp;
  protected casing = CasingEnum.SNAKE_CASE;
  channelType = ChannelTypeEnum.SMS as ChannelTypeEnum.SMS;
  public static BASE_URL = 'https://api.gupshup.io/wa/api/v1/template/msg';

  constructor(
    private config: {
      apiKey?: string;
      from?: string; // source
      senderName?: string; // appName
      /** Used when trigger payload / overrides omit templateId */
      templateId?: string;
    }
  ) {
    super();
  }

  async sendMessage(
    options: ISmsOptions,
    bridgeProviderData: WithPassthrough<Record<string, unknown>> = {}
  ): Promise<ISendMessageSuccessResponse> {
    const defaultTemplateId = this.config.templateId;
    const templateId =
      options.customData?.templateId ||
      options.customData?.template?.id ||
      (defaultTemplateId != null && String(defaultTemplateId).trim() !== '' ? String(defaultTemplateId).trim() : undefined);
    const templateParams = options.customData?.templateParams || options.customData?.template?.params || [];

    if (templateId == null || String(templateId).trim() === '') {
      throw new Error(
        'Gupshup WhatsApp: missing template id. Set Default template ID on the integration, or pass templateId in the trigger payload or overrides.sms.customData.'
      );
    }

    const templateJSON = JSON.stringify({
      id: templateId,
      params: templateParams,
    });

    const params = new URLSearchParams(
      this.transform(bridgeProviderData, {
        channel: 'whatsapp',
        source: this.config.from,
        destination: options.to,
        'src.name': this.config.senderName,
        template: templateJSON,
      }).body as Record<string, string>
    );

    const response = await axios.post(GupshupWhatsappProvider.BASE_URL, params, {
      headers: {
        apikey: this.config.apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
        'cache-control': 'no-cache',
      },
    });

    const body = response.data;

    if (body.status === 'error' || response.status >= 400) {
      throw new Error(`Gupshup Error: ${JSON.stringify(body)}`);
    }

    return {
      id: body.messageId || body.id || new Date().toISOString(),
      date: new Date().toISOString(),
    };
  }
}

