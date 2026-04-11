import axios from 'axios';
import { SmsProviderIdEnum } from '@novu/shared';
import { GupshupWhatsappProvider } from './gupshup-whatsapp.provider';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('Gupshup WhatsApp Provider', () => {
  let provider: GupshupWhatsappProvider;

  beforeEach(() => {
    provider = new GupshupWhatsappProvider({
      apiKey: 'test-api-key',
      from: '15558378566',
      senderName: 'Finkhoz',
    });
  });

  test('should trigger gupshup whatsapp correctly', async () => {
    mockedAxios.post.mockResolvedValue({
      status: 200,
      data: { status: 'submitted', messageId: 'msg-123' },
    } as any);

    const result = await provider.sendMessage({
      to: '919102888850',
      content: 'ignored-content-for-template',
      customData: {
        templateId: '08504e07-a967-49b4-848c-f0b99753ccc0',
        templateParams: ['Aman', 'Basket', 'link'],
      },
    } as any);

    const [url, data] = mockedAxios.post.mock.calls[0] as unknown as [string, URLSearchParams];
    expect(url).toEqual('https://api.gupshup.io/wa/api/v1/template/msg');
    expect(data.get('channel')).toEqual('whatsapp');
    expect(result.id).toEqual('msg-123');
    expect(provider.id).toEqual(SmsProviderIdEnum.GupshupWhatsapp);
  });
});

