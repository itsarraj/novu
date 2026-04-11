import { GupshupWhatsappProvider } from '@novu/providers';
import { ChannelTypeEnum, ICredentials, SmsProviderIdEnum } from '@novu/shared';
import { BaseSmsHandler } from './base.handler';

export class GupshupWhatsappHandler extends BaseSmsHandler {
  constructor() {
    super(SmsProviderIdEnum.GupshupWhatsapp, ChannelTypeEnum.SMS);
  }

  buildProvider(credentials: ICredentials) {
    this.provider = new GupshupWhatsappProvider({
      apiKey: credentials.apiKey,
      from: credentials.from,
      senderName: credentials.senderName,
      templateId: credentials.templateId,
    });
  }
}

